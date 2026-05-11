import "package:mio_notice/features/timetable/models/timetable_models.dart";

/// Parses lines like: `수 10:00 - 10:50 ( 공701 )`
abstract final class TimetableSlotParser {
  static final RegExp _linePattern = RegExp(
    r"^\s*(월|화|수|목|금|토)\s*(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})\s*\(\s*([^)]*)\s*\)\s*$",
  );

  static int weekdayFromChar(String c) {
    return switch (c) {
      "월" => 1,
      "화" => 2,
      "수" => 3,
      "목" => 4,
      "금" => 5,
      "토" => 6,
      _ => 1,
    };
  }

  static int? _parseHm(String s) {
    final RegExpMatch? m = RegExp(r"^(\d{1,2}):(\d{2})$").firstMatch(s.trim());
    if (m == null) return null;
    final int h = int.parse(m.group(1)!);
    final int min = int.parse(m.group(2)!);
    if (h < 0 || h > 23 || min < 0 || min > 59) return null;
    return h * 60 + min;
  }

  /// Splits [raw] on newlines and returns parsed slots (invalid lines skipped).
  static List<TimetableSlot> parseTimetableCell({
    required String raw,
    required String courseName,
    required String offeringId,
    required String colorKey,
  }) {
    final List<TimetableSlot> out = <TimetableSlot>[];
    for (final String line in raw.split(RegExp(r"\r\n|\n|\r"))) {
      final String t = line.trim();
      if (t.isEmpty) continue;
      final RegExpMatch? m = _linePattern.firstMatch(t);
      if (m == null) continue;
      final int wd = weekdayFromChar(m.group(1)!);
      final int? start = _parseHm(m.group(2)!);
      final int? end = _parseHm(m.group(3)!);
      if (start == null || end == null) continue;
      if (end <= start) continue;
      final String room = m.group(4)!.trim();
      out.add(
        TimetableSlot(
          weekday: wd,
          startMinute: start,
          endMinute: end,
          room: room,
          courseName: courseName,
          offeringId: offeringId,
          colorKey: colorKey,
        ),
      );
    }
    return out;
  }

  static String stableOfferingId({
    required String department,
    required String courseName,
    required String section,
    required String professor,
  }) {
    return Object.hash(
      department.trim(),
      courseName.trim(),
      section.trim(),
      professor.trim(),
    ).toRadixString(16);
  }
}
