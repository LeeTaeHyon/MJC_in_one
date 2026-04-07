import "package:firebase_core/firebase_core.dart";
import "package:flutter/material.dart";
import "package:mio_notice/firebase_options.dart";
import "package:mio_notice/screens/main_navigation_screen.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
