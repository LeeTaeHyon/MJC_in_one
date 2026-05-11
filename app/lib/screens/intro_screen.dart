import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:mio_notice/screens/main_navigation_screen.dart";
import "package:mio_notice/theme/app_colors.dart";
import "package:mio_notice/theme/app_theme.dart";

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  bool _navigated = false;

  void _goNext() {
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
    final titleStyle = Theme.of(context).textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
          height: 1.0,
          color: Colors.white,
          fontSize: 52,
        ) ??
        const TextStyle(
          fontFamily: kPretendardFontFamily,
          fontSize: 52,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
          height: 1.0,
          color: Colors.white,
        );

    final subtitleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          height: 1.3,
          color: Colors.white.withValues(alpha: 0.85),
        ) ??
        TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          height: 1.3,
          color: Colors.white.withValues(alpha: 0.85),
        );

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.introBackground,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "MJC ONE",
                    textAlign: TextAlign.center,
                    style: titleStyle,
                  )
                      .animate(
                        onComplete: (controller) => _goNext(),
                      )
                      .fadeIn(duration: 520.ms, curve: Curves.easeOut)
                      .slideX(
                        begin: -0.55,
                        end: 0,
                        duration: 700.ms,
                        curve: Curves.easeOutCubic,
                      ),
                  const SizedBox(height: 12),
                  Text(
                    "명지전문대학 통합 서비스",
                    textAlign: TextAlign.center,
                    style: subtitleStyle,
                  )
                      .animate()
                      .fadeIn(
                        delay: 240.ms,
                        duration: 520.ms,
                        curve: Curves.easeOut,
                      )
                      .slideX(
                        begin: -0.45,
                        end: 0,
                        delay: 240.ms,
                        duration: 680.ms,
                        curve: Curves.easeOutCubic,
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

