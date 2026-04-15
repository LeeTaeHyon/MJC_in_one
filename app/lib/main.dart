import "dart:convert";
import "package:firebase_core/firebase_core.dart";
import "package:flutter/material.dart";
import "package:flutter/scheduler.dart" as sched;
import "package:mio_notice/agent_debug_log.dart";
import "package:mio_notice/firebase_options.dart";
import "package:mio_notice/notification_history_prefs.dart";
import "package:mio_notice/notification_sources.dart";
import "package:mio_notice/screens/main_navigation_screen.dart";
import "package:mio_notice/theme/app_theme.dart";
import "package:mio_notice/widgets/scroll_to_top_fab.dart";
import "package:mio_notice/widgets/scroll_to_top_scope.dart";
import "package:mio_notice/perf_debug_context.dart";
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
  final enabledSources = prefs.getStringList(kNotificationSourcesPrefKey) ??
      defaultNotificationSources();
  final source = resolveNotificationSource(
    Map<String, dynamic>.from(message.data),
  );
  if (!enabledSources.contains(source)) return;

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
    // 1. 내역 저장을 위한 데이터 구성
    final now = DateTime.now();
    final historyItem = {
      "title": title,
      "body": body,
      "received_at": "${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}",
      "data": message.data,
    };

    // 2. SharedPreferences에 알람 내역 추가 저장
    final historyStrings = prefs.getStringList(kNotificationHistoryPrefKey) ?? [];
    historyStrings.add(jsonEncode(historyItem));
    
    // 너무 많이 쌓이지 않게 최신 50개만 유지
    if (historyStrings.length > 50) {
      historyStrings.removeAt(0);
    }
    await prefs.setStringList(kNotificationHistoryPrefKey, historyStrings);

    // 3. 실제 기기에 푸시 노티 표시
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

  // #region agent log
  int _h0WindowStartMs = DateTime.now().millisecondsSinceEpoch;
  int _h0Count = 0;
  int _h0CountBuild = 0;
  int _h0CountRaster = 0;
  int _h0MaxBuildUs = 0;
  int _h0MaxRasterUs = 0;
  int _h0CountGt50ms = 0;
  sched.SchedulerBinding.instance.addTimingsCallback(
    (List<sched.FrameTiming> timings) {
      for (final t in timings) {
        final int buildUs = t.buildDuration.inMicroseconds;
        final int rasterUs = t.rasterDuration.inMicroseconds;
        if (buildUs <= 16000 && rasterUs <= 16000) continue;

        _h0Count += 1;
        if (buildUs > 16000) _h0CountBuild += 1;
        if (rasterUs > 16000) _h0CountRaster += 1;
        if (buildUs > _h0MaxBuildUs) _h0MaxBuildUs = buildUs;
        if (rasterUs > _h0MaxRasterUs) _h0MaxRasterUs = rasterUs;
        if (buildUs > 50000 || rasterUs > 50000) _h0CountGt50ms += 1;
      }

      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      final int windowMs = nowMs - _h0WindowStartMs;
      if (windowMs < 2000) return;

      agentDebugNdjson(
        hypothesisId: "H0S",
        location: "main.dart:main:addTimingsCallback",
        message: "jank summary window",
        data: <String, dynamic>{
          "windowMs": windowMs,
          "count": _h0Count,
          "countBuild": _h0CountBuild,
          "countRaster": _h0CountRaster,
          "countGt50ms": _h0CountGt50ms,
          "maxBuildUs": _h0MaxBuildUs,
          "maxRasterUs": _h0MaxRasterUs,
          "activeMainTabIndex": PerfDebugContext.activeMainTabIndex,
          "screen": PerfDebugContext.screen,
        },
      );

      _h0WindowStartMs = nowMs;
      _h0Count = 0;
      _h0CountBuild = 0;
      _h0CountRaster = 0;
      _h0MaxBuildUs = 0;
      _h0MaxRasterUs = 0;
      _h0CountGt50ms = 0;
  },
  );
  // #endregion

  // 웹(Chrome)에서 Firebase 설정이 안되어 있어서 흰 화면이 뜨는 것을 막기 위해 try-catch 처리
  try {
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
  } catch (e) {
    debugPrint("Firebase 초기화 에러 (웹 테스트 등): $e");
  }

  runApp(const MioNoticeApp());
}

class MioNoticeApp extends StatefulWidget {
  const MioNoticeApp({super.key});

  @override
  State<MioNoticeApp> createState() => _MioNoticeAppState();
}

class _MioNoticeAppState extends State<MioNoticeApp> {
  final ScrollToTopCoordinator _scrollToTopCoordinator = ScrollToTopCoordinator();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return ScrollToTopScope(
      coordinator: _scrollToTopCoordinator,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: "명지전문대학 공지",
        theme: buildMjcTheme(),
        builder: (BuildContext context, Widget? child) {
          final Widget body = child ?? const SizedBox.shrink();
          final bool pushedRoute = _navigatorKey.currentState?.canPop() ?? false;
          if (!pushedRoute) {
            return body;
          }
          final double safeBottom = MediaQuery.paddingOf(context).bottom;
          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              body,
              Positioned(
                right: 14,
                bottom: safeBottom + 16,
                child: const ScrollToTopFab(),
              ),
            ],
          );
        },
        home: const MainNavigationScreen(),
      ),
    );
  }
}
