import "package:flutter_test/flutter_test.dart";
import "package:mjc_in_one/features/timetable/services/timetable_slot_parser.dart";

void main() {
  test("parseTimetableCell parses multiline MJC-style cell", () {
    const String raw = "수 10:00 - 10:50 ( 공701 )\n수 11:00 - 11:50 ( 공701 )";
    final slots = TimetableSlotParser.parseTimetableCell(
      raw: raw,
      courseName: "IE정보능력",
      offeringId: "abc",
      colorKey: "IE정보능력|101",
    );
    expect(slots.length, 2);
    expect(slots.first.weekday, 3);
    expect(slots.first.startMinute, 10 * 60);
    expect(slots.first.endMinute, 10 * 60 + 50);
    expect(slots.first.room, "공701");
    expect(slots.first.courseName, "IE정보능력");
  });

  test("parseTimetableCell parses single-line cells with spaces between slots", () {
    const String raw =
        "수 10:00 - 10:50 ( 공701 )  수 11:00 - 11:50 ( 공701 )";
    final slots = TimetableSlotParser.parseTimetableCell(
      raw: raw,
      courseName: "IE정보능력",
      offeringId: "abc",
      colorKey: "IE정보능력|101",
    );
    expect(slots.length, 2);
    expect(slots[1].startMinute, 11 * 60);
  });
}
