import "dart:convert";

import "package:mjc_in_one/features/timetable/utils/timetable_slot_merge.dart";

/// One meeting period on the weekly grid (Mon–Fri typical).
class TimetableSlot {
  const TimetableSlot({
    required this.weekday,
    required this.startMinute,
    required this.endMinute,
    required this.room,
    required this.courseName,
    required this.offeringId,
    required this.colorKey,
  });

  /// [DateTime.weekday] convention: Mon = 1 … Sun = 7.
  final int weekday;
  final int startMinute;
  final int endMinute;
  final String room;
  final String courseName;
  final String offeringId;
  /// Same as parent offering’s [ParsedCourseOffering.colorKey] for palette mapping.
  final String colorKey;

  Map<String, dynamic> toJson() => <String, dynamic>{
        "weekday": weekday,
        "startMinute": startMinute,
        "endMinute": endMinute,
        "room": room,
        "courseName": courseName,
        "offeringId": offeringId,
        "colorKey": colorKey,
      };

  static TimetableSlot fromJson(Map<String, dynamic> json) {
    final String cn = (json["courseName"] ?? "").toString();
    return TimetableSlot(
      weekday: (json["weekday"] as num?)?.toInt() ?? 1,
      startMinute: (json["startMinute"] as num?)?.toInt() ?? 0,
      endMinute: (json["endMinute"] as num?)?.toInt() ?? 0,
      room: (json["room"] ?? "").toString(),
      courseName: cn,
      offeringId: (json["offeringId"] ?? "").toString(),
      colorKey: (json["colorKey"] ?? cn).toString(),
    );
  }
}

/// One row from the official Excel (one section / 분반).
class ParsedCourseOffering {
  ParsedCourseOffering({
    required this.offeringId,
    required this.courseCategory,
    required this.department,
    required this.courseName,
    required this.section,
    required this.professor,
    required this.gradeYear,
    required this.completionType,
    required this.credits,
    required this.slots,
    required this.rawTimetableText,
  });

  final String offeringId;
  final String courseCategory;
  final String department;
  final String courseName;
  final String section;
  final String professor;
  final String gradeYear;
  final String completionType;
  final String credits;
  final List<TimetableSlot> slots;
  final String rawTimetableText;

  /// Official timetable cell text for «원격시험 배정시간» — remote class with
  /// only a face-to-face exam block on the sheet; show name below grid, not in cells.
  static const String remoteExamScheduleMarker = "원격시험 배정시간";

  bool get isRemoteExamFaceToFaceOnly =>
      rawTimetableText.contains(remoteExamScheduleMarker);

  /// Stable key for color (same course + section shares color).
  String get colorKey => "$courseName|$section";

  String get scheduleSummary {
    final List<TimetableSlot> merged = TimetableSlotMerge.mergeAdjacent(slots);
    return merged
        .map(
          (TimetableSlot s) {
            final String roomLabel = isRemoteExamFaceToFaceOnly
                ? (s.room.isEmpty
                    ? "대면시험 강의실"
                    : "대면시험 강의실 ${s.room}")
                : s.room;
            return "${_weekdayLabel(s.weekday)} ${_fmtHm(s.startMinute)}-${_fmtHm(s.endMinute)} ($roomLabel)";
          },
        )
        .join(" ");
  }

  static String _weekdayLabel(int wd) {
    return switch (wd) {
      1 => "월",
      2 => "화",
      3 => "수",
      4 => "목",
      5 => "금",
      6 => "토",
      _ => "일",
    };
  }

  static String _fmtHm(int minutes) {
    final int h = minutes ~/ 60;
    final int m = minutes % 60;
    return "${h.toString().padLeft(2, "0")}:${m.toString().padLeft(2, "0")}";
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        "offeringId": offeringId,
        "courseCategory": courseCategory,
        "department": department,
        "courseName": courseName,
        "section": section,
        "professor": professor,
        "gradeYear": gradeYear,
        "completionType": completionType,
        "credits": credits,
        "rawTimetableText": rawTimetableText,
        "slots": slots.map((e) => e.toJson()).toList(),
      };

  static ParsedCourseOffering fromJson(Map<String, dynamic> json) {
    final List<dynamic>? rawSlots = json["slots"] as List<dynamic>?;
    return ParsedCourseOffering(
      offeringId: (json["offeringId"] ?? "").toString(),
      courseCategory: (json["courseCategory"] ?? "").toString(),
      department: (json["department"] ?? "").toString(),
      courseName: (json["courseName"] ?? "").toString(),
      section: (json["section"] ?? "").toString(),
      professor: (json["professor"] ?? "").toString(),
      gradeYear: (json["gradeYear"] ?? "").toString(),
      completionType: (json["completionType"] ?? "").toString(),
      credits: (json["credits"] ?? "").toString(),
      rawTimetableText: (json["rawTimetableText"] ?? "").toString(),
      slots: rawSlots == null
          ? const <TimetableSlot>[]
          : rawSlots
              .map((e) => TimetableSlot.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList(),
    );
  }

  static String encodeOfferingsList(List<ParsedCourseOffering> list) {
    return jsonEncode(list.map((e) => e.toJson()).toList());
  }

  static List<ParsedCourseOffering> decodeOfferingsList(String raw) {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) return const <ParsedCourseOffering>[];
    return decoded
        .map((e) => ParsedCourseOffering.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
