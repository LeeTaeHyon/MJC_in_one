import "package:flutter/material.dart";
import "package:mjc_in_one/utils/notice_image_download.dart";
import "package:mjc_in_one/widgets/mjc_zoomable_image_viewport.dart";
import "package:share_plus/share_plus.dart";

/// 공지 HTML 본문 이미지 전체 화면 뷰어.
class NoticeHtmlImageViewer extends StatefulWidget {
  const NoticeHtmlImageViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  final List<String> imageUrls;
  final int initialIndex;

  static Future<void> open(
    BuildContext context,
    String imageUrl, {
    List<String>? imageUrls,
    int? initialIndex,
  }) {
    final List<String> allImages =
        (imageUrls != null && imageUrls.isNotEmpty)
            ? imageUrls
            : <String>[imageUrl];
    int index = initialIndex ?? allImages.indexOf(imageUrl);
    if (index < 0 || index >= allImages.length) {
      index = 0;
    }

    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => NoticeHtmlImageViewer(
          imageUrls: allImages,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  State<NoticeHtmlImageViewer> createState() => _NoticeHtmlImageViewerState();
}

class _NoticeHtmlImageViewerState extends State<NoticeHtmlImageViewer> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _isDownloading = false;
  bool _pageScrollEnabled = true;

  bool get _hasMultipleImages => widget.imageUrls.length > 1;
  String get _currentUrl => widget.imageUrls[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
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
    if (target < 0 || target >= widget.imageUrls.length) return;

    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _download() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    final NoticeImageDownloadResult result =
        await downloadNoticeImage(_currentUrl);
    if (!mounted) return;
    setState(() => _isDownloading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  Future<void> _share() async {
    await Share.shareUri(Uri.parse(_currentUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          _hasMultipleImages
              ? "이미지 ${_currentIndex + 1}/${widget.imageUrls.length}"
              : "이미지",
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
              itemCount: widget.imageUrls.length,
              onPageChanged: _onPageChanged,
              physics: _pageScrollEnabled
                  ? const PageScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              itemBuilder: (BuildContext context, int index) {
                return _NoticeHtmlZoomableImagePage(
                  key: ValueKey<String>("${widget.imageUrls[index]}|$index"),
                  pageIndex: index,
                  imageUrl: widget.imageUrls[index],
                  onZoomChanged: _onZoomChanged,
                  onHorizontalSwipeAtEdge: _onZoomedImageSwipeAtEdge,
                );
              },
            ),
          ),
          if (_hasMultipleImages)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < widget.imageUrls.length; i++)
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

class _NoticeHtmlZoomableImagePage extends StatelessWidget {
  const _NoticeHtmlZoomableImagePage({
    super.key,
    required this.pageIndex,
    required this.imageUrl,
    required this.onZoomChanged,
    required this.onHorizontalSwipeAtEdge,
  });

  final int pageIndex;
  final String imageUrl;
  final void Function(int pageIndex, bool isZoomed) onZoomChanged;
  final void Function(
    int pageIndex,
    MjcHorizontalSwipeDirection direction,
  ) onHorizontalSwipeAtEdge;

  @override
  Widget build(BuildContext context) {
    final ImageProvider provider = NetworkImage(imageUrl);

    return MjcZoomableImageViewport(
      imageProvider: provider,
      onZoomChanged: (bool isZoomed) => onZoomChanged(pageIndex, isZoomed),
      onHorizontalSwipeAtEdge: (MjcHorizontalSwipeDirection direction) =>
          onHorizontalSwipeAtEdge(pageIndex, direction),
      child: Image(
        image: provider,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
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
