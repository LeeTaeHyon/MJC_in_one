import "package:firebase_core/firebase_core.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter/foundation.dart";
import "package:mio_notice/firebase_options.dart";

Future<void>? _firebaseStartupFuture;

/// [main]에서 [runApp] 직전에 한 번 호출해 Firebase 초기화를 시작한다.
/// UI는 즉시 뜨고, [waitForFirebaseStartup]으로 완료를 기다린 뒤 Firestore 등을 쓰면 된다.
Future<void> startFirebaseAppServices({
  required void Function(RemoteMessage message) onForegroundMessage,
}) {
  return _firebaseStartupFuture ??=
      _bootstrapFirebase(onForegroundMessage: onForegroundMessage);
}

/// Firestore·Auth 등을 쓰기 전에 호출해 초기화가 끝날 때까지 기다린다.
Future<void> waitForFirebaseStartup() async {
  final Future<void>? f = _firebaseStartupFuture;
  if (f != null) await f;
}

Future<void> _bootstrapFirebase({
  required void Function(RemoteMessage message) onForegroundMessage,
}) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    FirebaseMessaging.onMessage.listen(onForegroundMessage);

    await messaging.subscribeToTopic("all_notices");
  } catch (e, st) {
    debugPrint("Firebase 초기화 에러 (웹 테스트 등): $e\n$st");
  }
}
