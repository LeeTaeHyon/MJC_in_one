import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:mjc_in_one/models/community_notice_media.dart";
import "package:mjc_in_one/services/community_notice_service.dart";
import "package:mjc_in_one/utils/community_notice_image_download.dart";
import "package:mjc_in_one/utils/notice_image_download.dart";
import "package:mjc_in_one/utils/mjc_snack_bar.dart";
import "package:mjc_in_one/widgets/mjc_zoomable_image_viewport.dart";
import "package:share_plus/share_plus.dart";

/// 학과 공지 사진 전체 화면 (확대·다운로드·공유·좌우 넘기기).
class CommunityNoticeImageViewer extends StatefulWidget {
  const CommunityNoticeImageViewer({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.communityNoticeService,
  });

  final List<CommunityNoticeMediaItem> items;
  final int initialIndex;
  final CommunityNoticeService? communityNoticeService;

  static Future<void> open(
    BuildContext context,
    CommunityNoticeMediaItem item, {
    List<CommunityNoticeMediaItem>? items,
    int? initialIndex,
    CommunityNoticeService? service,
  }) {
    final List<CommunityNoticeMediaItem> allItems =
        (items != null && items.isNotEmpty) ? items : [item];
    int index = initialIndex ?? allItems.indexOf(item);
    if (index < 0 || index >= allItems.length) {
      index = 0;
    }

    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => CommunityNoticeImageViewer(
          items: allItems,
          initialIndex: index,
          communityNoticeService: service,
        ),
      ),
    );
  }

  @override
  State<CommunityNoticeImageViewer> createState() =>
      _CommunityNoticeImageViewerState();
}

class _CommunityNoticeImageViewerState extends State<CommunityNoticeImageViewer> {
  late final CommunityNoticeService _service =
      widget.communityNoticeService ?? CommunityNoticeService();
  late final PageController _pageController;
  late int _currentIndex;
  bool _isDownloading = false;
  bool _pageScrollEnabled = true;

  bool get _hasMultipleItems => widget.items.length > 1;

  CommunityNoticeMediaItem get _currentItem => widget.items[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onZoomChanged(int pageIndex, bool isZoomed) {
    if (pageIndex != _currentIndex) return;
    if (_pageScrollEnabled == !isZoomed) return;
    setState(() => _pageScrollEnabled = !isZoomed);
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _pageScrollEnabled = true;
    });
  }

  void _onZoomedImageSwipeAtEdge(
    int pageIndex,
    MjcHorizontalSwipeDirection direction,
  ) {
    if (pageIndex != _currentIndex || !_pageController.hasClients) return;

    final int delta =
        direction == MjcHorizontalSwipeDirection.next ? 1 : -1;
    final int target = _currentIndex + delta;
    if (target < 0 || target >= widget.items.length) return;

    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _download() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    final CommunityNoticeMediaItem item = _currentItem;
    final NoticeImageDownloadResult result =
        await downloadCommunityNoticeImage(
      service: _service,
      imageUrl: item.url,
      imageStoragePath: item.storagePath,
      fileName: item.name,
    );
    if (!mounted) return;
    setState(() => _isDownloading = false);
    showMjcSnackBar(context, message: result.message);
  }

  Future<void> _share() async {
    final String url = _currentItem.url.trim();
    if (url.isEmpty) return;
    await Share.shareUri(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          _hasMultipleItems
              ? "사진 ${_currentIndex + 1}/${widget.items.length}"
              : "사진",
        ),
        actions: [
          IconButton(
            tooltip: "공유",
            onPressed: _share,
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: "다운로드",
            onPressed: _isDownloading ? null : _download,
            icon: _isDownloading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.items.length,
              onPageChanged: _onPageChanged,
              physics: _pageScrollEnabled
                  ? const PageScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final CommunityNoticeMediaItem item = widget.items[index];
                return _ZoomableNoticeImagePage(
                  key: ValueKey<String>(
                    "${item.storagePath}|${item.url}|$index",
                  ),
                  pageIndex: index,
                  item: item,
                  service: _service,
                  onZoomChanged: _onZoomChanged,
                  onHorizontalSwipeAtEdge: _onZoomedImageSwipeAtEdge,
                );
              },
            ),
          ),
          if (_hasMultipleItems)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < widget.items.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _currentIndex ? 8 : 6,
                      height: i == _currentIndex ? 8 : 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _currentIndex
                            ? Colors.white
                            : Colors.white38,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ZoomableNoticeImagePage extends StatefulWidget {
  const _ZoomableNoticeImagePage({
    super.key,
    required this.pageIndex,
    required this.item,
    required this.service,
    required this.onZoomChanged,
    required this.onHorizontalSwipeAtEdge,
  });

  final int pageIndex;
  final CommunityNoticeMediaItem item;
  final CommunityNoticeService service;
  final void Function(int pageIndex, bool isZoomed) onZoomChanged;
  final void Function(
    int pageIndex,
    MjcHorizontalSwipeDirection direction,
  ) onHorizontalSwipeAtEdge;

  @override
  State<_ZoomableNoticeImagePage> createState() =>
      _ZoomableNoticeImagePageState();
}

