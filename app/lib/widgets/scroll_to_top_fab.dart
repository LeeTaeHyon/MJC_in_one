import "package:flutter/material.dart";
import "package:mio_notice/theme/app_colors.dart";
import "package:mio_notice/widgets/scroll_to_top_scope.dart";

/// [ScrollToTopCoordinator]에 등록된 대상으로 스크롤·웹뷰를 맨 위로 올립니다.
/// [ScrollToTopCoordinator.fabRevealScrollViewportFraction] 만큼 뷰포트 높이를 넘기면 보입니다.
class ScrollToTopFab extends StatelessWidget {
  const ScrollToTopFab({super.key});

  @override
  Widget build(BuildContext context) {
    final ScrollToTopCoordinator coordinator = ScrollToTopScope.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: coordinator.fabVisibleNotifier,
      builder: (BuildContext context, bool visible, Widget? child) {
        if (!visible) return const SizedBox.shrink();
        return child!;
      },
      child: Material(
        elevation: 6,
        shadowColor: Colors.black26,
        shape: const CircleBorder(),
        color: AppColors.primary,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => coordinator.scrollToTop(),
          splashColor: Colors.white.withValues(alpha: 0.28),
          highlightColor: Colors.white.withValues(alpha: 0.14),
          child: Tooltip(
            message: "맨 위로",
            child: Semantics(
              button: true,
              label: "맨 위로 스크롤",
              child: const SizedBox(
                width: 46,
                height: 46,
                child: Icon(
                  Icons.vertical_align_top_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
