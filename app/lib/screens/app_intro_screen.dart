import "package:flutter/material.dart";
import "package:mjc_in_one/screens/main_navigation_screen.dart";
import "package:mjc_in_one/widgets/main_navigation_scope.dart";
import "package:mjc_in_one/widgets/mjc_floating_pill_cta.dart";
import "package:mjc_in_one/widgets/scroll_to_top_scope.dart";
import "package:shared_preferences/shared_preferences.dart";

const String kAppGuideSeenPrefKey = "app_guide_seen";

/// 앱 최초 실행·더보기 «도움말»에서 열리는 가이드 화면.
class AppIntroScreen extends StatelessWidget {
  const AppIntroScreen({
    super.key,
    this.isFirstLaunch = false,
    this.onNavigate,
  });

  /// [IntroScreen] 이후 첫 실행 전용. 완료 시 메인으로 교체합니다.
  final bool isFirstLaunch;

  /// 더보기 등 푸시 라우트 위에서 열릴 때 홈 탭 전환 콜백.
  final MainNavigationNavigate? onNavigate;

  static const String _guideAsset = "assets/images/guide.png";
  static const Duration _routeDuration = Duration(milliseconds: 220);

  static Future<bool> shouldShowOnFirstLaunch() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kAppGuideSeenPrefKey) != true;
  }

  static Future<void> markSeen() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kAppGuideSeenPrefKey, true);
  }

  /// 진입·퇴장(축소+페이드) 애니메이션이 적용된 라우트.
  static Route<void> route({
    bool isFirstLaunch = false,
    MainNavigationNavigate? onNavigate,
  }) {
    return PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => AppIntroScreen(
        isFirstLaunch: isFirstLaunch,
        onNavigate: onNavigate,
      ),
      transitionDuration: _routeDuration,
      reverseTransitionDuration: _routeDuration,
      transitionsBuilder: (_, animation, __, child) {
        final CurvedAnimation curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  static Route<void> _mainAfterIntroRoute() {
    return PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => const MainNavigationScreen(),
      transitionDuration: _routeDuration,
      reverseTransitionDuration: Duration.zero,
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: child,
        );
      },
    );
  }

  Future<void> _goHome(BuildContext context) async {
    if (isFirstLaunch) {
      await markSeen();
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(_mainAfterIntroRoute());
      return;
    }

    final MainNavigationNavigate? navigate =
        onNavigate ?? MainNavigationScope.maybeNavigate(context);
    Navigator.of(context).popUntil((route) => route.isFirst);
    navigate?.call(MainNavTabIndex.home);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isFirstLaunch,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("앱 소개"),
          automaticallyImplyLeading: !isFirstLaunch,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                0,
                0,
                0,
                MjcFloatingCtaLayout.scrollBottomPadding(
                  context,
                  buttonHeight: MjcFloatingCtaLayout.compactHeight,
                ),
              ),
              child: Image.asset(
                _guideAsset,
                fit: BoxFit.fitWidth,
                width: double.infinity,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: MjcFloatingCtaLayout.positionedBottom(context),
              child: Center(
                child: MjcFloatingPillCta(
                  variant: MjcFloatingPillCtaVariant.primaryCompact,
                  label: "홈으로 가기",
                  icon: Icons.home_rounded,
                  onTap: () => _goHome(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