class _ZoomableNoticeImagePageState extends State<_ZoomableNoticeImagePage> {
  ImageProvider? _sizeProvider;
  bool _providerResolveStarted = false;

  @override
  void initState() {
    super.initState();
    _resolveSizeProvider();
  }

  @override
  void didUpdateWidget(covariant _ZoomableNoticeImagePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.storagePath != widget.item.storagePath ||
        oldWidget.item.url != widget.item.url) {
      _sizeProvider = null;
      _providerResolveStarted = false;
      _resolveSizeProvider();
    }
  }

  void _resolveSizeProvider() {
    if (_providerResolveStarted) return;
    _providerResolveStarted = true;

    final String url = widget.item.url.trim();
    if (url.startsWith("http://") || url.startsWith("https://")) {
      _setProvider(NetworkImage(url));
      return;
    }

    unawaited(_resolveSizeProviderAsync());
  }

  Future<void> _resolveSizeProviderAsync() async {
    try {
      if (kIsWeb) {
        final String? resolved = await widget.service.resolveImageDownloadUrl(
          imageUrl: widget.item.url,
          imageStoragePath: widget.item.storagePath,
          preferStoredUrlOnWeb: true,
        );
        if (!mounted) return;
        if (resolved != null && resolved.isNotEmpty) {
          _setProvider(NetworkImage(resolved));
          return;
        }
      } else {
        final Uint8List? bytes = await widget.service.loadImageBytes(
          imageStoragePath: widget.item.storagePath,
          imageUrl: widget.item.url,
        );
        if (!mounted) return;
        if (bytes != null && bytes.isNotEmpty) {
          _setProvider(MemoryImage(bytes));
          return;
        }
      }
    } catch (e, st) {
      debugPrint("_ZoomableNoticeImagePage size provider: $e\n$st");
    }
    if (mounted) setState(() => _sizeProvider = null);
  }

  void _setProvider(ImageProvider provider) {
    if (!mounted) return;
    setState(() => _sizeProvider = provider);
  }

  @override
  Widget build(BuildContext context) {
    final ImageProvider? provider = _sizeProvider;
    if (provider == null) {
      return const Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return MjcZoomableImageViewport(
      imageProvider: provider,
      onZoomChanged: (bool isZoomed) =>
          widget.onZoomChanged(widget.pageIndex, isZoomed),
      onHorizontalSwipeAtEdge: (MjcHorizontalSwipeDirection direction) =>
          widget.onHorizontalSwipeAtEdge(widget.pageIndex, direction),
      child: Image(
        image: provider,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        loadingBuilder: (
          BuildContext context,
          Widget child,
          ImageChunkEvent? progress,
        ) {
          if (progress == null) return child;
          return const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(color: Colors.white),
          );
        },
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white70,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  "이미지를 불러오지 못했습니다.",
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
