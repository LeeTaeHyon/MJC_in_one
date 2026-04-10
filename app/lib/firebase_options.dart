// FlutterFire CLI로 교체하세요: dart run flutterfire_cli:flutterfire configure
import "package:firebase_core/firebase_core.dart" show FirebaseOptions;
import "package:flutter/foundation.dart"
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "REPLACE_ME",
    appId: "REPLACE_ME",
    messagingSenderId: "REPLACE_ME",
    projectId: "REPLACE_ME",
    authDomain: "REPLACE_ME",
    storageBucket: "REPLACE_ME",
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyDjtMLX0ISRfx9zlks6Yh0MYxybB-52oL0",
    appId: "1:512160526046:android:0bfd687eb5859b75b0dc4f",
    messagingSenderId: "512160526046",
    projectId: "mjcinone",
    storageBucket: "mjcinone.firebasestorage.app",
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "REPLACE_ME",
    appId: "REPLACE_ME",
    messagingSenderId: "REPLACE_ME",
    projectId: "REPLACE_ME",
    storageBucket: "REPLACE_ME",
    iosBundleId: "com.myeongji.mio.mioNotice",
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: "REPLACE_ME",
    appId: "REPLACE_ME",
    messagingSenderId: "REPLACE_ME",
    projectId: "REPLACE_ME",
    storageBucket: "REPLACE_ME",
    iosBundleId: "com.myeongji.mio.mioNotice",
  );
}
