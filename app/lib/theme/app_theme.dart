import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "app_colors.dart";

@immutable
class MjcSurfaceTokens extends ThemeExtension<MjcSurfaceTokens> {
  const MjcSurfaceTokens({
    required this.cardBorder,
    required this.hairline,
    required this.surfaceContainer,
    required this.sourceMjc,
    required this.sourceMpu,
    required this.sourceCtl,
    required this.foodAccent,
    required this.deadlineBadge,
    required this.dashboardGradients,
  });

  final Color cardBorder;
  final Color hairline;
  final Color surfaceContainer;
  final Color sourceMjc;
  final Color sourceMpu;
  final Color sourceCtl;
  final Color foodAccent;
  final Color deadlineBadge;
  final List<List<Color>> dashboardGradients;

  @override
  MjcSurfaceTokens copyWith({
    Color? cardBorder,
    Color? hairline,
    Color? surfaceContainer,
    Color? sourceMjc,
    Color? sourceMpu,
    Color? sourceCtl,
    Color? foodAccent,
    Color? deadlineBadge,
    List<List<Color>>? dashboardGradients,
  }) {
    return MjcSurfaceTokens(
      cardBorder: cardBorder ?? this.cardBorder,
      hairline: hairline ?? this.hairline,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      sourceMjc: sourceMjc ?? this.sourceMjc,
      sourceMpu: sourceMpu ?? this.sourceMpu,
      sourceCtl: sourceCtl ?? this.sourceCtl,
      foodAccent: foodAccent ?? this.foodAccent,
      deadlineBadge: deadlineBadge ?? this.deadlineBadge,
      dashboardGradients: dashboardGradients ?? this.dashboardGradients,
    );
  }

  @override
  MjcSurfaceTokens lerp(ThemeExtension<MjcSurfaceTokens>? other, double t) {
    if (other is! MjcSurfaceTokens) return this;
    return MjcSurfaceTokens(
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      surfaceContainer:
          Color.lerp(surfaceContainer, other.surfaceContainer, t)!,
      sourceMjc: Color.lerp(sourceMjc, other.sourceMjc, t)!,
      sourceMpu: Color.lerp(sourceMpu, other.sourceMpu, t)!,
      sourceCtl: Color.lerp(sourceCtl, other.sourceCtl, t)!,
      foodAccent: Color.lerp(foodAccent, other.foodAccent, t)!,
      deadlineBadge: Color.lerp(deadlineBadge, other.deadlineBadge, t)!,
      dashboardGradients: _lerpDashboardGradients(
          dashboardGradients, other.dashboardGradients, t),
    );
  }

  static List<List<Color>> _lerpDashboardGradients(
    List<List<Color>> a,
    List<List<Color>> b,
    double t,
  ) {
    final int groups = a.length < b.length ? a.length : b.length;
    return List<List<Color>>.generate(groups, (int groupIndex) {
      final List<Color> left = a[groupIndex];
      final List<Color> right = b[groupIndex];
      final int stops = left.length < right.length ? left.length : right.length;
      return List<Color>.generate(
        stops,
        (int stopIndex) => Color.lerp(left[stopIndex], right[stopIndex], t)!,
      );
    });
  }
}

const MjcSurfaceTokens _lightSurfaceTokens = MjcSurfaceTokens(
  cardBorder: Color(0xFFEDEDED),
  hairline: Color(0xFFEDEDED),
  surfaceContainer: Color(0xFFF0F1F4),
  sourceMjc: Color(0xFF1976D2),
  sourceMpu: Color(0xFF7986CB),
  sourceCtl: Color(0xFF2962FF),
  foodAccent: Color(0xFFE65100),
  deadlineBadge: Color(0xFF0D47A1),
  dashboardGradients: [
    [Color(0xFF0D47A1), Color(0xFF1976D2)],
    [Color(0xFF2962FF), Color(0xFF448AFF)],
    [Color(0xFF7986CB), Color(0xFF90A4AE)],
    [Color(0xFF0288D1), Color(0xFF26C6DA)],
  ],
);

