import "dart:convert";
import "package:firebase_core/firebase_core.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:mjc_in_one/firebase_options.dart";
import "package:mjc_in_one/notification_history_prefs.dart";
import "package:mjc_in_one/notification_sources.dart";
import "package:mjc_in_one/screens/admin/admin_shell.dart";
import "package:mjc_in_one/screens/inquiry_screen.dart";
import "package:mjc_in_one/screens/intro_screen.dart";
import "package:mjc_in_one/services/keyword_notification_detail.dart";
import "package:mjc_in_one/services/deep_link_handler.dart";
import "package:mjc_in_one/services/firebase_app_startup.dart";
import "package:mjc_in_one/services/user_data_repository.dart";
import "package:mjc_in_one/theme/app_theme.dart";
import "package:mjc_in_one/theme/theme_mode_scope.dart";
import "package:mjc_in_one/debug/app_debug_flags.dart";
import "package:mjc_in_one/debug/scroll_fab_debug.dart";
import "package:mjc_in_one/widgets/scroll_to_top_scope.dart";
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
    final enabledSources = prefs.getStringList(kNotificationSourcesPrefKey) ??
        defaultNotificationSources();
    final source = resolveNotificationSource(
      Map<String, dynamic>.from(message.data),
    );
    if (!enabledSources.contains(source)) return;
    shouldShow = true;
  } else {
    shouldShow = await shouldShowKeywordNotification(
      keywords: keywordsList,
      title: title,
      body: body,
      data: Map<String, dynamic>.from(message.data),
    );
  }

  // 발송 허가된 상태라면 로컬 알람 솜
  if (shouldShow) {
    // 1. 내역 저장을 위한 데이터 구성
    final now = DateTime.now();
    final historyItem = {
      "title": title,
      "body": body,
      "received_at":
          "${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}",
      "data": message.data,
    };

    // 2. SharedPreferences에 알람 내역 추가 저장
    final historyStrings =
        prefs.getStringList(kNotificationHistoryPrefKey) ?? [];
    historyStrings.add(jsonEncode(historyItem));

    // 너무 많이 쌓이지 않게 최신 50개만 유지
    if (historyStrings.length > 50) {
      historyStrings.removeAt(0);
    }
    await prefs.setStringList(kNotificationHistoryPrefKey, historyStrings);

    // 3. 실제 기기에 푸시 노티 표시
    final flnp = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: initSettingsAndroid);
    await flnp.initialize(initSettings);

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'mjc_channel_id',
      'MJC 공지 알림',
      channelDescription: '명지전문대학 새 글 알림입니다.',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await flnp.show(
      message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      platformDetails,
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 백그라운드 메시지 핸들러는 [runApp] 전에 등록해야 한다.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Firebase는 await하지 않는다. 그렇지 않으면 네이티브 스플래시에서 오래 멈춘 뒤
  // Flutter 인트로가 한 프레임만 보이거나 건너뛴 것처럼 느껴진다.
  startFirebaseAppServices(
    onForegroundMessage: _processAndShowNotification,
  );

  runApp(const MioNoticeApp());
}

class MioNoticeApp extends StatefulWidget {
  const MioNoticeApp({super.key});

  @override
  State<MioNoticeApp> createState() => _MioNoticeAppState();
}

class _MioNoticeAppState extends State<MioNoticeApp>
    with WidgetsBindingObserver {
  final ScrollToTopCoordinator _scrollToTopCoordinator =
      ScrollToTopCoordinator();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  ThemeModeController? _themeModeController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      DeepLinkHandler.instance.start(_navigatorKey);
      _maybeOpenAdminFromUrl();
    });
    ThemeModeController.load().then((c) {
      if (!mounted) return;
      setState(() => _themeModeController = c);
    });
  }

  void _maybeOpenAdminFromUrl() {
    if (!kIsWeb) return;
    final String fragment = Uri.base.fragment;
    if (fragment == "/admin" || fragment.startsWith("/admin")) {
      _navigatorKey.currentState?.pushNamed("/admin");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      UserDataRepository.instance.pushSnapshotToCloud();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DeepLinkHandler.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeModeController controller =
        _themeModeController ?? ThemeModeController(ThemeMode.system);
    return ScrollToTopScope(
      coordinator: _scrollToTopCoordinator,
      child: ThemeModeScope(
        controller: controller,
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: controller,
          builder: (context, mode, _) {
            return MaterialApp(
              navigatorKey: _navigatorKey,
              navigatorObservers: ScrollFabDebug.enabled
                  ? <NavigatorObserver>[ScrollFabDebug.navigatorObserver]
                  : const <NavigatorObserver>[],
              title: "명지전문대학 공지",
              theme: buildMjcTheme(),
              darkTheme: buildMjcDarkTheme(),
              themeMode: mode,
              onGenerateRoute: (RouteSettings settings) {
                // 관리자 콘솔: 웹 URL `/#/admin` 또는 설정 > 앱 버전 표시 5회 탭
                if (settings.name == "/admin") {
                  return MaterialPageRoute<void>(
                    builder: (_) => const AdminShell(),
                    settings: settings,
                  );
                }
                return null;
              },
              builder: (BuildContext context, Widget? child) {
                final Widget body = child ?? const SizedBox.shrink();
                final bool pushedRoute =
                    _navigatorKey.currentState?.canPop() ?? false;
                final double safeBottom = MediaQuery.paddingOf(context).bottom;
                if (ScrollFabDebug.enabled) {
                  ScrollFabDebug.reportCanPop(pushedRoute);
                }

                return Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: [
                    body,
                    if (AppDevFeatures.globalInquiryFab)
                      Positioned(
                        left: 16,
                        // 메인 탭바(BottomNavigationBar)를 가리지 않도록 위치 조정
                        bottom: pushedRoute
                            ? safeBottom + 16
                            : safeBottom + 90,
                        child: SafeArea(
                          child: FloatingActionButton.small(
                            heroTag: 'global_feedback_btn',
                            elevation: 4,
                            backgroundColor: Colors.red,
                            onPressed: () {
                              _navigatorKey.currentState?.push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const InquiryScreen(),
                                ),
                              );
                            },
                            child: Icon(
                              Icons.campaign_rounded,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),

                    if (ScrollFabDebug.enabled)
                      const ScrollFabDebugOverlay(),
                  ],
                );
              },
              home: const IntroScreen(),
            );
          },
        ),
      ),
    );
  }
}
