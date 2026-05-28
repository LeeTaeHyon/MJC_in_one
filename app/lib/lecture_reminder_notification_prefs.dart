import "package:shared_preferences/shared_preferences.dart";

const String kLectureReminderNotificationEnabledPrefKey =
    "lecture_reminder_notification_enabled";

/// 시간표 기준 강의 알림을 알림 패널에 상시 표시할지 여부.
abstract final class LectureReminderNotificationPrefs {
  static Future<bool> isEnabled() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kLectureReminderNotificationEnabledPrefKey) ?? false;
  }

  static Future<void> setEnabled(bool enabled) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kLectureReminderNotificationEnabledPrefKey, enabled);
  }
}