const MjcSurfaceTokens _darkSurfaceTokens = MjcSurfaceTokens(
  cardBorder: AppColors.cardBorderDark,
  hairline: AppColors.cardBorderDark,
  surfaceContainer: AppColors.surfaceContainerDark,
  sourceMjc: Color(0xFF82B1FF),
  sourceMpu: Color(0xFFB0B6E0),
  sourceCtl: Color(0xFF82AEFF),
  foodAccent: Color(0xFFFFAB91),
  deadlineBadge: Color(0xFF1F4F9A),
  dashboardGradients: [
    [Color(0xFF15366B), Color(0xFF1B4787)],
    [Color(0xFF1A3D88), Color(0xFF2C5BB5)],
    [Color(0xFF3D4574), Color(0xFF5A6285)],
    [Color(0xFF0B5E80), Color(0xFF1A8AA0)],
  ],
);

ThemeData buildMjcTheme() {
  const primary = AppColors.primary;

  final base = ThemeData.light(useMaterial3: true);
  final textTheme = GoogleFonts.notoSansKrTextTheme(base.textTheme);

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.scaffoldMuted,
    textTheme: textTheme,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      surface: Colors.white,
      surfaceContainerLow: Color(0xFFF5F5F5),
      surfaceContainer: Color(0xFFF0F1F4),
      surfaceContainerHigh: Color(0xFFE9ECF1),
      onSurface: Color(0xDE000000),
      onSurfaceVariant: AppColors.mutedForeground,
      outline: Color(0xFFEDEDED),
      error: Color(0xFFD4183D),
      onError: Colors.white,
    ),
    extensions: const <ThemeExtension<dynamic>>[
      _lightSurfaceTokens,
    ],
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 6,
      shadowColor: Colors.black26,
      height: 56,
      indicatorColor: primary.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: selected ? primary : AppColors.mutedForeground,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? primary : AppColors.mutedForeground,
        );
      }),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return null;
        if (states.contains(WidgetState.selected)) return primary;
        // OFF: 흰 카드 위에서도 트랙·썸이 분리되어 보이게.
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return null;
        if (states.contains(WidgetState.selected)) {
          return primary.withValues(alpha: 0.45);
        }
        return const Color(0xFFD8DCE5);
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return null;
        if (states.contains(WidgetState.selected)) {
          return Colors.transparent;
        }
        return const Color(0xFF9AA3B2);
      }),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.black.withValues(alpha: 0.10),
      thickness: 1,
      space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  );
}

ThemeData buildMjcDarkTheme() {
  const primary = AppColors.primary;
  const secondary = AppColors.secondary;

  final base = ThemeData.dark(useMaterial3: true);
  final textTheme = GoogleFonts.notoSansKrTextTheme(base.textTheme);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.scaffoldMutedDark,
    textTheme: textTheme,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: Colors.white,
      surface: AppColors.cardDark,
      surfaceContainerLow: AppColors.scaffoldMutedDark,
      surfaceContainer: AppColors.surfaceContainerDark,
      surfaceContainerHigh: Color(0xFF303035),
      onSurface: Color(0xE6FFFFFF),
      onSurfaceVariant: AppColors.mutedForegroundDark,
      outline: AppColors.cardBorderDark,
      error: Color(0xFFFF6B7A),
      onError: Colors.white,
    ),
    extensions: const <ThemeExtension<dynamic>>[
      _darkSurfaceTokens,
    ],
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.cardDark,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.cardDark,
      elevation: 6,
      shadowColor: Colors.black54,
      height: 56,
      indicatorColor: AppColors.switchActiveDark.withValues(alpha: 0.22),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: selected
              ? AppColors.switchActiveDark
              : const Color(0xFF9AA4B2),
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected
              ? AppColors.switchActiveDark
              : const Color(0xFF9AA4B2),
        );
      }),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return null;
        if (states.contains(WidgetState.selected)) {
          return AppColors.switchActiveDark;
        }
        // OFF: 기본값은 배경과 붙어 비활성처럼 보임 — 일반 "꺼짐" 토글로 보이게 구분.
        return const Color(0xFFC8D0DA);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return null;
        if (states.contains(WidgetState.selected)) {
          return AppColors.switchActiveDark.withValues(alpha: 0.48);
        }
        return const Color(0xFF3E434C);
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return null;
        if (states.contains(WidgetState.selected)) {
          return Colors.transparent;
        }
        return const Color(0xFF6A717D);
      }),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF101826),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.white.withValues(alpha: 0.08),
      thickness: 1,
      space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  );
}
