import "package:mjc_in_one/features/timetable/models/timetable_models.dart";

/// Today’s next class that has not yet started (local weekday).
abstract final class TimetableNextLecture {
  static TimetableSlot? nextUpcomingSlotToday(
    List<ParsedCourseOffering> enrolled,
  ) {
    final DateTime now = DateTime.now();
    final int wd = now.weekday;
    final int nowMin = now.hour * 60 + now.minute;
    TimetableSlot? best;
    int bestStart = 1 << 30;
    for (final ParsedCourseOffering o in enrolled) {
      if (o.isRemoteExamFaceToFaceOnly) continue;
      for (final TimetableSlot s in o.slots) {
        if (s.weekday != wd) continue;
        if (s.startMinute <= nowMin) continue;
        if (s.startMinute < bestStart) {
          bestStart = s.startMinute;
          best = s;
        }
      }
    }
    return best;
  }

  static String formatCountdownKo(int totalMinutes) {
    if (totalMinutes <= 0) return "곧";
    final int h = totalMinutes ~/ 60;
    final int m = totalMinutes % 60;
    if (h > 0 && m > 0) return "$h시간 $m분";
    if (h > 0) return "$h시간";
    return "$m분";
  }
}
