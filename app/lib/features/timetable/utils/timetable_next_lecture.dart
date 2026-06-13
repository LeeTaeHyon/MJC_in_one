import "package:mjc_in_one/features/timetable/models/timetable_models.dart";
import "package:mjc_in_one/features/timetable/utils/timetable_slot_merge.dart";

/// Today’s next class block that has not started yet (merged adjacent periods).
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

    // 홈 알림은 «아직 시작 전» 수업만 표시합니다. 진행 중·종료된 슬롯은 제외해
    // 시작 시각이 지난 뒤에도 «곧 시작»이 남는 문제를 막습니다.
    TimetableSlot? bestUpcoming;
    int bestUpcomingStart = 1 << 30;
    for (final TimetableSlot s in merged) {
      if (s.startMinute <= nowMin) continue;
      if (s.startMinute < bestUpcomingStart) {
        bestUpcomingStart = s.startMinute;
        bestUpcoming = s;
      }
    }
    return bestUpcoming;
  }

  static List<TimetableSlot> upcomingSlotsToday(
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
    if (todayRaw.isEmpty) return const [];

    final List<TimetableSlot> merged =
        TimetableSlotMerge.mergeAdjacent(todayRaw);
        
    final List<TimetableSlot> upcoming = [];
    for (final TimetableSlot s in merged) {
      if (s.startMinute > nowMin) {
        upcoming.add(s);
      }
    }
    return upcoming;
  }

  static List<TimetableSlot> allSlotsForWeekday(
    List<ParsedCourseOffering> enrolled,
    int weekday,
  ) {
    final List<TimetableSlot> raw = <TimetableSlot>[];
    for (final ParsedCourseOffering o in enrolled) {
      if (o.isRemoteExamFaceToFaceOnly) continue;
      for (final TimetableSlot s in o.slots) {
        if (s.weekday == weekday) raw.add(s);
      }
    }
    if (raw.isEmpty) return const [];

    final List<TimetableSlot> merged = TimetableSlotMerge.mergeAdjacent(raw);
    merged.sort((a, b) => a.startMinute.compareTo(b.startMinute));
    return merged;
  }

  static TimetableSlot? firstSlotToday(List<ParsedCourseOffering> enrolled) {
    final DateTime now = DateTime.now();
    final int wd = now.weekday;

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
        
    TimetableSlot? firstSlot;
    int firstStart = 1 << 30;
    for (final TimetableSlot s in merged) {
      if (s.startMinute < firstStart) {
        firstStart = s.startMinute;
        firstSlot = s;
      }
    }
    return firstSlot;
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
