import "dart:async";

import "package:app_links/app_links.dart";
import "package:flutter/material.dart";
import "package:mio_notice/services/auth_service.dart";
import "package:mio_notice/services/user_data_repository.dart";

class DeepLinkHandler {
  DeepLinkHandler._();

  static final DeepLinkHandler instance = DeepLinkHandler._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  GlobalKey<NavigatorState>? _navigatorKey;
  String? _lastHandledLink;

  Future<void> start(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;
    _subscription ??= _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (Object error) => _showSnackBar("로그인 링크 처리 중 오류가 발생했습니다."),
    );

    final Uri? initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      await _handleUri(initialUri);
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _handleUri(Uri uri) async {
    final String link = _extractFirebaseEmailLink(uri);
    if (link.isEmpty || link == _lastHandledLink) return;
    _lastHandledLink = link;

    final AuthService auth = AuthService.instance;
    if (!auth.isSignInLink(link)) return;

    try {
      final credential = await auth.completeSignIn(link);
      final user = credential.user;
      if (user != null) {
        await UserDataRepository.instance.hydrateFromCloudOnLogin(user);
      }
      _popLoginRouteIfPossible();
      _showSnackBar("로그인되었습니다.");
    } on MissingPendingEmailException {
      _showSnackBar("먼저 이 기기에서 로그인 링크를 요청해 주세요.");
    } on MjcDomainException {
      _showSnackBar("@mjc.ac.kr 이메일만 로그인할 수 있습니다.");
    } catch (_) {
      _showSnackBar("로그인 링크가 만료되었거나 유효하지 않습니다.");
    }
  }

  String _extractFirebaseEmailLink(Uri uri) {
    if (uri.scheme == "mjcinone" && uri.host == "login") {
      final String? embedded = uri.queryParameters["link"];
      if (embedded != null && embedded.trim().isNotEmpty) {
        return Uri.decodeComponent(embedded);
      }
      return "";
    }
    return uri.toString();
  }

  void _popLoginRouteIfPossible() {
    final NavigatorState? navigator = _navigatorKey?.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    }
  }

  void _showSnackBar(String message) {
    final BuildContext? context = _navigatorKey?.currentContext;
    if (context == null) return;
    final ScaffoldMessengerState? messenger =
        ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }
}
