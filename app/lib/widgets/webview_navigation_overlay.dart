import "package:flutter/material.dart";
import "package:mjc_in_one/theme/app_colors.dart";

/// 웹뷰 위 왼쪽 하단 뒤로/앞으로 플로팅 컨트롤.
class WebViewNavigationOverlay extends StatelessWidget {
  final bool canGoBack;
  final bool canGoForward;
  final Future<void> Function() onGoBack;
  final Future<void> Function() onGoForward;
  final Color activeColor;

  const WebViewNavigationOverlay({
    super.key,
    required this.canGoBack,
    required this.canGoForward,
    required this.onGoBack,
    required this.onGoForward,
    this.activeColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color disabled = scheme.onSurfaceVariant.withValues(alpha: 0.35);
    return Positioned(
      left: 12,
      bottom: 12 + MediaQuery.paddingOf(context).bottom,
      child: Material(
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.26),
        borderRadius: BorderRadius.circular(24),
        color: scheme.surface,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: "뒤로",
              visualDensity: VisualDensity.compact,
              onPressed: canGoBack ? () => onGoBack() : null,
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: canGoBack ? activeColor : disabled,
              ),
            ),
            SizedBox(
              height: 28,
              child: VerticalDivider(
                width: 1,
                thickness: 1,
                color: scheme.outline.withValues(alpha: 0.70),
              ),
            ),
            IconButton(
              tooltip: "앞으로",
              visualDensity: VisualDensity.compact,
              onPressed: canGoForward ? () => onGoForward() : null,
              icon: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: canGoForward ? activeColor : disabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
