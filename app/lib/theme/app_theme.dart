import "package:flutter/material.dart";

import "app_colors.dart";

/// Bundled [Pretendard](https://github.com/orioncactus/pretendard) (SIL OFL).
const String kPretendardFontFamily = "Pretendard";

/// Text styles that must stay centralized per project rules.
abstract final class MjcAppTypography {
  static const List<Shadow> homeHeroCollapsedTitleShadows = <Shadow>[
    Shadow(blurRadius: 6, color: Color(0x66000000)),
  ];

  /// Collapsed home hero title — «MJC».
  static TextStyle homeHeroCollapsedTitleMjc({required Color color}) =>
      TextStyle(
        fontFamily: kPretendardFontFamily,
        color: color,
        fontSize: 20,
        fontWeight: FontWeight.w900,
        height: 1.1,
        shadows: homeHeroCollapsedTitleShadows,
      );

  /// Collapsed home hero title — space or other middle segments.
  static TextStyle homeHeroCollapsedTitleMid({required Color color}) =>
      TextStyle(
        fontFamily: kPretendardFontFamily,
        color: color,
        fontSize: 20,
        fontWeight: FontWeight.w500,
        height: 1.1,
        shadows: homeHeroCollapsedTitleShadows,
      );

  /// Collapsed home hero title — «ONE».
  static TextStyle homeHeroCollapsedTitleOne({required Color color}) =>
      TextStyle(
        fontFamily: kPretendardFontFamily,
        color: color,
        fontSize: 20,
        fontWeight: FontWeight.w300,
        height: 1.1,
        shadows: homeHeroCollapsedTitleShadows,
      );

  /// Home dashboard greeting under the brand row (solid blue header).
  static TextStyle homeDashboardGreeting({required Color color}) =>
      TextStyle(
        fontFamily: kPretendardFontFamily,
        color: color,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: -0.18,
      );
}

// Theme owns the final “source of truth” for UI tokens used across screens.
// Keep concrete values here and consume them via Theme/Extensions.

// ---- Color tokens (light) ----
const Color _kCardBorderLight = Color(0xFFEDEDED);
const Color _kSurfaceContainerLowLight = Color(0xFFF5F5F5);
const Color _kSurfaceContainerLight = Color(0xFFF0F1F4);
const Color _kSurfaceContainerHighLight = Color(0xFFE9ECF1);
const Color _kOnSurfaceLight = Color(0xDE000000);
const Color _kErrorLight = Color(0xFFD4183D);

/// 공지·바로가기 색상 — **이 클래스만** 수정하면 MJC / CTL / MPU · [main_website_screen] 공지 UI에 반영됩니다.
///
/// - `*Home` : 레거시·기타 (홈·더보기 바로가기 accent는 [_kDashboardGradientsLight])
/// - `*Ui`   : 공지 탭·컬러바·새로고침·검색 (Home보다 연한 톤)
abstract final class MjcNoticePalette {
  /// 본교 공지 ([main_website_screen], 홈 «본교 공지»).
  static const Color mjcHome = AppColors.primary;
  static const Color mjcUiLight = Color(0xFF4B74C8);
  static const Color mjcUiDark = Color(0xFF82A8F0);

  /// 교수학습 ([ctl_screen], 홈 «교수학습»).
  static const Color ctlHome = Color(0xFF7357A0);
  static const Color ctlUiLight = Color(0xFF9178AB);
  static const Color ctlUiDark = Color(0xFFB5A3C8);

  /// 역량관리 ([mpu_screen], 홈 «역량관리»).
  static const Color mpuHome = Color(0xFFD97706);
  static const Color mpuUiLight = Color(0xFFE0944F);
  static const Color mpuUiDark = Color(0xFFF0B889);

  /// 읽은 공지 제목 (모든 공지 리스트·검색 카드 공통).
  static const Color readTitleLight = Color(0xFF8E7AA8);
  static const Color readTitleDark = Color(0xFFB8A8C8);
}

const Color _kSourceMjcLight = MjcNoticePalette.mjcUiLight;
const Color _kSourceCtlLight = MjcNoticePalette.ctlUiLight;
const Color _kSourceMpuLight = MjcNoticePalette.mpuUiLight;
const Color _kFoodAccentLight = Color(0xFFE65100);
const Color _kDeadlineBadgeLight = Color(0xFF0D47A1);

