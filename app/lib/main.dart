import "package:firebase_core/firebase_core.dart";
import "package:flutter/material.dart";
import "package:mio_notice/firebase_options.dart";
import "package:mio_notice/screens/main_navigation_screen.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:shared_preferences/shared_preferences.dart";

// 백그라운드 메시지 핸들러 (반드시 최상단 전역 함수로 작성해야 함)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _processAndShowNotification(message);
}

// 키워드 대조 및 로컬 푸시 알람 처리 로직
Future<void> _processAndShowNotification(RemoteMessage message) async {
  if (message.data.isEmpty) return;

  final prefs = await SharedPreferences.getInstance();
  final allNoticesEnabled = prefs.getBool("allNoticesEnabled") ?? true;
  final keywordsList = prefs.getStringList("keywords") ?? [];
  
  final title = message.data["title"] ?? "새 알림";
  final body = message.data["body"] ?? "";
  
  bool shouldShow = false;

  if (allNoticesEnabled) {
    shouldShow = true;
  } else {
    for (String kw in keywordsList) {
      if (body.contains(kw) || title.contains(kw)) {
        shouldShow = true;
        break;
      }
    }
  }

  // 발송 허가된 상태라면 로컬 알람 솜
  if (shouldShow) {
    final flnp = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: initSettingsAndroid);
    await flnp.initialize(initSettings);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'mjc_channel_id',
      'MJC 공지 알림',
      channelDescription: '명지전문대학 새 글 알림입니다.',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    
    await flnp.show(
      message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      platformDetails,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // 알림 권한 요청 (안드로이드 13+, iOS 용)
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();

  // 백그라운드 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // 포그라운드(앱이 켜져 있을 때) 핸들러 등록
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    _processAndShowNotification(message);
  });

  // 토픽 기본 구독 (전체 알람 발송용)
  await messaging.subscribeToTopic("all_notices");

  runApp(const MioNoticeApp());
}

class MioNoticeApp extends StatelessWidget {
  const MioNoticeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "명지전문대학 공지",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}
