import "package:flutter/material.dart";
import "package:mjc_in_one/models/community_notice_media.dart";
import "package:mjc_in_one/services/community_notice_service.dart";
import "package:mjc_in_one/utils/community_notice_image_download.dart";
import "package:mjc_in_one/utils/notice_image_download.dart";
import "package:mjc_in_one/widgets/community_notice_image.dart";
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
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
  });

  final int pageIndex;
  final CommunityNoticeMediaItem item;
  final CommunityNoticeService service;
  final void Function(int pageIndex, bool isZoomed) onZoomChanged;

  @override
  State<_ZoomableNoticeImagePage> createState() =>
      _ZoomableNoticeImagePageState();
}

class _ZoomableNoticeImagePageState extends State<_ZoomableNoticeImagePage> {
  final TransformationController _transformController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _transformController.addListener(_handleTransformChanged);
  }

  @override
  void dispose() {
    _transformController.removeListener(_handleTransformChanged);
    _transformController.dispose();
    super.dispose();
  }

  void _handleTransformChanged() {
    final double scale = _transformController.value.getMaxScaleOnAxis();
    widget.onZoomChanged(widget.pageIndex, scale > 1.01);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: 0.5,
        maxScale: 4,
        child: CommunityNoticeImage(
          imageUrl: widget.item.url,
          imageStoragePath: widget.item.storagePath,
          fit: BoxFit.contain,
          communityNoticeService: widget.service,
        ),
      ),
    );
  }
}
