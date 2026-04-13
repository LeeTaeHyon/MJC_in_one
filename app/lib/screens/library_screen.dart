import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:mio_notice/theme/app_colors.dart";
import "package:mio_notice/widgets/scroll_to_top_scope.dart";
import "package:mio_notice/widgets/webview_navigation_overlay.dart";
import "package:share_plus/share_plus.dart";
import "package:url_launcher/url_launcher.dart";
import "package:webview_flutter/webview_flutter.dart";

/// 명지전문대학 도서관 모바일 웹사이트를
/// 앱 내의 웹뷰(WebView) 형태로 띄워주는 화면입니다.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  static const String _homeUrl = "https://lib.mjc.ac.kr/";
  static const String _title = "명지전문대학 도서관";

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  static const String _scrollChannelName = "MjcLibraryScroll";

  late final WebViewController _controller;
  ScrollToTopCoordinator? _scrollToTopCoordinator;
  bool _isLoading = true;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String _currentUrl = LibraryScreen._homeUrl;

  Future<void> _syncNavigationHistory() async {
    final bool back = await _controller.canGoBack();
    final bool forward = await _controller.canGoForward();
    if (!mounted) return;
    setState(() {
      _canGoBack = back;
      _canGoForward = forward;
    });
  }

  void _onLibraryScrollChannelMessage(JavaScriptMessage message) {
    try {
      if (!mounted) return;
      final List<String> parts = message.message.split("|");
      if (parts.length < 2) return;
      final double? y = double.tryParse(parts[0]);
      final double? vh = double.tryParse(parts[1]);
      if (y == null || vh == null) return;
      _scrollToTopCoordinator?.reportMainTabScroll(
        MainNavTabIndex.library,
        y,
        vh,
      );
    } catch (e, st) {
      debugPrint("library scroll channel: $e\n$st");
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
        onMessageReceived: _onLibraryScrollChannelMessage,
      );
    }

    controller
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
            _syncNavigationHistory();
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });
            _syncNavigationHistory();
            if (!kIsWeb) {
              _installLibraryScrollReporter();
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint("WebView Error: ${error.description}");
          },
        ),
      )
      ..loadRequest(Uri.parse(LibraryScreen._homeUrl));

    _controller = controller;
  }

  Future<void> _installLibraryScrollReporter() async {
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
  if (!window.__mjcLibScroll) {
    window.__mjcLibScroll = true;
    window.addEventListener("scroll", send, {passive: true});
  }
  send();
})();
""");
    } catch (e) {
      debugPrint("library scroll hook: $e");
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ScrollToTopCoordinator? c = ScrollToTopScope.maybeOf(context);
    if (c != null) {
      _scrollToTopCoordinator = c;
      c.registerMainTab(MainNavTabIndex.library, _scrollWebToTop);
    }
  }

  Future<void> _scrollWebToTop() async {
    try {
      await _controller.runJavaScript("window.scrollTo(0, 0);");
    } catch (e) {
      debugPrint("scrollToTop (library webview): $e");
    }
  }

  @override
  void dispose() {
    _scrollToTopCoordinator?.unregisterMainTab(MainNavTabIndex.library);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.library,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          LibraryScreen._title,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "새로고침",
            onPressed: () => _controller.reload(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.share_outlined, size: 22),
            color: Colors.white,
            onSelected: (value) async {
              if (value == "share") {
                await Share.share("${LibraryScreen._title}\n$_currentUrl");
              } else if (value == "browser") {
                final uri = Uri.parse(_currentUrl);
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (e) {
                  debugPrint("Could not launch $uri: $e");
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
            color: Colors.white.withValues(alpha: 0.25),
            height: 1.0,
          ),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.library),
                  SizedBox(height: 16),
                  Text(
                    "도서관 페이지를 불러오는 중...",
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          WebViewNavigationOverlay(
            canGoBack: _canGoBack,
            canGoForward: _canGoForward,
            activeColor: AppColors.library,
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
