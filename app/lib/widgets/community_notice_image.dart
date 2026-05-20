import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:mjc_in_one/services/community_notice_service.dart";

/// 학과 공지 Firebase Storage 이미지.
/// - 웹: [Image.network] + [WebHtmlElementStrategy.prefer] (브라우저 img, CORS 회피)
/// - 앱: Storage [getData] → [Image.memory]
class CommunityNoticeImage extends StatefulWidget {
  const CommunityNoticeImage({
    super.key,
    this.imageUrl,
    this.imageStoragePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.communityNoticeService,
  });

  final String? imageUrl;
  final String? imageStoragePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final CommunityNoticeService? communityNoticeService;

  bool get _hasSource =>
      (imageUrl ?? "").trim().isNotEmpty ||
      (imageStoragePath ?? "").trim().isNotEmpty;

  @override
  State<CommunityNoticeImage> createState() => _CommunityNoticeImageState();
}

class _CommunityNoticeImageState extends State<CommunityNoticeImage> {
  late final CommunityNoticeService _service =
      widget.communityNoticeService ?? CommunityNoticeService();

  Future<Uint8List?>? _bytesFuture;
  Future<String?>? _urlFuture;

  /// 웹에서 Firestore URL을 바로 쓰면 SDK·CORS fetch를 피할 수 있음.
  String? _webUrlImmediate;

  bool get _compact {
    final double? h = widget.height;
    final double? w = widget.width;
    if (h != null && h <= 56) return true;
    if (w != null && w.isFinite && w <= 56) return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(CommunityNoticeImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.imageStoragePath != widget.imageStoragePath) {
      _reload();
    }
  }

  void _reload() {
    if (!widget._hasSource) {
      _bytesFuture = null;
      _urlFuture = null;
      _webUrlImmediate = null;
      return;
    }
    if (kIsWeb) {
      _bytesFuture = null;
      final String stored = widget.imageUrl?.trim() ?? "";
      if (stored.startsWith("http://") || stored.startsWith("https://")) {
        _webUrlImmediate = stored;
        _urlFuture = null;
      } else {
        _webUrlImmediate = null;
        _urlFuture = _service.resolveImageDownloadUrl(
          imageUrl: widget.imageUrl,
          imageStoragePath: widget.imageStoragePath,
          preferStoredUrlOnWeb: true,
        );
      }
    } else {
      _webUrlImmediate = null;
      _urlFuture = null;
      _bytesFuture = _service.loadImageBytes(
        imageStoragePath: widget.imageStoragePath,
        imageUrl: widget.imageUrl,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget._hasSource) return const SizedBox.shrink();

    final ColorScheme scheme = Theme.of(context).colorScheme;

    Widget child = kIsWeb ? _buildWeb(scheme) : _buildNative(scheme);

    if (widget.borderRadius != null) {
      child = ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }

    if (widget.width == double.infinity) {
      child = SizedBox(width: double.infinity, child: child);
    }

    return child;
  }

  Widget _buildWebNetworkImage(ColorScheme scheme, String url) {
    return Image.network(
      url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _loadingBox(scheme);
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint("CommunityNoticeImage web: $error");
        return _errorBox(scheme);
      },
    );
  }

  Widget _buildWeb(ColorScheme scheme) {
    final String? immediate = _webUrlImmediate;
    if (immediate != null && immediate.isNotEmpty) {
      return _buildWebNetworkImage(scheme, immediate);
    }

    return FutureBuilder<String?>(
      future: _urlFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _loadingBox(scheme);
        }
        final String? url = snap.data;
        if (url == null || url.isEmpty) {
          return _errorBox(scheme);
        }
        return _buildWebNetworkImage(scheme, url);
      },
    );
  }

  Widget _buildNative(ColorScheme scheme) {
    return FutureBuilder<Uint8List?>(
      future: _bytesFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _loadingBox(scheme);
        }
        if (snap.hasError) {
          debugPrint("CommunityNoticeImage: ${snap.error}");
          return _errorBox(scheme);
        }
        final Uint8List? bytes = snap.data;
        if (bytes == null || bytes.isEmpty) {
          return _errorBox(scheme);
        }

        return Image.memory(
          bytes,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) {
            debugPrint("CommunityNoticeImage decode: $error");
            return _errorBox(scheme);
          },
        );
      },
    );
  }

  Widget _loadingBox(ColorScheme scheme) {
    final double boxHeight = widget.height ?? (_compact ? 48 : 120);
    final double indicator = _compact ? 16 : 24;
    return Container(
      width: widget.width,
      height: boxHeight,
      alignment: Alignment.center,
      color: scheme.surfaceContainerHighest,
      child: SizedBox(
        width: indicator,
        height: indicator,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _errorBox(ColorScheme scheme) {
    final double boxHeight = widget.height ?? (_compact ? 48 : 120);
    return Container(
      width: widget.width,
      height: boxHeight,
      padding: EdgeInsets.all(_compact ? 4 : 12),
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: _compact
          ? Icon(
              Icons.broken_image_outlined,
              size: 20,
              color: scheme.onSurfaceVariant,
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 6),
                Text(
                  "이미지를 불러오지 못했습니다.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
    );
  }
}
