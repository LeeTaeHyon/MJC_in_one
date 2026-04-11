import "package:flutter/material.dart";

/// figma_design (MUI) 화면과 동일한 브랜드 색상.
abstract final class AppColors {
  static const Color primary = Color(0xFF0047BB);
  static const Color secondary = Color(0xFF1976D2);
  static const Color teaching = Color(0xFF1976D2);
  static const Color competency = Color(0xFF2196F3);
  static const Color library = Color(0xFF42A5F5);

  static const Color scaffoldMuted = Color(0xFFF5F5F5);
  static const Color chipBackground = Color(0xFFE3F2FD);
  static const Color toggleSelected = Color(0xFFE3F2FD);
  static const Color mutedForeground = Color(0xFF717182);

  static Color iconBackdrop(Color base) => base.withValues(alpha: 0.082);
}
