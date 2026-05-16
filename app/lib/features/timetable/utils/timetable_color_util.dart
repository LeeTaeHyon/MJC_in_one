import "package:flutter/material.dart";
import "package:mjc_in_one/theme/app_colors.dart";

abstract final class TimetableColorUtil {
  static Color colorForCourseKey(String colorKey) {
    if (AppColors.timetableCoursePalette.isEmpty) return AppColors.primary;
    final int i =
        colorKey.hashCode.abs() % AppColors.timetableCoursePalette.length;
    return AppColors.timetableCoursePalette[i];
  }
}
