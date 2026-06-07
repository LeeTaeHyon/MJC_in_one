import "dart:async";

import "package:app_links/app_links.dart";
import "package:flutter/material.dart";
import "package:mjc_in_one/screens/profile_setup_screen.dart";
import "package:mjc_in_one/services/auth_service.dart";
import "package:mjc_in_one/services/firebase_app_startup.dart";
import "package:mjc_in_one/services/user_data_repository.dart";
import "package:mjc_in_one/utils/mjc_snack_bar.dart";
import "package:mjc_in_one/widgets/main_navigation_scope.dart";

/// Firebase 이메일 매직 링크 딥링크 처리.
class DeepLinkHandler {
  DeepLinkHandler._();

  static final DeepLinkHandler instance = DeepLinkHandler._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  GlobalKey<NavigatorState>? _navigatorKey;
  String? _lastHandledLink;
  String? _queuedSnackBarMessage;
  Uri? _pendingUri;
  bool _openedViaAuthLink = false;
  bool _needsProfileSetupAfterLogin = false;

  /// 매직 링크로 앱이 열렸으면 인트로(Lottie)를 건너뛴다.
  bool get skipIntro => _openedViaAuthLink || _needsProfileSetupAfterLogin;

  /// [runApp] 전에 호출해 cold start 링크를 놓치지 않는다.
  Future<void> captureInitialLink() async {
    _pendingUri ??= await _appLinks.getInitialLink();
    if (_pendingUri != null) {
      _openedViaAuthLink = true;
      debugPrint("DeepLinkHandler: captured initial link $_pendingUri");
    }
  }

  /// Firebase 초기화 직후, UI 전에 로그인을 시도한다.
  Future<bool> processPendingAuthLink() async {
    final Uri? uri = _pendingUri;
    if (uri == null) return false;
    _pendingUri = null;
    final bool signedIn = await _handleUri(uri, showErrors: false);
    if (signedIn) {
      _needsProfileSetupAfterLogin = true;
    }
    return signedIn;
  }

  Future<void> start(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;
    _flushQueuedSnackBar();

    // main()에서 옮겨온 처리: Firebase 준비 후 대기 중인 매직 링크 로그인 시도.
    await processPendingAuthLink();

    _subscription ??= _appLinks.uriLinkStream.listen(
      (Uri uri) => _handleUri(uri),
      onError: (Object error) {
        debugPrint("DeepLinkHandler stream error: $error");
        _queueSnackBar("로그인 링크 처리 중 오류가 발생했습니다.");
      },
    );

    final Uri? latestUri = await _appLinks.getLatestLink();
    if (latestUri != null) {
      debugPrint("DeepLinkHandler: latest link $latestUri");
      await _handleUri(latestUri);
    }

    if (_needsProfileSetupAfterLogin) {
      _needsProfileSetupAfterLogin = false;
      final NavigatorState? navigator = _navigatorKey?.currentState;
      if (navigator != null) {
        await ProfileSetupScreen.maybePush(navigator);
      }
    }
  }

