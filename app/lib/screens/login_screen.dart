import "dart:async";

import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:mjc_in_one/screens/common_webview_screen.dart";
import "package:mjc_in_one/screens/main_navigation_screen.dart";
import "package:mjc_in_one/services/auth_service.dart";
import "package:mjc_in_one/services/legal_consent_service.dart";
import "package:mjc_in_one/theme/app_colors.dart";
import "package:mjc_in_one/theme/app_theme.dart";
import "package:mjc_in_one/utils/mjc_snack_bar.dart";
import "package:mjc_in_one/widgets/legal_consent_row.dart";

/// 홈 대시보드 [_kHomeHeaderBottomRadius]와 동일한 상단 카드 라운드.
const double _kLoginSheetTopRadius = 30;

/// 파란 헤더 위로 흰 로그인 시트가 겹치는 높이 ([home_dashboard_screen] 패턴).
const double _kLoginSheetOverlap = 24;

/// [more_tab_screen] 로그인 배너와 동일한 헤더 그래디언트.
const LinearGradient _kLoginHeaderGradientLight = LinearGradient(
  colors: <Color>[Color(0xFF2563EB), Color(0xFF1D4ED8)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient _kLoginHeaderGradientDark = LinearGradient(
  colors: <Color>[Color(0xFF1D4ED8), Color(0xFF073A8C)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final ScrollController _sheetScrollController = ScrollController();
  final GlobalKey _emailFieldKey = GlobalKey();
  bool _sending = false;
  bool _sent = false;
  String? _errorText;
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;
  bool _consentAccepted = false;
  String _termsUrl = kTermsOfServiceUrlFallback;
  String _privacyUrl = kPrivacyPolicyUrlFallback;

  @override
  void initState() {
    super.initState();
    _loadConsentState();
    _emailFocusNode.addListener(_scrollEmailIntoView);
  }

  void _scrollEmailIntoView() {
    if (!_emailFocusNode.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final BuildContext? fieldContext = _emailFieldKey.currentContext;
      if (fieldContext == null) return;
      Scrollable.ensureVisible(
        fieldContext,
        alignment: 0.15,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _loadConsentState() async {
    final bool accepted =
        await LegalConsentService.instance.hasValidLocalConsent();
    final String termsUrl =
        await LegalConsentService.instance.resolveTermsUrl();
    final String privacyUrl =
        await LegalConsentService.instance.resolvePrivacyUrl();
    if (!mounted) return;
    setState(() {
      _consentAccepted = accepted;
      _termsUrl = termsUrl;
      _privacyUrl = privacyUrl;
    });
  }

  void _openLegalPage({required String url, required String title}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CommonWebViewScreen(url: url, title: title),
      ),
    );
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailFocusNode.removeListener(_scrollEmailIntoView);
    _emailFocusNode.dispose();
    _sheetScrollController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 30);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds -= 1);
      }
    });
  }

  /// 로그아웃 등으로 스택에 이 화면만 남은 경우 [maybePop]이 동작하지 않아,
  /// 메인 셸로 되돌립니다.
  void _leaveLoginOrPop(BuildContext context) {
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const MainNavigationScreen(),
      ),
    );
  }

  Future<void> _sendLoginLink() async {
    if (!_consentAccepted) {
      showMjcSnackBar(
        context,
        message: "약관 및 개인정보 처리에 동의해 주세요.",
      );
      return;
    }

    final String email = _emailController.text.trim().toLowerCase();
    setState(() {
      _errorText = null;
      _sending = true;
    });

    try {
      await LegalConsentService.instance.recordLocalConsent();
      await AuthService.instance.sendMagicLink(email);
      if (!mounted) return;
      setState(() => _sent = true);
      _startCooldown();
      showMjcSnackBar(context, message: "로그인 링크를 이메일로 보냈습니다.");
    } on MjcDomainException {
      if (!mounted) return;
      setState(() => _errorText = "@mjc.ac.kr 이메일만 가능합니다.");
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = e.message ?? "로그인 링크 발송에 실패했습니다.";
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorText = "로그인 링크 발송에 실패했습니다.");
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  LinearGradient _headerGradient(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? _kLoginHeaderGradientDark : _kLoginHeaderGradientLight;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final NavigatorState navigator = Navigator.of(context);
    final LinearGradient headerGradient = _headerGradient(context);
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double keyboardInset = mediaQuery.viewInsets.bottom;
    final double headerHeight = mediaQuery.size.height * 0.38;
    final double baseSheetTop = headerHeight - _kLoginSheetOverlap;
    final double minSheetTop = mediaQuery.padding.top + 44;
    final double sheetTop = keyboardInset > 0
        ? (baseSheetTop - keyboardInset).clamp(minSheetTop, baseSheetTop)
        : baseSheetTop;

    return PopScope(
      canPop: navigator.canPop(),
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _leaveLoginOrPop(context);
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        resizeToAvoidBottomInset: true,
        body: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: headerHeight + _kLoginSheetOverlap,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(_kLoginSheetTopRadius),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: headerGradient,
                          ),
                        ),
                        SafeArea(
                          bottom: false,
                          child: Column(
                            children: <Widget>[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  color: Colors.white,
                                  onPressed: () => _leaveLoginOrPop(context),
                                  tooltip: "뒤로",
                                ),
                              ),
                              const Spacer(),
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.all(10),
                                child: Image.asset(
                                  "assets/images/app_logo.png",
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                "MJC ONE",
                                style: TextStyle(
                                  fontFamily: kPretendardFontFamily,
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "명지전문대학교 소식과 정보를",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: kPretendardFontFamily,
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  height: 1.45,
                                ),
                              ),
                              Text(
                                "한곳에서 확인할 수 있는 앱입니다.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: kPretendardFontFamily,
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  height: 1.45,
                                ),
                              ),
                              const Spacer(flex: 2),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  top: sheetTop,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(_kLoginSheetTopRadius),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: SingleChildScrollView(
                        controller: _sheetScrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(24, 28, 24, 24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: _LoginForm(
                              emailController: _emailController,
                              emailFocusNode: _emailFocusNode,
                              emailFieldKey: _emailFieldKey,
                              sending: _sending,
                              sent: _sent,
                              errorText: _errorText,
                              cooldownSeconds: _cooldownSeconds,
                              consentAccepted: _consentAccepted,
                              onConsentChanged: (bool? value) {
                                setState(
                                    () => _consentAccepted = value ?? false);
                              },
                              onOpenTerms: () => _openLegalPage(
                                url: _termsUrl,
                                title: "서비스 이용약관",
                              ),
                              onOpenPrivacy: () => _openLegalPage(
                                url: _privacyUrl,
                                title: "개인정보처리방침",
                              ),
                              onSend: _sendLoginLink,
                              onBrowse: () => _leaveLoginOrPop(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.emailController,
    required this.emailFocusNode,
    required this.emailFieldKey,
    required this.sending,
    required this.sent,
    required this.errorText,
    required this.cooldownSeconds,
    required this.consentAccepted,
    required this.onConsentChanged,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
    required this.onSend,
    required this.onBrowse,
  });

  final TextEditingController emailController;
  final FocusNode emailFocusNode;
  final GlobalKey emailFieldKey;
  final bool sending;
  final bool sent;
  final String? errorText;
  final int cooldownSeconds;
  final bool consentAccepted;
  final ValueChanged<bool?> onConsentChanged;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;
  final VoidCallback onSend;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accentBlue =
        isDark ? AppColors.switchActiveDark : AppColors.primary;
    final bool canSend =
        consentAccepted && !sending && cooldownSeconds == 0;
    final Color mutedText = cs.onSurface.withValues(alpha: 0.55);
    final Color borderColor = cs.onSurface.withValues(alpha: 0.14);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text(
          "이메일 로그인",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: kPretendardFontFamily,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "명지전문대학 이메일로 받은 링크를 열면 로그인됩니다.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: kPretendardFontFamily,
            color: mutedText,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 22),
        TextField(
          key: emailFieldKey,
          controller: emailController,
          focusNode: emailFocusNode,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const <String>[AutofillHints.email],
          style: const TextStyle(
            fontFamily: kPretendardFontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          onSubmitted: (_) {
            if (canSend) onSend();
          },
          decoration: InputDecoration(
            hintText: "name@mjc.ac.kr",
            hintStyle: TextStyle(
              fontFamily: kPretendardFontFamily,
              color: mutedText.withValues(alpha: 0.75),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              Icons.mail_outline_rounded,
              color: mutedText,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: accentBlue, width: 1.5),
            ),
          ),
        ),
        if (errorText != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            errorText!,
            style: const TextStyle(
              fontFamily: kPretendardFontFamily,
              color: Color(0xFFD4183D),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (sent) ...<Widget>[
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: accentBlue.withValues(alpha: isDark ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.mark_email_read_outlined,
                    color: accentBlue,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "메일함에서 로그인 링크를 확인해 주세요.",
                      style: TextStyle(
                        fontFamily: kPretendardFontFamily,
                        color: cs.onSurface.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        LegalConsentRow(
          value: consentAccepted,
          onChanged: onConsentChanged,
          onOpenTerms: onOpenTerms,
          onOpenPrivacy: onOpenPrivacy,
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 54,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor:
                  AppColors.primary.withValues(alpha: 0.35),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: canSend ? onSend : null,
            child: sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    cooldownSeconds > 0
                        ? "$cooldownSeconds초 후 다시 보내기"
                        : (sent ? "로그인 링크 다시 받기" : "로그인 링크 받기"),
                    style: const TextStyle(
                      fontFamily: kPretendardFontFamily,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 54,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: accentBlue,
              side: BorderSide(
                color: accentBlue.withValues(alpha: 0.55),
              ),
              backgroundColor: cs.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: onBrowse,
            child: const Text(
              "둘러보기",
              style: TextStyle(
                fontFamily: kPretendardFontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.lock_outline_rounded,
              size: 14,
              color: mutedText,
            ),
            const SizedBox(width: 6),
            Text(
              "학교 이메일로 안전하게 이용할 수 있습니다.",
              style: TextStyle(
                fontFamily: kPretendardFontFamily,
                color: mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
