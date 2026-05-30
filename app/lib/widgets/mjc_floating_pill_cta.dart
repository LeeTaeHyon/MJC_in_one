import "package:flutter/material.dart";
import "package:mjc_in_one/theme/app_theme.dart";

enum MjcFloatingPillCtaVariant {
  /// 문의 등 — 가로 전체 pill + surface 배경.
  surfaceWide,

  /// 공지 상세 — primary 채움, 콘텐츠 너비 capsule.
  primaryCompact,
}

/// 공지 상세 「본문 보기」, 문의 「문의 보내기」 등 하단 플로팅 pill CTA.
class MjcFloatingPillCta extends StatelessWidget {
  const MjcFloatingPillCta({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
    this.enabled = true,
    this.loading = false,
    this.variant = MjcFloatingPillCtaVariant.surfaceWide,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;
  final bool loading;
  final MjcFloatingPillCtaVariant variant;

  bool get _highlighted => enabled && !loading && onTap != null;

  @override
  Widget build(BuildContext context) {
    if (variant == MjcFloatingPillCtaVariant.primaryCompact) {
      return _buildPrimaryCompact(context);
    }
    return _buildSurfaceWide(context);
  }

  Widget _buildPrimaryCompact(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color background = _highlighted
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: 0.28);
    final Color foreground =
        _highlighted ? Colors.white : Colors.white.withValues(alpha: 0.72);

    return Material(
      color: background,
      elevation: _highlighted ? 6 : 0,
      shadowColor: scheme.primary.withValues(alpha: 0.35),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _highlighted ? onTap : null,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                )
              else
                Icon(icon, size: 20, color: foreground),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSurfaceWide(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final MjcComponentTokens components =
        theme.extension<MjcComponentTokens>()!;
    final MjcSurfaceTokens surfaceTokens =
        theme.extension<MjcSurfaceTokens>()!;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color accent = components.bottomNavSelected;

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Material(
          color: scheme.surface.withValues(alpha: isDark ? 0.98 : 0.96),
          elevation: 10,
          shadowColor: components.noticeSubNavShadow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: surfaceTokens.hairline, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            child: InkWell(
              onTap: _highlighted ? onTap : null,
              borderRadius: BorderRadius.circular(28),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                curve: Curves.easeOutCubic,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _highlighted
                      ? accent.withValues(alpha: isDark ? 0.20 : 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                  border: _highlighted
                      ? Border.all(
                          color: accent.withValues(
                            alpha: isDark ? 0.35 : 0.18,
                          ),
                        )
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (loading)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.onSurfaceVariant
                              .withValues(alpha: 0.45),
                        ),
                      )
                    else
                      Icon(
                        icon,
                        size: 18,
                        color: _highlighted
                            ? accent
                            : scheme.onSurfaceVariant
                                .withValues(alpha: 0.45),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: _highlighted
                            ? accent
                            : scheme.onSurfaceVariant
                                .withValues(alpha: 0.45),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
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

/// 하단 플로팅 CTA 배치·스크롤 패딩 상수.
abstract final class MjcFloatingCtaLayout {
  static const double height = 50;
  static const double compactHeight = 44;
  static const double bottomGap = 12;
  static const double horizontalInset = 18;

  static double positionedBottom(BuildContext context) {
    return MediaQuery.paddingOf(context).bottom + bottomGap;
  }

  static double scrollBottomPadding(
    BuildContext context, {
    double buttonHeight = height,
  }) {
    return MediaQuery.paddingOf(context).bottom + bottomGap + buttonHeight + 16;
  }
}
