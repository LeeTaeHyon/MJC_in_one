import "package:flutter_local_notifications/flutter_local_notifications.dart";

const int kLectureReminderNotificationId = 91001;
const int kLectureReminderClassStartScheduleId = 91002;

const String kLectureReminderChannelId = "mjc_lecture_reminder_channel_v3";
const String kLectureReminderChannelName = "강의 알림";
const String kLectureReminderChannelDescription =
    "시간표에 등록된 다음 수업 시작까지 남은 시간을 알려줍니다.";

bool _lectureReminderPluginInitialized = false;

NotificationDetails scheduledLectureReminderNotificationDetails() {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    kLectureReminderChannelId,
    kLectureReminderChannelName,
    channelDescription: kLectureReminderChannelDescription,
    importance: Importance.high,
    priority: Priority.high,
    ongoing: false,
    autoCancel: true,
    tag: "mjc_lecture_reminder",
    category: AndroidNotificationCategory.event,
    enableVibration: true,
    playSound: true,
  );
  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );
  return const NotificationDetails(android: androidDetails, iOS: iosDetails);
}


Future<void> ensureLectureReminderNotificationChannel(
  FlutterLocalNotificationsPlugin plugin,
) async {
  if (!_lectureReminderPluginInitialized) {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings("ic_notification");
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await plugin.initialize(initSettings);
    _lectureReminderPluginInitialized = true;
  }

  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          kLectureReminderChannelId,
          kLectureReminderChannelName,
          description: kLectureReminderChannelDescription,
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        ),
      );
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
