enum AcademicScheduleKind {
  exam,
  registration,
  grades,
  scholarship,
  general;

  static AcademicScheduleKind? tryParse(String? raw) {
    final String v = (raw ?? "").trim().toLowerCase();
    return switch (v) {
      "exam" => AcademicScheduleKind.exam,
      "registration" => AcademicScheduleKind.registration,
      "grades" => AcademicScheduleKind.grades,
      "scholarship" => AcademicScheduleKind.scholarship,
      "general" => AcademicScheduleKind.general,
      _ => null,
    };
  }
}

