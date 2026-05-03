import "package:flutter/material.dart";

class PinFavoriteButtons extends StatelessWidget {
  const PinFavoriteButtons({
    super.key,
    required this.isPinned,
    required this.isFavorite,
    required this.onTogglePinned,
    required this.onToggleFavorite,
    this.pinnedColor,
    this.favoriteColor,
  });

  final bool isPinned;
  final bool isFavorite;
  final VoidCallback onTogglePinned;
  final VoidCallback onToggleFavorite;
  final Color? pinnedColor;
  final Color? favoriteColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color favC = favoriteColor ?? const Color(0xFFFFC107);
    final Color pinC = pinnedColor ?? const Color(0xFFE53935);

    Widget action({
      required IconData icon,
      required bool active,
      required VoidCallback onTap,
      required String tooltip,
      required Color activeColor,
    }) {
      final Color fg = active
          ? activeColor
          : scheme.onSurfaceVariant.withValues(alpha: 0.72);
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Tooltip(
              message: tooltip,
              child: Icon(icon, size: 18, color: fg),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: isDark ? 0.96 : 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.70)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          action(
            icon: isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
            active: isFavorite,
            onTap: onToggleFavorite,
            tooltip: "즐겨찾기",
            activeColor: favC,
          ),
          action(
            icon: isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            active: isPinned,
            onTap: onTogglePinned,
            tooltip: "상단 고정",
            activeColor: pinC,
          ),
        ],
      ),
    );
  }
}
