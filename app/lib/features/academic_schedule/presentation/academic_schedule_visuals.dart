import "package:flutter/material.dart";
import "package:mjc_in_one/features/academic_schedule/domain/academic_schedule_kind.dart";
import "package:mjc_in_one/theme/app_colors.dart";

class AcademicScheduleVisuals {
  const AcademicScheduleVisuals({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.dotColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color dotColor;

  static AcademicScheduleVisuals of(
    BuildContext context,
    AcademicScheduleKind kind,
  ) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color grey = scheme.onSurfaceVariant;

    switch (kind) {
      case AcademicScheduleKind.exam:
        return AcademicScheduleVisuals(
          icon: Icons.quiz_rounded,
          iconColor: Colors.redAccent,
          backgroundColor: Colors.redAccent.withValues(alpha: 0.12),
          dotColor: Colors.redAccent,
        );
      case AcademicScheduleKind.registration:
        return AcademicScheduleVisuals(
          icon: Icons.edit_calendar_rounded,
          iconColor: Colors.blueAccent,
          backgroundColor: Colors.blueAccent.withValues(alpha: 0.12),
          dotColor: Colors.blueAccent,
        );
      case AcademicScheduleKind.grades:
        return AcademicScheduleVisuals(
          icon: Icons.grading_rounded,
          iconColor: Colors.deepPurpleAccent,
          backgroundColor: Colors.deepPurpleAccent.withValues(alpha: 0.12),
          dotColor: Colors.deepPurpleAccent,
        );
      case AcademicScheduleKind.scholarship:
        return AcademicScheduleVisuals(
          icon: Icons.volunteer_activism_rounded,
          iconColor: Colors.green,
          backgroundColor: Colors.green.withValues(alpha: 0.12),
          dotColor: Colors.green,
        );
      case AcademicScheduleKind.general:
        return AcademicScheduleVisuals(
          icon: Icons.event_note_rounded,
          iconColor: grey,
          backgroundColor: grey.withValues(alpha: 0.10),
          dotColor: grey.withValues(alpha: 0.85),
        );
    }
  }

  static bool isImportant(AcademicScheduleKind kind) =>
      kind != AcademicScheduleKind.general;

  static int priority(AcademicScheduleKind kind) {
    // 낮을수록 우선
    return switch (kind) {
      AcademicScheduleKind.exam => 0,
      AcademicScheduleKind.registration => 1,
      AcademicScheduleKind.grades => 2,
      AcademicScheduleKind.scholarship => 3,
      AcademicScheduleKind.general => 99,
    };
  }

  static Color calendarDayBackground({
    required BuildContext context,
    required bool hasEvent,
    required bool hasImportant,
  }) {
    if (!hasEvent) return Colors.transparent;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    if (hasImportant) {
      return AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10);
    }
    return scheme.onSurfaceVariant.withValues(alpha: isDark ? 0.14 : 0.10);
  }
}

