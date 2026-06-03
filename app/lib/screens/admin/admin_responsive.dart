import "package:flutter/material.dart";
import "package:mjc_in_one/theme/app_colors.dart";

/// 관리자 콘솔: 이 너비 미만이면 모바일 레이아웃(하단 탭·풀스크린 편집 등).
const double kAdminMobileBreakpoint = 600;

bool adminIsMobile(BuildContext context) =>
    MediaQuery.sizeOf(context).width < kAdminMobileBreakpoint;

/// 다크 모드에서 [AppColors.primary]는 charcoal 배경 대비가 낮아 읽기 어렵습니다.
/// 관리자 콘솔(탭·버튼·상태 뱃지·TextButton 등)에만 밝은 accent를 씁니다.
ThemeData adminConsoleTheme(BuildContext context) {
  final ThemeData theme = Theme.of(context);
  if (theme.brightness != Brightness.dark) return theme;

  const Color accent = AppColors.switchActiveDark;
  final ColorScheme base = theme.colorScheme;
  final ColorScheme scheme = base.copyWith(
    primary: accent,
    onPrimary: Colors.white,
    primaryContainer: accent.withValues(alpha: 0.22),
    onPrimaryContainer: const Color(0xFFE8EEF9),
    secondary: accent,
    onSecondary: Colors.white,
  );

  return theme.copyWith(
    colorScheme: scheme,
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      selectedIconTheme: const IconThemeData(color: accent),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      selectedLabelTextStyle: theme.textTheme.labelMedium?.copyWith(
        color: accent,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: theme.textTheme.labelMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
  );
}
