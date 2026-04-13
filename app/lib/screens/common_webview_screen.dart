import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:mio_notice/widgets/scroll_to_top_scope.dart";
import "package:mio_notice/widgets/webview_navigation_overlay.dart";
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
  static const String _scrollChannelName = "MjcCommonScroll";

  late final WebViewController _controller;
  ScrollToTopCoordinator? _scrollRouteCoordinator;
  bool _registeredScrollRoute = false;
  bool _isLoading = true;
  bool _canGoBack = false;
  bool _canGoForward = false;

  Future<void> _syncNavigationHistory() async {
    final bool back = await _controller.canGoBack();
    final bool forward = await _controller.canGoForward();
    if (!mounted) return;
    setState(() {
      _canGoBack = back;
      _canGoForward = forward;
    });
  }

  void _onCommonScrollChannelMessage(JavaScriptMessage message) {
    try {
      if (!mounted) return;
      final List<String> parts = message.message.split("|");
      if (parts.length < 2) return;
      final double? y = double.tryParse(parts[0]);
      final double? vh = double.tryParse(parts[1]);
      if (y == null || vh == null) return;
      _scrollRouteCoordinator?.reportRouteScroll(y, vh);
    } catch (e, st) {
      debugPrint("common webview scroll channel: $e\n$st");
    }
  }

  @override
  void initState() {
    super.initState();
    final WebViewController controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);

    if (!kIsWeb) {
      controller.addJavaScriptChannel(
        _scrollChannelName,
        onMessageReceived: _onCommonScrollChannelMessage,
      );
    }

    controller
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
            _syncNavigationHistory();
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            _syncNavigationHistory();
            if (!kIsWeb) {
              _installWebViewScrollReporter();
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint("WebView Error: ${error.description}");
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));

    _controller = controller;
  }

  Future<void> _installWebViewScrollReporter() async {
    try {
      await _controller.runJavaScript("""
(function() {
  function send() {
    try {
      $_scrollChannelName.postMessage(
        String(window.scrollY || window.pageYOffset || 0)
        + "|"
        + String(window.innerHeight || document.documentElement.clientHeight || 0)
      );
    } catch (e) {}
  }
  if (!window.__mjcCommonScroll) {
    window.__mjcCommonScroll = true;
    window.addEventListener("scroll", send, {passive: true});
  }
  send();
})();
""");
    } catch (e) {
      debugPrint("common webview scroll hook: $e");
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_registeredScrollRoute) return;
    final ScrollToTopCoordinator? c = ScrollToTopScope.maybeOf(context);
    if (c != null) {
      _scrollRouteCoordinator = c;
      c.pushRouteHandler(_scrollWebToTop);
      _registeredScrollRoute = true;
    }
  }

  Future<void> _scrollWebToTop() async {
    try {
      await _controller.runJavaScript("window.scrollTo(0, 0);");
    } catch (e) {
      debugPrint("scrollToTop (webview): $e");
    }
  }

  @override
  void dispose() {
    if (_registeredScrollRoute) {
      _scrollRouteCoordinator?.popRouteHandler();
    }
    super.dispose();
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
          WebViewNavigationOverlay(
            canGoBack: _canGoBack,
            canGoForward: _canGoForward,
            onGoBack: () async {
              await _controller.goBack();
              await _syncNavigationHistory();
            },
            onGoForward: () async {
              await _controller.goForward();
              await _syncNavigationHistory();
            },
          ),
        ],
      ),
    );
  }
}
