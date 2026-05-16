import "dart:async";

import "package:flutter/material.dart";
import "package:mjc_in_one/features/timetable/models/timetable_models.dart";
import "package:mjc_in_one/features/timetable/screens/timetable_main_screen.dart";
import "package:mjc_in_one/features/timetable/services/timetable_storage_service.dart";
import "package:mjc_in_one/features/timetable/utils/timetable_next_lecture.dart";
import "package:mjc_in_one/theme/app_colors.dart";
import "package:mjc_in_one/theme/app_theme.dart";

/// 홈 대시보드용 다음 수업 안내. 분 단위 카운트다운이 지나가도록 1분마다 갱신합니다.
class HomeLectureReminderCard extends StatefulWidget {
  const HomeLectureReminderCard({super.key});

  @override
  State<HomeLectureReminderCard> createState() => _HomeLectureReminderCardState();
}

class _HomeLectureReminderCardState extends State<HomeLectureReminderCard> {
  late Future<List<ParsedCourseOffering>> _enrolledFuture;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _enrolledFuture = TimetableStorageService.loadEnrolled();
    _tickTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    return FutureBuilder<List<ParsedCourseOffering>>(
      future: _enrolledFuture,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<ParsedCourseOffering>> snapshot,
      ) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final List<ParsedCourseOffering> enrolled =
            snapshot.data ?? const <ParsedCourseOffering>[];
        final TimetableSlot? slot =
            TimetableNextLecture.nextUpcomingSlotToday(enrolled);
        if (slot == null) return const SizedBox.shrink();
        final DateTime now = DateTime.now();
        final int nowMin = now.hour * 60 + now.minute;
        final int untilMin = slot.startMinute - nowMin;
        final String label = TimetableNextLecture.formatCountdownKo(untilMin);
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Material(
            color: scheme.surface,
            elevation: 1,
            shadowColor: scheme.shadow.withValues(alpha: isDark ? 0.45 : 0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: (isDark ? tokens.cardBorder : scheme.outline)
                    .withValues(alpha: isDark ? 0.85 : 0.55),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const TimetableMainScreen(),
                  ),
                );
                if (!mounted) return;
                setState(() {
                  _enrolledFuture = TimetableStorageService.loadEnrolled();
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.schedule_rounded, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "$label 뒤 ${slot.courseName} 수업이 있습니다.",
                        style: TextStyle(
                          fontFamily: kPretendardFontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                          height: 1.25,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
