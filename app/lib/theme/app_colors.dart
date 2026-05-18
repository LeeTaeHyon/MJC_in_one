import "package:flutter/material.dart";

/// figma_design (MUI) 화면과 동일한 브랜드 색상.
abstract final class AppColors {
  /// 인트로(앱 시작) 스플래시 배경.
  static const Color introBackground = Color(0xFFFFFFFF);

  static const Color primary = Color(0xFF0047BB);
  static const Color secondary = Color(0xFF1976D2);
  static const Color teaching = Color(0xFF1976D2);
  static const Color competency = Color(0xFF2196F3);
  static const Color library = Color(0xFF42A5F5);

  /// 바로가기 카드 텍스트 (라이트 모드).
  static const Color quickCardText = Color(0xFF343A40);

  static const Color scaffoldMuted = Color(0xFFF5F5F5);
  static const Color scaffoldMutedDark = Color(0xFF0A0A0A);
  static const Color cardDark = Color(0xFF16181C);
  static const Color surfaceContainerDark = Color(0xFF20242B);
  static const Color cardBorderDark = Color(0xFF2A2A2D);
  static const Color chipBackground = Color(0xFFE3F2FD);

  /// 상단 분류·태그 필터 칩 (메인 공지, 알림 내역).
  static const Color noticeFilterChipSelectedBgLight = Color(0xFF374151);
  static const Color noticeFilterChipSelectedBgDark = Color(0xFFE5E7EB);
  /// 스캐폴드·surface 대비가 보이도록 gray-200 톤 (기존 #F2F2F2는 배경과 거의 동일).
  static const Color noticeFilterChipUnselectedBgLight = Color(0xFFE5E7EB);
  static const Color noticeFilterChipUnselectedBgDark = Color(0xFF303035);
  static const Color noticeFilterChipUnselectedFgLight = Color(0xFF374151);
  static const Color noticeFilterChipSelectedFgLight = Color(0xFFF3F4F6);
  static const Color noticeFilterChipUnselectedFgDark = Color(0xFFD1D5DB);
  static const Color noticeFilterChipSelectedFgDark = Color(0xFF374151);

  static Color noticeFilterChipBackground({
    required bool isDark,
    required bool selected,
  }) {
    if (selected) {
      return isDark
          ? noticeFilterChipSelectedBgDark
          : noticeFilterChipSelectedBgLight;
    }
    return isDark
        ? noticeFilterChipUnselectedBgDark
        : noticeFilterChipUnselectedBgLight;
  }

  static Color noticeFilterChipForeground({
    required bool isDark,
    required bool selected,
  }) {
    if (selected) {
      return isDark
          ? noticeFilterChipSelectedFgDark
          : noticeFilterChipSelectedFgLight;
    }
    return isDark
        ? noticeFilterChipUnselectedFgDark
        : noticeFilterChipUnselectedFgLight;
  }
  static const Color toggleSelected = Color(0xFFE3F2FD);
  static const Color mutedForeground = Color(0xFF717182);
  static const Color mutedForegroundDark = Color(0xFF9CA3AF);

  /// 다크 모드 스위치 ON — 칩·세그먼트 선택 등 밝은 파란 톤과 맞춤 (`primary`는 너무 어두움).
  static const Color switchActiveDark = Color(0xFF5B8CFF);

  static Color iconBackdrop(Color base) => base.withValues(alpha: 0.082);

  /// Colored timetable blocks (subject); text uses [timetableSlotOnColor].
  static const List<Color> timetableCoursePalette = <Color>[
    Color(0xFFE65100),
    Color(0xFF00897B),
    Color(0xFF3949AB),
    Color(0xFF7B1FA2),
    Color(0xFFC62828),
    Color(0xFF2E7D32),
    Color(0xFFAD1457),
    Color(0xFF00695C),
    Color(0xFF283593),
    Color(0xFFF9A825),
    Color(0xFF5D4037),
    Color(0xFF0277BD),
  ];

  static const Color timetableSlotOnColor = Color(0xFFFFFFFF);
}