/// 홈·더보기 바로가기 accent — [home_dashboard_screen], [more_tab_screen].
/// 색 변경은 **이 배열(라이트·다크)** 만 수정하면 됩니다.
const List<List<Color>> _kDashboardGradientsLight = [
  [Color(0xFF2563EB)], // 0 본교 공지
  [Color(0xFF7357A0)], // 1 교수학습
  [Color(0xFFD97706)], // 2 역량관리
  [Color(0xFF4F46E5)], // 3 도서관
  [Color(0xFFDC2626)], // 4 학사일정
  [Color(0xFF0F766E)], // 5 캠퍼스 약도
];

// ---- Color tokens (dark) ----
const Color _kSourceMjcDark = MjcNoticePalette.mjcUiDark;
const Color _kSourceCtlDark = MjcNoticePalette.ctlUiDark;
const Color _kSourceMpuDark = MjcNoticePalette.mpuUiDark;
const Color _kNoticeReadTitleLight = MjcNoticePalette.readTitleLight;
const Color _kNoticeReadTitleDark = MjcNoticePalette.readTitleDark;
const Color _kFoodAccentDark = Color(0xFFFFAB91);
const Color _kDeadlineBadgeDark = Color(0xFF1F4F9A);

const List<List<Color>> _kDashboardGradientsDark = [
  [Color(0xFF2563EB)], // 0 본교 공지
  [Color(0xFF7357A0)], // 1 교수학습
  [Color(0xFFD97706)], // 2 역량관리
  [Color(0xFF4F46E5)], // 3 도서관
  [Color(0xFFDC2626)], // 4 학사일정
  [Color(0xFF0F766E)], // 5 캠퍼스 약도
];

const Color _kBottomNavUnselectedDark = Color(0xFF9AA4B2);

/// 마이페이지 «고정·즐겨찾기 공지» `TabBar` — 다크 모드 미선택 라벨·아이콘.
const Color kMjcMyPageBookmarkTabUnselectedDark = Color(0xFF9AA4B2);

/// 마이페이지 «고정·즐겨찾기 공지» `TabBar` — 다크 모드 선택 탭·인디케이터.
const Color kMjcMyPageBookmarkTabSelectedDark = Color(0xFF82B1FF);

const Color _kSubNavShadowLight = Color(0x33000000); // ~20% black
const Color _kSubNavShadowDark = Color(0x8A000000); // ~54% black

const Color _kSwitchTrackOffLight = Color(0xFFD8DCE5);
const Color _kSwitchOutlineOffLight = Color(0xFF9AA3B2);
const Color _kSwitchTrackOffDark = Color(0xFF3E434C);
const Color _kSwitchOutlineOffDark = Color(0xFF6A717D);

const Color _kSurfaceContainerHighDark = Color(0xFF303035);
const Color _kOnSurfaceDark = Color(0xE6FFFFFF);
const Color _kErrorDark = Color(0xFFFF6B7A);
const Color _kCardDarkAlt = Color(0xFF16181C);
@immutable
class MjcTextTokens extends ThemeExtension<MjcTextTokens> {
  const MjcTextTokens({
    required this.appBarTitle,
    required this.navLabel,
  });

  final TextStyle appBarTitle;
  final TextStyle navLabel;

  @override
  MjcTextTokens copyWith({
    TextStyle? appBarTitle,
    TextStyle? navLabel,
  }) {
    return MjcTextTokens(
      appBarTitle: appBarTitle ?? this.appBarTitle,
      navLabel: navLabel ?? this.navLabel,
    );
  }

  @override
  MjcTextTokens lerp(ThemeExtension<MjcTextTokens>? other, double t) {
    if (other is! MjcTextTokens) return this;
    return MjcTextTokens(
      appBarTitle: TextStyle.lerp(appBarTitle, other.appBarTitle, t)!,
      navLabel: TextStyle.lerp(navLabel, other.navLabel, t)!,
    );
  }
}

@immutable
class MjcSurfaceTokens extends ThemeExtension<MjcSurfaceTokens> {
  const MjcSurfaceTokens({
    required this.cardBorder,
    required this.hairline,
    required this.surfaceContainer,
    required this.sourceMjc,
    required this.sourceMpu,
    required this.sourceCtl,
    required this.noticeReadTitle,
    required this.foodAccent,
    required this.deadlineBadge,
    required this.dashboardGradients,
  });

