import "package:shared_preferences/shared_preferences.dart";

const String kLectureReminderNotificationEnabledPrefKey =
    "lecture_reminder_notification_enabled";
const String kLectureReminderExactPrefKey = "lecture_reminder_exact";
const String kLectureReminder10mPrefKey = "lecture_reminder_10m";
const String kLectureReminder30mPrefKey = "lecture_reminder_30m";
const String kLectureReminder60mPrefKey = "lecture_reminder_60m";
const String kLectureReminderFirstOnlyPrefKey = "lecture_reminder_first_only";

/// 시간표 기준 강의 알림 설정 저장소.
abstract final class LectureReminderNotificationPrefs {
  static Future<bool> isEnabled() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kLectureReminderNotificationEnabledPrefKey) ?? false;
  }

  static Future<void> setEnabled(bool enabled) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kLectureReminderNotificationEnabledPrefKey, enabled);
  }

  static Future<bool> isExactEnabled() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kLectureReminderExactPrefKey) ?? true;
  }

  static Future<void> setExactEnabled(bool enabled) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kLectureReminderExactPrefKey, enabled);
  }

  static Future<bool> is10mEnabled() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kLectureReminder10mPrefKey) ?? false;
  }

  static Future<void> set10mEnabled(bool enabled) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kLectureReminder10mPrefKey, enabled);
  }

  static Future<bool> is30mEnabled() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kLectureReminder30mPrefKey) ?? false;
  }

  static Future<void> set30mEnabled(bool enabled) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kLectureReminder30mPrefKey, enabled);
  }

  static Future<bool> is60mEnabled() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kLectureReminder60mPrefKey) ?? false;
  }

  static Future<void> set60mEnabled(bool enabled) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kLectureReminder60mPrefKey, enabled);
  }

  static Future<bool> isFirstClassOnlyEnabled() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kLectureReminderFirstOnlyPrefKey) ?? false;
  }

  static Future<void> setFirstClassOnlyEnabled(bool enabled) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kLectureReminderFirstOnlyPrefKey, enabled);
  }
}
