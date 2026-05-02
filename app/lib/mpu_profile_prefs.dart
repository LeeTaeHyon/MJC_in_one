import "package:shared_preferences/shared_preferences.dart";

const String kMpuProfileNamePrefKey = "mpu_profile_name";
const String kMpuProfileDepartmentPrefKey = "mpu_profile_department";
const String kMpuProfileGradePrefKey = "mpu_profile_grade";
const String kMpuProfileStudentIdPrefKey = "mpu_profile_student_id";
const String kMpuProfileMileagePrefKey = "mpu_profile_mileage";

class MpuProfile {
  const MpuProfile({
    required this.name,
    required this.department,
    required this.grade,
    required this.studentId,
    required this.mileage,
  });

  final String name;
  final String department;
  final String grade;
  final String studentId;

  /// 대시보드에 보이는 마이 마일리지 등 숫자(문자열).
  final String mileage;

  bool get hasAnyValue =>
      name.trim().isNotEmpty ||
      department.trim().isNotEmpty ||
      grade.trim().isNotEmpty ||
      studentId.trim().isNotEmpty ||
      mileage.trim().isNotEmpty;

  MpuProfile copyWith({
    String? name,
    String? department,
    String? grade,
    String? studentId,
    String? mileage,
  }) {
    return MpuProfile(
      name: name ?? this.name,
      department: department ?? this.department,
      grade: grade ?? this.grade,
      studentId: studentId ?? this.studentId,
      mileage: mileage ?? this.mileage,
    );
  }
}

Future<MpuProfile> loadMpuProfile() async {
  final prefs = await SharedPreferences.getInstance();
  return MpuProfile(
    name: prefs.getString(kMpuProfileNamePrefKey) ?? "",
    department: prefs.getString(kMpuProfileDepartmentPrefKey) ?? "",
    grade: prefs.getString(kMpuProfileGradePrefKey) ?? "",
    studentId: prefs.getString(kMpuProfileStudentIdPrefKey) ?? "",
    mileage: prefs.getString(kMpuProfileMileagePrefKey) ?? "",
  );
}

Future<void> saveMpuProfile(MpuProfile profile) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kMpuProfileNamePrefKey, profile.name.trim());
  await prefs.setString(
    kMpuProfileDepartmentPrefKey,
    profile.department.trim(),
  );
  await prefs.setString(kMpuProfileGradePrefKey, profile.grade.trim());
  await prefs.setString(kMpuProfileStudentIdPrefKey, profile.studentId.trim());
  await prefs.setString(kMpuProfileMileagePrefKey, profile.mileage.trim());
}

Future<void> clearMpuProfile() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(kMpuProfileNamePrefKey);
  await prefs.remove(kMpuProfileDepartmentPrefKey);
  await prefs.remove(kMpuProfileGradePrefKey);
  await prefs.remove(kMpuProfileStudentIdPrefKey);
  await prefs.remove(kMpuProfileMileagePrefKey);
}