  final Color cardBorder;
  final Color hairline;
  final Color surfaceContainer;
  /// 본교 공지 UI 액센트 — [MjcNoticePalette.mjcUiLight] / [MjcNoticePalette.mjcUiDark].
  final Color sourceMjc;
  /// 역량관리 공지 UI 액센트.
  final Color sourceMpu;
  /// 교수학습 공지 UI 액센트.
  final Color sourceCtl;
  /// 읽은 공지 제목 색.
  final Color noticeReadTitle;
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
    Color? noticeReadTitle,
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
      noticeReadTitle: noticeReadTitle ?? this.noticeReadTitle,
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
      noticeReadTitle: Color.lerp(noticeReadTitle, other.noticeReadTitle, t)!,
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

@immutable
class MjcComponentTokens extends ThemeExtension<MjcComponentTokens> {
  const MjcComponentTokens({
    required this.bottomNavSelected,
    required this.bottomNavUnselected,
    required this.noticeSubNavShadow,
    required this.myPageBookmarkTabSelected,
    required this.myPageBookmarkTabUnselected,
  });

  /// Bottom navigation selected icon/label.
  final Color bottomNavSelected;

  /// Bottom navigation unselected icon/label.
  final Color bottomNavUnselected;

  /// Shadow color used by floating sub-navigation pills/cards.
  final Color noticeSubNavShadow;

  /// 마이페이지 고정·즐겨찾기 공지 `TabBar` — 선택 탭·인디케이터.
  final Color myPageBookmarkTabSelected;

  /// 마이페이지 고정·즐겨찾기 공지 `TabBar` — 미선택 라벨·아이콘.
  final Color myPageBookmarkTabUnselected;

  @override
  MjcComponentTokens copyWith({
    Color? bottomNavSelected,
    Color? bottomNavUnselected,
    Color? noticeSubNavShadow,
    Color? myPageBookmarkTabSelected,
    Color? myPageBookmarkTabUnselected,
  }) {
    return MjcComponentTokens(
      bottomNavSelected: bottomNavSelected ?? this.bottomNavSelected,
      bottomNavUnselected: bottomNavUnselected ?? this.bottomNavUnselected,
      noticeSubNavShadow: noticeSubNavShadow ?? this.noticeSubNavShadow,
      myPageBookmarkTabSelected:
          myPageBookmarkTabSelected ?? this.myPageBookmarkTabSelected,
      myPageBookmarkTabUnselected:
          myPageBookmarkTabUnselected ?? this.myPageBookmarkTabUnselected,
    );
  }

