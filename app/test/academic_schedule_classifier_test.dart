import "package:flutter_test/flutter_test.dart";
import "package:mjc_in_one/features/academic_schedule/domain/academic_schedule_classifier.dart";
import "package:mjc_in_one/features/academic_schedule/domain/academic_schedule_kind.dart";

void main() {
  test("AcademicScheduleClassifier classifies exam", () {
    expect(
      AcademicScheduleClassifier.kindOfTitle("2026-1학기 중간고사"),
      AcademicScheduleKind.exam,
    );
  });

  test("AcademicScheduleClassifier classifies lecture evaluation as grades", () {
    expect(
      AcademicScheduleClassifier.kindOfTitle("중간 강의평가"),
      AcademicScheduleKind.grades,
    );
  });

  test("AcademicScheduleClassifier classifies worship", () {
    expect(
      AcademicScheduleClassifier.kindOfTitle("학생 부활절예배"),
      AcademicScheduleKind.worship,
    );
  });

  test("AcademicScheduleClassifier classifies registration", () {
    expect(
      AcademicScheduleClassifier.kindOfTitle("수강신청 기간"),
      AcademicScheduleKind.registration,
    );
  });

  test("AcademicScheduleClassifier classifies grades", () {
    expect(
      AcademicScheduleClassifier.kindOfTitle("성적 열람 및 이의신청"),
      AcademicScheduleKind.grades,
    );
  });

  test("AcademicScheduleClassifier classifies scholarship", () {
    expect(
      AcademicScheduleClassifier.kindOfTitle("등록금 납부 안내"),
      AcademicScheduleKind.scholarship,
    );
  });

  test("AcademicScheduleClassifier defaults to general", () {
    expect(
      AcademicScheduleClassifier.kindOfTitle("학과 행사 안내"),
      AcademicScheduleKind.general,
    );
  });
}

