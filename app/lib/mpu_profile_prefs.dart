import "package:shared_preferences/shared_preferences.dart";

const String kMpuProfileNamePrefKey = "mpu_profile_name";
const String kMpuProfileGradePrefKey = "mpu_profile_grade";
const String kMpuProfileMileagePrefKey = "mpu_profile_mileage";

/// @deprecated 예전 필드. 저장 시 제거됨.
const String kMpuProfileDepartmentPrefKey = "mpu_profile_department";

/// @deprecated 학번은 MPU에 노출되지 않아 마일리지로 대체됨. 저장 시 제거됨.
const String kMpuProfileStudentIdPrefKey = "mpu_profile_student_id";

class MpuProfile {
  const MpuProfile({
    required this.name,
    required this.grade,
    required this.mileage,
  });

  final String name;
  final String grade;

  /// 대시보드에 보이는 마이 마일리지 등 숫자(문자열).
  final String mileage;

  bool get hasAnyValue =>
      name.trim().isNotEmpty ||
      grade.trim().isNotEmpty ||
      mileage.trim().isNotEmpty;
}

Future<MpuProfile> loadMpuProfile() async {
  final prefs = await SharedPreferences.getInstance();
  return MpuProfile(
    name: prefs.getString(kMpuProfileNamePrefKey) ?? "",
    grade: prefs.getString(kMpuProfileGradePrefKey) ?? "",
    mileage: prefs.getString(kMpuProfileMileagePrefKey) ?? "",
  );
}

Future<void> saveMpuProfile(MpuProfile profile) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kMpuProfileNamePrefKey, profile.name.trim());
  await prefs.setString(kMpuProfileGradePrefKey, profile.grade.trim());
  await prefs.setString(kMpuProfileMileagePrefKey, profile.mileage.trim());
  await prefs.remove(kMpuProfileDepartmentPrefKey);
  await prefs.remove(kMpuProfileStudentIdPrefKey);
}

Future<void> clearMpuProfile() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(kMpuProfileNamePrefKey);
  await prefs.remove(kMpuProfileGradePrefKey);
  await prefs.remove(kMpuProfileMileagePrefKey);
  await prefs.remove(kMpuProfileDepartmentPrefKey);
  await prefs.remove(kMpuProfileStudentIdPrefKey);
}
