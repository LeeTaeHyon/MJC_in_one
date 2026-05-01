import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:mio_notice/screens/main_navigation_screen.dart";
import "package:mio_notice/theme/app_colors.dart";
import "package:google_fonts/google_fonts.dart";

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
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
        GoogleFonts.notoSansKr(
          fontSize: 52,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
          height: 1.0,
          color: Colors.white,
        );

    final subtitleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w300,
          height: 1.25,
          color: Colors.white70,
        ) ??
        const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w300,
          height: 1.25,
          color: Colors.white70,
        );

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: SafeArea(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.secondary.withValues(alpha: 0.92),
                  const Color(0xFF0B1B3A),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("MJC in one", style: titleStyle)
                        .animate(
                          onComplete: (controller) => _goNext(),
                        )
                        .fadeIn(duration: 520.ms, curve: Curves.easeOut)
                        .slideX(
                          begin: -0.12,
                          end: 0,
                          duration: 650.ms,
                          curve: Curves.easeOutCubic,
                        ),
                    const SizedBox(height: 10),
                    Text("명지전문대학 통합 플랫폼", style: subtitleStyle)
                        .animate()
                        .fadeIn(
                          delay: 220.ms,
                          duration: 520.ms,
                          curve: Curves.easeOut,
                        )
                        .slideX(
                          begin: -0.10,
                          end: 0,
                          delay: 220.ms,
                          duration: 650.ms,
                          curve: Curves.easeOutCubic,
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