  @override
  MjcComponentTokens lerp(
    ThemeExtension<MjcComponentTokens>? other,
    double t,
  ) {
    if (other is! MjcComponentTokens) return this;
    return MjcComponentTokens(
      bottomNavSelected:
          Color.lerp(bottomNavSelected, other.bottomNavSelected, t)!,
      bottomNavUnselected:
          Color.lerp(bottomNavUnselected, other.bottomNavUnselected, t)!,
      noticeSubNavShadow:
          Color.lerp(noticeSubNavShadow, other.noticeSubNavShadow, t)!,
      myPageBookmarkTabSelected: Color.lerp(
        myPageBookmarkTabSelected,
        other.myPageBookmarkTabSelected,
        t,
      )!,
      myPageBookmarkTabUnselected: Color.lerp(
        myPageBookmarkTabUnselected,
        other.myPageBookmarkTabUnselected,
        t,
      )!,
    );
  }
}

const MjcSurfaceTokens _lightSurfaceTokens = MjcSurfaceTokens(
  cardBorder: _kCardBorderLight,
  hairline: _kCardBorderLight,
  surfaceContainer: _kSurfaceContainerLight,
  sourceMjc: _kSourceMjcLight,
  sourceMpu: _kSourceMpuLight,
  sourceCtl: _kSourceCtlLight,
  noticeReadTitle: _kNoticeReadTitleLight,
  foodAccent: _kFoodAccentLight,
  deadlineBadge: _kDeadlineBadgeLight,
  dashboardGradients: _kDashboardGradientsLight,
);

const MjcSurfaceTokens _darkSurfaceTokens = MjcSurfaceTokens(
  cardBorder: AppColors.cardBorderDark,
  hairline: AppColors.cardBorderDark,
  surfaceContainer: AppColors.surfaceContainerDark,
  sourceMjc: _kSourceMjcDark,
  sourceMpu: _kSourceMpuDark,
  sourceCtl: _kSourceCtlDark,
  noticeReadTitle: _kNoticeReadTitleDark,
  foodAccent: _kFoodAccentDark,
  deadlineBadge: _kDeadlineBadgeDark,
  dashboardGradients: _kDashboardGradientsDark,
);

const MjcComponentTokens _lightComponentTokens = MjcComponentTokens(
  bottomNavSelected: AppColors.primary,
  bottomNavUnselected: AppColors.mutedForeground,
  noticeSubNavShadow: _kSubNavShadowLight,
  myPageBookmarkTabSelected: AppColors.primary,
  myPageBookmarkTabUnselected: AppColors.mutedForeground,
);

const MjcComponentTokens _darkComponentTokens = MjcComponentTokens(
  // Dark ColorScheme.primary is too dim on bottom bar; match toggle ON color.
  bottomNavSelected: AppColors.switchActiveDark,
  bottomNavUnselected: _kBottomNavUnselectedDark,
  noticeSubNavShadow: _kSubNavShadowDark,
  myPageBookmarkTabSelected: kMjcMyPageBookmarkTabSelectedDark,
  myPageBookmarkTabUnselected: kMjcMyPageBookmarkTabUnselectedDark,
);

ThemeData buildMjcTheme() {
  const primary = AppColors.primary;

  final base = ThemeData.light(useMaterial3: true);
  final textTheme = base.textTheme.apply(fontFamily: kPretendardFontFamily);
  const textTokens = MjcTextTokens(
    appBarTitle: TextStyle(
      fontFamily: kPretendardFontFamily,
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    navLabel: TextStyle(
      fontFamily: kPretendardFontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: kPretendardFontFamily,
    scaffoldBackgroundColor: AppColors.scaffoldMuted,
    textTheme: textTheme,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      surface: Colors.white,
      surfaceContainerLow: _kSurfaceContainerLowLight,
      surfaceContainer: _kSurfaceContainerLight,
      surfaceContainerHigh: _kSurfaceContainerHighLight,
      onSurface: _kOnSurfaceLight,
      onSurfaceVariant: AppColors.mutedForeground,
      outline: _kCardBorderLight,
      error: _kErrorLight,
      onError: Colors.white,
    ),
    extensions: <ThemeExtension<dynamic>>[
      _lightSurfaceTokens,
      _lightComponentTokens,
      textTokens,
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTokens.appBarTitle,
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
          fontFamily: kPretendardFontFamily,
          fontSize: textTokens.navLabel.fontSize,
          fontWeight: textTokens.navLabel.fontWeight,
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
    tabBarTheme: const TabBarThemeData(
      labelColor: primary,
      unselectedLabelColor: AppColors.mutedForeground,
      indicatorColor: primary,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: _kCardBorderLight,
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
        return _kSwitchTrackOffLight;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return null;
        if (states.contains(WidgetState.selected)) {
          return Colors.transparent;
        }
        return _kSwitchOutlineOffLight;
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
  final textTheme = base.textTheme.apply(fontFamily: kPretendardFontFamily);
  const textTokens = MjcTextTokens(
    appBarTitle: TextStyle(
      fontFamily: kPretendardFontFamily,
      color: Color(0xFFE0E0E0),
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    navLabel: TextStyle(
      fontFamily: kPretendardFontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: kPretendardFontFamily,
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
      surfaceContainerHigh: _kSurfaceContainerHighDark,
      onSurface: _kOnSurfaceDark,
      onSurfaceVariant: AppColors.mutedForegroundDark,
      outline: AppColors.cardBorderDark,
      error: _kErrorDark,
      onError: Colors.white,
    ),
    extensions: <ThemeExtension<dynamic>>[
      _darkSurfaceTokens,
      _darkComponentTokens,
      textTokens,
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.cardDark,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTokens.appBarTitle,
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
          fontFamily: kPretendardFontFamily,
          fontSize: textTokens.navLabel.fontSize,
          fontWeight: textTokens.navLabel.fontWeight,
          color: selected
              ? AppColors.switchActiveDark
              : _kBottomNavUnselectedDark,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected
              ? AppColors.switchActiveDark
              : _kBottomNavUnselectedDark,
        );
      }),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.switchActiveDark,
      unselectedLabelColor: _kBottomNavUnselectedDark,
      indicatorColor: AppColors.switchActiveDark,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: AppColors.cardBorderDark,
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
        return _kSwitchTrackOffDark;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return null;
        if (states.contains(WidgetState.selected)) {
          return Colors.transparent;
        }
        return _kSwitchOutlineOffDark;
      }),
    ),
    cardTheme: CardThemeData(
      color: _kCardDarkAlt,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.white.withValues(alpha: 0.05),
      thickness: 1,
      space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  );
}
