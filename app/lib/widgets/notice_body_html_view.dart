import "dart:async";

import "package:flutter/foundation.dart" show Factory, kIsWeb;
import "package:flutter/material.dart";
import "package:flutter/gestures.dart";
import "package:mjc_in_one/widgets/notice_body_html_platform.dart";
import "package:mjc_in_one/widgets/notice_html_image_viewer.dart";
import "package:webview_flutter/webview_flutter.dart";

/// Firestore `body_html` 조각을 앱 테마에 맞춰 WebView 로 렌더합니다.
class NoticeBodyHtmlView extends StatefulWidget {
  const NoticeBodyHtmlView({
    super.key,
    required this.htmlFragment,
    required this.baseUrl,
    required this.colorScheme,
    required this.brightness,
  });

  final String htmlFragment;
  final String baseUrl;
  final ColorScheme colorScheme;
  final Brightness brightness;

  @override
  State<NoticeBodyHtmlView> createState() => _NoticeBodyHtmlViewState();
}

class _NoticeBodyHtmlViewState extends State<NoticeBodyHtmlView> {
  static const double _minHeight = 120;
  static const String _heightChannelName = "FlutterHtmlHeight";
  static const String _imageTapChannelName = "FlutterHtmlImageTap";

  WebViewController? _controller;
  double _webViewHeight = _minHeight;
  bool _isLoading = true;
  Timer? _heightDebounce;
  String? _webViewType;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _registerWebFrame();
    } else {
      _initController();
    }
  }

  void _registerWebFrame() {
    final String html = _buildWrapperHtml(widget.htmlFragment);
    final String viewType =
        "notice-body-html-${identityHashCode(this)}-${html.hashCode}";
    _webViewType = viewType;
    final double height = _estimateWebFrameHeight();
    registerNoticeBodyHtmlPlatformFrame(
      viewType: viewType,
      html: html,
    );
    if (mounted) {
      setState(() {
        _webViewHeight = height;
        _isLoading = false;
      });
    }
  }

  double _estimateWebFrameHeight() {
    final int imgCount =
        RegExp(r"<img\b", caseSensitive: false).allMatches(widget.htmlFragment).length;
    if (imgCount > 0) {
      return 520;
    }
    return 280;
  }

  @override
  void didUpdateWidget(covariant NoticeBodyHtmlView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brightness != widget.brightness ||
        oldWidget.htmlFragment != widget.htmlFragment ||
        oldWidget.baseUrl != widget.baseUrl) {
      _heightDebounce?.cancel();
      setState(() {
        _webViewHeight = _minHeight;
        _isLoading = true;
      });
      if (kIsWeb) {
        _registerWebFrame();
      } else {
        _initController();
      }
    }
  }

  @override
  void dispose() {
    _heightDebounce?.cancel();
    super.dispose();
  }

  void _initController() {
    final WebViewController controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(widget.colorScheme.surface)
      ..addJavaScriptChannel(
        _heightChannelName,
        onMessageReceived: _onHeightMessage,
      )
      ..addJavaScriptChannel(
        _imageTapChannelName,
        onMessageReceived: _onImageTapMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint("NoticeBodyHtmlView: ${error.description}");
          },
          onNavigationRequest: (NavigationRequest request) {
            final String base = _resolvedBaseUrl();
            if (request.url == base ||
                request.url.startsWith("about:") ||
                request.url.startsWith("data:")) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      );

    _controller = controller;
    unawaited(
      controller.loadHtmlString(
        _buildWrapperHtml(widget.htmlFragment),
        baseUrl: _resolvedBaseUrl(),
      ),
    );
  }

  String _resolvedBaseUrl() {
    final String raw = widget.baseUrl.trim();
    if (raw.isEmpty) return "https://www.mjc.ac.kr";
    final Uri? uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) return "https://www.mjc.ac.kr";
    if (uri.hasAuthority) {
      return "${uri.scheme}://${uri.authority}/";
    }
    return raw.endsWith("/") ? raw : "$raw/";
  }

  void _onImageTapMessage(JavaScriptMessage message) {
    final String url = message.message.trim();
    if (url.isEmpty || !mounted) return;
    unawaited(NoticeHtmlImageViewer.open(context, url));
  }

  void _onHeightMessage(JavaScriptMessage message) {
    final double? next = double.tryParse(message.message.trim());
    if (next == null || next <= 0) return;
    final double clamped = next < _minHeight ? _minHeight : next;
    _heightDebounce?.cancel();
    _heightDebounce = Timer(const Duration(milliseconds: 60), () {
      if (!mounted) return;
      if ((_webViewHeight - clamped).abs() < 2) {
        if (_isLoading) setState(() => _isLoading = false);
        return;
      }
      setState(() {
        _webViewHeight = clamped;
        _isLoading = false;
      });
    });
  }

  String _colorHex(Color color) {
    final int rgb = color.toARGB32() & 0xFFFFFF;
    return "#${rgb.toRadixString(16).padLeft(6, "0")}";
  }

  String _buildWrapperHtml(String fragment) {
    final Color surface = widget.colorScheme.surface;
    final Color onSurface = widget.colorScheme.onSurface;
    final Color link = widget.colorScheme.primary;
    final String bg = _colorHex(surface);
    final String fg = _colorHex(onSurface);
    final String anchor = _colorHex(link);

    return """
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <style>
    html, body {
      margin: 0;
      padding: 0;
      background-color: $bg;
      color: $fg;
    }
    body {
      padding: 12px;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      font-size: 15px;
      line-height: 1.55;
      word-break: break-word;
    }
    img {
      max-width: 100%;
      height: auto;
      display: block;
      cursor: pointer;
    }
    a { color: $anchor; }
    table { max-width: 100%; }
  </style>
</head>
<body>
$fragment
<script>
(function () {
  var debounceTimer;
  function sendHeight() {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(function () {
      var h = Math.max(
        document.documentElement.scrollHeight || 0,
        document.body.scrollHeight || 0
      );
      if (window.$_heightChannelName) {
        window.$_heightChannelName.postMessage(String(h + 8));
      }
    }, 60);
  }
  window.addEventListener("load", sendHeight);
  if (window.ResizeObserver) {
    new ResizeObserver(sendHeight).observe(document.body);
  }
  function bindImage(img) {
    if (img.dataset.mjcBound === "1") return;
    img.dataset.mjcBound = "1";
    img.addEventListener("click", function (event) {
      event.preventDefault();
      event.stopPropagation();
      var src = img.currentSrc || img.src;
      if (!src) return;
      if (window.$_imageTapChannelName) {
        window.$_imageTapChannelName.postMessage(src);
        return;
      }
      window.open(src, "_blank");
    });
    if (!img.complete) {
      img.addEventListener("load", sendHeight);
      img.addEventListener("error", sendHeight);
    }
  }
  Array.prototype.forEach.call(document.images, bindImage);
  if (window.MutationObserver) {
    new MutationObserver(function () {
      Array.prototype.forEach.call(document.images, bindImage);
    }).observe(document.body, { childList: true, subtree: true });
  }
  sendHeight();
})();
</script>
</body>
</html>
""";
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      final String? viewType = _webViewType;
      if (viewType == null) {
        return const SizedBox(
          height: _minHeight,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return Container(
        decoration: BoxDecoration(
          color: widget.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: widget.brightness == Brightness.dark ? 0.45 : 0.05,
              ),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: noticeBodyHtmlPlatformFrame(
          viewType: viewType,
          height: _webViewHeight,
        ),
      );
    }

    final WebViewController? controller = _controller;
    if (controller == null) {
      return const SizedBox(
        height: _minHeight,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: widget.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: widget.brightness == Brightness.dark ? 0.45 : 0.05,
            ),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          SizedBox(
            height: _webViewHeight,
            child: WebViewWidget(
              key: ValueKey<String>(
                "${widget.brightness.name}|${widget.htmlFragment.hashCode}",
              ),
              controller: controller,
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<VerticalDragGestureRecognizer>(
                  () => VerticalDragGestureRecognizer(),
                ),
                Factory<HorizontalDragGestureRecognizer>(
                  () => HorizontalDragGestureRecognizer(),
                ),
              },
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: ColoredBox(
                color: widget.colorScheme.surface.withValues(alpha: 0.65),
                child: const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