  Future<void> onAppResumed() async {
    final Uri? latestUri = await _appLinks.getLatestLink();
    if (latestUri != null) {
      debugPrint("DeepLinkHandler: resumed with link $latestUri");
      await _handleUri(latestUri);
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<bool> _handleUri(Uri uri, {bool showErrors = true}) async {
    debugPrint("DeepLinkHandler: received $uri");

    final List<String> candidates = _collectEmailLinkCandidates(uri);
    if (candidates.isEmpty) {
      debugPrint("DeepLinkHandler: no auth link candidates in $uri");
      return false;
    }

    await waitForFirebaseStartup();

    final AuthService auth = AuthService.instance;
    String? matchedLink;
    for (final String candidate in candidates) {
      if (candidate == _lastHandledLink) continue;
      if (auth.isSignInLink(candidate)) {
        matchedLink = candidate;
        break;
      }
    }

    if (matchedLink == null) {
      debugPrint(
        "DeepLinkHandler: no sign-in link among ${candidates.length} candidates",
      );
      return false;
    }

    try {
      final credential = await auth.completeSignIn(matchedLink);
      _lastHandledLink = matchedLink;
      final user = credential.user;
      if (user != null) {
        await UserDataRepository.instance.hydrateFromCloudOnLogin(user);
      }
      _needsProfileSetupAfterLogin = true;
      _popLoginRouteIfPossible();
      _queueSnackBar("로그인되었습니다.");
      _flushQueuedSnackBar();
      final NavigatorState? navigator = _navigatorKey?.currentState;
      if (navigator != null) {
        await ProfileSetupScreen.maybePush(navigator);
        _needsProfileSetupAfterLogin = false;
      }
      return true;
    } on MissingPendingEmailException {
      if (showErrors) {
        _queueSnackBar("먼저 이 기기에서 로그인 링크를 요청해 주세요.");
        _flushQueuedSnackBar();
      } else {
        debugPrint("DeepLinkHandler: pending email missing for $matchedLink");
      }
    } on MjcDomainException {
      _queueSnackBar("@mjc.ac.kr 이메일만 로그인할 수 있습니다.");
      _flushQueuedSnackBar();
    } catch (error, stackTrace) {
      debugPrint("DeepLinkHandler sign-in failed: $error\n$stackTrace");
      if (showErrors) {
        _queueSnackBar("로그인 링크가 만료되었거나 유효하지 않습니다.");
        _flushQueuedSnackBar();
      }
    }
    return false;
  }

  List<String> _collectEmailLinkCandidates(Uri uri) {
    final Set<String> seen = <String>{};
    final List<String> queue = <String>[uri.toString()];
    final List<String> results = <String>[];

    while (queue.isNotEmpty) {
      final String raw = queue.removeAt(0);
      if (raw.trim().isEmpty || !seen.add(raw)) continue;

      if (_looksLikeEmailSignInLink(raw)) {
        results.add(raw);
      }

      Uri parsed;
      try {
        parsed = Uri.parse(raw);
      } catch (_) {
        continue;
      }

      for (final String key in const <String>["link", "continueUrl"]) {
        final String? nested = parsed.queryParameters[key];
        if (nested == null || nested.trim().isEmpty) continue;
        queue.add(Uri.decodeComponent(nested));
      }

      if (parsed.scheme == "mjcinone" && parsed.host == "login") {
        final String? embedded = parsed.queryParameters["link"];
        if (embedded != null && embedded.trim().isNotEmpty) {
          queue.add(Uri.decodeComponent(embedded));
        }
      }
    }

    return results;
  }

  bool _looksLikeEmailSignInLink(String link) {
    return (link.contains("mode=signIn") || link.contains("mode%3DsignIn")) &&
        (link.contains("oobCode=") || link.contains("oobCode%3D"));
  }

  void _popLoginRouteIfPossible() {
    final NavigatorState? navigator = _navigatorKey?.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    }
  }

  void _queueSnackBar(String message) {
    _queuedSnackBarMessage = message;
  }

  void _flushQueuedSnackBar() {
    final String? message = _queuedSnackBarMessage;
    if (message == null) return;
    _queuedSnackBarMessage = null;

    final BuildContext? context = _navigatorKey?.currentContext;
    if (context == null) return;
    showMjcSnackBar(
      context,
      message: message,
      margin: _snackBarMargin(context),
      duration: const Duration(seconds: 4),
    );
  }

  /// [Navigator] 루트 context에는 [MainNavigationScope]가 없어 하단 네비 여백을 직접 맞춘다.
  EdgeInsets _snackBarMargin(BuildContext context) {
    if (MainNavigationScope.maybeNavigate(context) != null) {
      return MainNavLayout.snackBarMargin(context);
    }
    final NavigatorState? navigator = Navigator.maybeOf(context);
    if (navigator != null && !navigator.canPop()) {
      return EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MainNavLayout.bottomInset(context) + MainNavLayout.snackBarGapAboveNav,
      );
    }
    return const EdgeInsets.fromLTRB(16, 0, 16, 16);
  }
}
