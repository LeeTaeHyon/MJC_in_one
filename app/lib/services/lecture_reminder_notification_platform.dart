import "dart:io" show Platform;

import "package:flutter/foundation.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";

const int kLectureReminderNotificationId = 91001;
const int kLectureReminderClassStartScheduleId = 91002;

const String kLectureReminderChannelId = "mjc_lecture_reminder_channel";
const String kLectureReminderChannelName = "강의 알림";
const String kLectureReminderChannelDescription =
    "시간표에 등록된 다음 수업 시작까지 남은 시간을 알려줍니다.";

NotificationDetails lectureReminderNotificationDetails({
  int? classStartEpochMs,
}) {
  final bool androidCountdown =
      !kIsWeb && Platform.isAndroid && classStartEpochMs != null;

  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    kLectureReminderChannelId,
    kLectureReminderChannelName,
    channelDescription: kLectureReminderChannelDescription,
    importance: Importance.low,
    priority: Priority.low,
    ongoing: true,
    autoCancel: false,
    onlyAlertOnce: true,
    showWhen: androidCountdown,
    when: classStartEpochMs,
    usesChronometer: androidCountdown,
    chronometerCountDown: androidCountdown,
    tag: "mjc_lecture_reminder",
    category: AndroidNotificationCategory.event,
  );
  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
    presentAlert: false,
    presentBadge: false,
    presentSound: false,
  );
  return NotificationDetails(android: androidDetails, iOS: iosDetails);
}

Future<void> ensureLectureReminderNotificationChannel(
  FlutterLocalNotificationsPlugin plugin,
) async {
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings("@mipmap/ic_launcher");
  const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
  const InitializationSettings initSettings = InitializationSettings(
    android: androidInit,
    iOS: iosInit,
  );
  await plugin.initialize(initSettings);

  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          kLectureReminderChannelId,
          kLectureReminderChannelName,
          description: kLectureReminderChannelDescription,
          importance: Importance.low,
        ),
      );
}

Future<void> showLectureReminderNotification(
  FlutterLocalNotificationsPlugin plugin, {
  required String title,
  required String text,
  required int classStartEpochMs,
  String? subText,
}) async {
  final bool androidCountdown = !kIsWeb && Platform.isAndroid;
  await plugin.show(
    kLectureReminderNotificationId,
    title,
    androidCountdown ? (subText ?? text) : text,
    lectureReminderNotificationDetails(
      classStartEpochMs: androidCountdown ? classStartEpochMs : null,
    ),
  );
}

Future<void> cancelLectureReminderNotification(
  FlutterLocalNotificationsPlugin plugin,
) async {
  await plugin.cancel(kLectureReminderNotificationId);
}

Future<void> cancelLectureReminderClassStartSchedule(
  FlutterLocalNotificationsPlugin plugin,
) async {
  await plugin.cancel(kLectureReminderClassStartScheduleId);
}

Future<bool> requestLectureReminderAndroidPermissions(
  FlutterLocalNotificationsPlugin plugin,
) async {
  final AndroidFlutterLocalNotificationsPlugin? android = plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  if (android == null) return true;

  final bool? notificationsGranted =
      await android.requestNotificationsPermission();
  if (notificationsGranted == false) return false;

  final bool? canExact = await android.canScheduleExactNotifications();
  if (canExact == false) {
    await android.requestExactAlarmsPermission();
    final bool? afterRequest = await android.canScheduleExactNotifications();
    if (afterRequest == false) return false;
  }

  return true;
}

Future<bool> checkLectureReminderNotificationGranted(
  FlutterLocalNotificationsPlugin plugin,
) async {
  final AndroidFlutterLocalNotificationsPlugin? android = plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  if (android == null) return true;

  final bool? enabled = await android.areNotificationsEnabled();
  return enabled ?? true;
}

Future<bool> checkLectureReminderExactAlarmGranted(
  FlutterLocalNotificationsPlugin plugin,
) async {
  final AndroidFlutterLocalNotificationsPlugin? android = plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  if (android == null) return true;

  final bool? canExact = await android.canScheduleExactNotifications();
  return canExact ?? true;
}
