import "package:mjc_in_one/features/timetable/models/timetable_models.dart";
import "package:mjc_in_one/features/timetable/utils/timetable_slot_merge.dart";

/// Today’s current or next class block (merged adjacent periods, local weekday).
abstract final class TimetableNextLecture {
  static TimetableSlot? nextUpcomingSlotToday(
    List<ParsedCourseOffering> enrolled,
  ) {
    final DateTime now = DateTime.now();
    final int wd = now.weekday;
    final int nowMin = now.hour * 60 + now.minute;

    final List<TimetableSlot> todayRaw = <TimetableSlot>[];
    for (final ParsedCourseOffering o in enrolled) {
      if (o.isRemoteExamFaceToFaceOnly) continue;
      for (final TimetableSlot s in o.slots) {
        if (s.weekday == wd) todayRaw.add(s);
      }
    }
    if (todayRaw.isEmpty) return null;

    final List<TimetableSlot> merged =
        TimetableSlotMerge.mergeAdjacent(todayRaw);

    TimetableSlot? bestOngoing;
    int bestOngoingStart = 1 << 30;
    TimetableSlot? bestUpcoming;
    int bestUpcomingStart = 1 << 30;
    for (final TimetableSlot s in merged) {
      if (s.endMinute <= nowMin) continue;
      if (s.startMinute <= nowMin) {
        if (s.startMinute < bestOngoingStart) {
          bestOngoingStart = s.startMinute;
          bestOngoing = s;
        }
      } else if (s.startMinute < bestUpcomingStart) {
        bestUpcomingStart = s.startMinute;
        bestUpcoming = s;
      }
    }
    return bestOngoing ?? bestUpcoming;
  }

  static String formatCountdownKo(int totalMinutes) {
    if (totalMinutes <= 0) return "곧";
    final int h = totalMinutes ~/ 60;
    final int m = totalMinutes % 60;
    if (h > 0 && m > 0) return "$h시간 $m분";
    if (h > 0) return "$h시간";
    return "$m분";
  }

  static String formatStartTimeHm(int startMinute) {
    final int h = startMinute ~/ 60;
    final int m = startMinute % 60;
    return "${h.toString().padLeft(2, "0")}:${m.toString().padLeft(2, "0")}";
  }

  /// 예: `1시간 30분 남음`, `35분 남음`, `곧 시작`
  static String formatRemainingKo(int totalMinutes) {
    if (totalMinutes <= 0) return "곧 시작";
    final int h = totalMinutes ~/ 60;
    final int m = totalMinutes % 60;
    if (h > 0 && m > 0) return "$h시간 $m분 남음";
    if (h > 0) return "$h시간 남음";
    return "$m분 남음";
  }
}
