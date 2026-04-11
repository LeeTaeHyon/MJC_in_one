import "package:flutter/material.dart";
import "package:share_plus/share_plus.dart";
import "package:url_launcher/url_launcher.dart";
import "package:webview_flutter/webview_flutter.dart";

/// 앱 내에서 웹페이지를 보여주는 공통 웹뷰 화면입니다.
class CommonWebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const CommonWebViewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<CommonWebViewScreen> createState() => _CommonWebViewScreenState();
}

class _CommonWebViewScreenState extends State<CommonWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint("WebView Error: ${error.description}");
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.share_outlined, size: 22),
            onSelected: (value) async {
              if (value == "share") {
                await Share.share("${widget.title}\n${widget.url}");
              } else if (value == "browser") {
                final uri = Uri.parse(widget.url);
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (e) {
                  debugPrint("Could not launch $uri: $e");
                  // 혹시 실패할 경우를 대비해 safari/chrome 등으로 시도
                  await launchUrl(uri, mode: LaunchMode.platformDefault);
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: "share",
                child: Row(
                  children: [
                    Icon(Icons.share_outlined, size: 20, color: Colors.black87),
                    SizedBox(width: 12),
                    Text("공유하기"),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: "browser",
                child: Row(
                  children: [
                    Icon(Icons.public_outlined, size: 20, color: Colors.black87),
                    SizedBox(width: 12),
                    Text("브라우저로 열기"),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.shade200,
            height: 1.0,
          ),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
