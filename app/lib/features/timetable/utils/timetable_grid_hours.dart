import "package:mjc_in_one/features/timetable/models/timetable_models.dart";

/// Default visible range on the weekly grid (Mon–Fri).
const int kTimetableGridStartHour = 9;
const int kTimetableGridDefaultEndHour = 18;
const int kTimetableGridExtendedEndHour = 22;

const int _defaultEndMinute = kTimetableGridDefaultEndHour * 60;

/// Returns [kTimetableGridExtendedEndHour] when any weekday slot ends after 18:00.
int timetableGridEndHourForSlots(Iterable<TimetableSlot> slots) {
  for (final TimetableSlot s in slots) {
    if (s.weekday < 1 || s.weekday > 5) continue;
    if (s.endMinute > _defaultEndMinute) {
      return kTimetableGridExtendedEndHour;
    }
  }
  return kTimetableGridDefaultEndHour;
}
