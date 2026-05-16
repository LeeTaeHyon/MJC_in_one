import "package:mjc_in_one/features/timetable/models/timetable_models.dart";

/// Merges consecutive timetable cells for the same [TimetableSlot.offeringId]
/// on the same weekday so the grid shows one block (e.g. 12:00–12:50 +
/// 13:00–13:50 + 14:00–14:50 → 12:00–14:50).
///
/// [maxGapMinutes]: treat the next slot as the same session if it starts at
/// most this many minutes after the previous slot ends (typical 50분 교시 +
/// 쉬는시간).
abstract final class TimetableSlotMerge {
  static const int defaultMaxGapMinutes = 20;

  static List<TimetableSlot> mergeAdjacent(
    Iterable<TimetableSlot> slots, {
    int maxGapMinutes = defaultMaxGapMinutes,
  }) {
    final List<TimetableSlot> list = slots.toList();
    if (list.isEmpty) return list;

    final Map<String, List<TimetableSlot>> groups = <String, List<TimetableSlot>>{};
    for (final TimetableSlot s in list) {
      final String key = "${s.offeringId}|${s.weekday}";
      groups.putIfAbsent(key, () => <TimetableSlot>[]).add(s);
    }

    final List<TimetableSlot> merged = <TimetableSlot>[];
    for (final List<TimetableSlot> g in groups.values) {
      g.sort((TimetableSlot a, TimetableSlot b) {
        final int c = a.startMinute.compareTo(b.startMinute);
        return c != 0 ? c : a.endMinute.compareTo(b.endMinute);
      });
      TimetableSlot cur = g.first;
      for (int i = 1; i < g.length; i++) {
        final TimetableSlot n = g[i];
        final int gap = n.startMinute - cur.endMinute;
        if (gap <= maxGapMinutes) {
          final int newEnd =
              n.endMinute > cur.endMinute ? n.endMinute : cur.endMinute;
          cur = TimetableSlot(
            weekday: cur.weekday,
            startMinute: cur.startMinute,
            endMinute: newEnd,
            room: cur.room.isNotEmpty ? cur.room : n.room,
            courseName: cur.courseName,
            offeringId: cur.offeringId,
            colorKey: cur.colorKey,
          );
        } else {
          merged.add(cur);
          cur = n;
        }
      }
      merged.add(cur);
    }

    merged.sort((TimetableSlot a, TimetableSlot b) {
      final int wd = a.weekday.compareTo(b.weekday);
      return wd != 0 ? wd : a.startMinute.compareTo(b.startMinute);
    });
    return merged;
  }
}
