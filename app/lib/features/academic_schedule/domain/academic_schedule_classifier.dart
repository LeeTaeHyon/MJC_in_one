import "package:mjc_in_one/features/academic_schedule/domain/academic_schedule_kind.dart";

class AcademicScheduleClassifier {
  static final List<RegExp> _exam = [
    RegExp(r"(시험|중간고사|기말고사|고사|재시험|추가시험|보강시험|평가)"),
  ];

  static final List<RegExp> _registration = [
    RegExp(
      r"(수강신청|수강\s*정정|수강정정|수강\s*철회|수강철회|수강\s*변경|수강변경|"
      r"수강꾸러미|장바구니|예비\s*수강신청|재수강|분반\s*변경|폐강|증원)",
    ),
  ];

  static final List<RegExp> _grades = [
    RegExp(r"(성적|강의평가|평가\s*입력|성적\s*입력|성적열람|성적\s*열람|성적정정|정정\s*기간)"),
  ];

  static final List<RegExp> _scholarship = [
    RegExp(
      r"(장학|장학금|국가장학|근로장학|학자금|대출|등록금|등록|분납|납부|고지서|추가\s*등록)",
    ),
  ];

  static AcademicScheduleKind kindOf(Map<String, dynamic> item) {
    final String title = (item["title"] ?? "").toString();
    return kindOfTitle(title);
  }

  static AcademicScheduleKind kindOfTitle(String title) {
    final String t = title.trim();
    if (t.isEmpty) return AcademicScheduleKind.general;

    bool anyMatch(List<RegExp> pats) => pats.any((p) => p.hasMatch(t));

    if (anyMatch(_exam)) return AcademicScheduleKind.exam;
    if (anyMatch(_registration)) return AcademicScheduleKind.registration;
    if (anyMatch(_grades)) return AcademicScheduleKind.grades;
    if (anyMatch(_scholarship)) return AcademicScheduleKind.scholarship;
    return AcademicScheduleKind.general;
  }
}

