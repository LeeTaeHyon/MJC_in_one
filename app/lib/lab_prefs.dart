import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";

const String kLabDepartmentNoticesEnabledPrefKey =
    "lab_department_notices_enabled";
const String kLabDepartmentNoticesSelectedDeptPrefKey =
    "lab_department_notices_selected_department";

/// 실험실 기능 on/off 및 학과 공지 UI 상태.
class LabPrefs {
  LabPrefs._();

  static final ValueNotifier<bool> departmentNoticesEnabled =
      ValueNotifier<bool>(false);
  static final ValueNotifier<String> selectedDepartment =
      ValueNotifier<String>("");

  static bool _loaded = false;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    departmentNoticesEnabled.value =
        prefs.getBool(kLabDepartmentNoticesEnabledPrefKey) ?? false;
    selectedDepartment.value =
        prefs.getString(kLabDepartmentNoticesSelectedDeptPrefKey) ?? "";
    _loaded = true;
  }

  static Future<void> setDepartmentNoticesEnabled(bool enabled) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kLabDepartmentNoticesEnabledPrefKey, enabled);
    departmentNoticesEnabled.value = enabled;
  }

  static Future<void> setSelectedDepartment(String displayName) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kLabDepartmentNoticesSelectedDeptPrefKey,
      displayName,
    );
    selectedDepartment.value = displayName;
  }
}
