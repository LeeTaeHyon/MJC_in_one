import "package:flutter/material.dart";
import "package:mjc_in_one/screens/common_webview_screen.dart";

/// 명지전문대학 도서관 모바일 웹사이트를
/// 앱 내의 웹뷰(WebView) 형태로 띄워주는 화면입니다.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  static const String _homeUrl = "https://lib.mjc.ac.kr/";
  static const String _title = "명지전문대학 도서관";

  @override
  Widget build(BuildContext context) {
    return const CommonWebViewScreen(
      url: _homeUrl,
      title: _title,
    );
  }
}
