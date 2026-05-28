import "package:mjc_in_one/debug/app_debug_flags.dart";
import "package:mjc_in_one/features/timetable/models/timetable_models.dart";
import "package:mjc_in_one/features/timetable/services/timetable_storage_service.dart";
import "package:mjc_in_one/features/timetable/utils/timetable_next_lecture.dart";

/// 알림 패널·포그라운드 서비스에 표시할 강의 알림 문구.
typedef LectureReminderPresentation = ({
  String title,
  String body,
  String text,
  int classStartEpochMs,
});

DateTime lectureClassStartDateTime(TimetableSlot slot) {
  final DateTime now = DateTime.now();
  return DateTime(
    now.year,
    now.month,
    now.day,
    slot.startMinute ~/ 60,
    slot.startMinute % 60,
  );
}

/// 다음 수업 슬롯 (디자인 프리뷰 포함).
Future<TimetableSlot?> resolveNextLectureSlot() async {
  if (AppDevFeatures.lectureReminderDesignPreview) {
    return _designPreviewSlot();
  }
  final List<ParsedCourseOffering> enrolled =
      await TimetableStorageService.loadEnrolled();
  return TimetableNextLecture.nextUpcomingSlotToday(enrolled);
}

TimetableSlot _designPreviewSlot() {
  final DateTime now = DateTime.now();
  return TimetableSlot(
    weekday: now.weekday,
    startMinute: 12 * 60,
    endMinute: 12 * 60 + 50,
    room: "A101",
    courseName: "모바일 프로그래밍",
    offeringId: "__design_preview__",
    colorKey: "0",
  );
}

Future<LectureReminderPresentation?> buildLectureReminderPresentation() async {
  final TimetableSlot? slot = await resolveNextLectureSlot();
  if (slot == null) return null;

  final DateTime now = DateTime.now();
  final int nowMin = now.hour * 60 + now.minute;
  final int untilMin = slot.startMinute - nowMin;

  final String title =
      "${slot.courseName} ${TimetableNextLecture.formatStartTimeHm(slot.startMinute)}";
  final String body = TimetableNextLecture.formatRemainingKo(untilMin);
  final String room = slot.room.trim();
  final String text = room.isEmpty ? body : "$body · $room";
  final DateTime classStart = lectureClassStartDateTime(slot);

  return (
    title: title,
    body: body,
    text: text,
    classStartEpochMs: classStart.millisecondsSinceEpoch,
  );
}
