enum AcademicScheduleKind {
  exam,
  registration,
  grades,
  scholarship,
  worship,
  general;

  static AcademicScheduleKind? tryParse(String? raw) {
    final String v = (raw ?? "").trim().toLowerCase();
    return switch (v) {
      "exam" => AcademicScheduleKind.exam,
      "registration" => AcademicScheduleKind.registration,
      "grades" => AcademicScheduleKind.grades,
      "scholarship" => AcademicScheduleKind.scholarship,
      "worship" => AcademicScheduleKind.worship,
      "general" => AcademicScheduleKind.general,
      _ => null,
    };
  }
}

