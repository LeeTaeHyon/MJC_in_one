import "package:flutter/material.dart";

/// figma_design (MUI) 화면과 동일한 브랜드 색상.
abstract final class AppColors {
  /// 인트로(앱 시작) 화면 배경.
  static const Color introBackground = Color(0xFF005EB8);

  static const Color primary = Color(0xFF0047BB);
  static const Color secondary = Color(0xFF1976D2);
  static const Color teaching = Color(0xFF1976D2);
  static const Color competency = Color(0xFF2196F3);
  static const Color library = Color(0xFF42A5F5);

  /// 바로가기 카드 텍스트 (라이트 모드).
  static const Color quickCardText = Color(0xFF343A40);

  static const Color scaffoldMuted = Color(0xFFF5F5F5);
  static const Color scaffoldMutedDark = Color(0xFF0F0F10);
  static const Color cardDark = Color(0xFF1C1C1E);
  static const Color surfaceContainerDark = Color(0xFF26262A);
  static const Color cardBorderDark = Color(0xFF2A2A2D);
  static const Color chipBackground = Color(0xFFE3F2FD);
  static const Color toggleSelected = Color(0xFFE3F2FD);
  static const Color mutedForeground = Color(0xFF717182);
  static const Color mutedForegroundDark = Color(0xFFB5B6BC);

  /// 다크 모드 스위치 ON — 칩·세그먼트 선택 등 밝은 파란 톤과 맞춤 (`primary`는 너무 어두움).
  static const Color switchActiveDark = Color(0xFF82B1FF);

  static Color iconBackdrop(Color base) => base.withValues(alpha: 0.082);
}
