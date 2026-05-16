import "package:flutter/material.dart";
import "package:lottie/lottie.dart";
import "package:mjc_in_one/screens/main_navigation_screen.dart";
import "package:mjc_in_one/services/firebase_app_startup.dart";
import "package:mjc_in_one/theme/app_colors.dart";

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  static const String _kLottieAsset = "assets/lottie/MJC ONE App intro.json";

  /// Lottie 재생 시작 전·종료 후 각각 이 만큼 멈춤.
  static const Duration _kIntroEdgeDelay = Duration(milliseconds: 200);

  bool _navigated = false;
  bool _lottiePlaybackStarted = false;
  Future<void>? _exitFuture;
  late final AnimationController _lottieController;

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _lottieController.dispose();
    super.dispose();
  }

  Future<void> _goNextAfterFirebase() {
    return _exitFuture ??= _exitAfterFirebaseImpl();
  }

  Future<void> _exitAfterFirebaseImpl() async {
    await waitForFirebaseStartup();
    if (_navigated || !mounted) return;
    _navigated = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const MainNavigationScreen(),
        transitionDuration: const Duration(milliseconds: 250),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final double lottieSide = media.shortestSide * 0.72;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.introBackground,
        body: Center(
          child: SizedBox(
            width: lottieSide,
            height: lottieSide,
            child: Lottie.asset(
              _kLottieAsset,
              controller: _lottieController,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              onLoaded: (composition) {
                if (_lottiePlaybackStarted) return;
                _lottiePlaybackStarted = true;
                _lottieController.duration = composition.duration;
                Future<void>.delayed(_kIntroEdgeDelay, () {
                  if (!mounted) return;
                  _lottieController.forward().whenComplete(() {
                    if (!mounted) return;
                    Future<void>.delayed(_kIntroEdgeDelay, () {
                      if (mounted) _goNextAfterFirebase();
                    });
                  });
                });
              },
              errorBuilder: (context, error, stackTrace) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _goNextAfterFirebase();
                });
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
  }
}
