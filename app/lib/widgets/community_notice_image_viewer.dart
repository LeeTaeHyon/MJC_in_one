import "package:flutter/material.dart";
import "package:mjc_in_one/models/community_notice_media.dart";
import "package:mjc_in_one/services/community_notice_service.dart";
import "package:mjc_in_one/utils/community_notice_image_download.dart";
import "package:mjc_in_one/utils/notice_image_download.dart";
import "package:mjc_in_one/widgets/community_notice_image.dart";
import "package:share_plus/share_plus.dart";

/// 학과 공지 사진 전체 화면 (확대·다운로드·공유).
class CommunityNoticeImageViewer extends StatefulWidget {
  const CommunityNoticeImageViewer({
    super.key,
    required this.item,
    this.communityNoticeService,
  });

  final CommunityNoticeMediaItem item;
  final CommunityNoticeService? communityNoticeService;

  static Future<void> open(
    BuildContext context,
    CommunityNoticeMediaItem item, {
    CommunityNoticeService? service,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => CommunityNoticeImageViewer(
          item: item,
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
  bool _isDownloading = false;

  Future<void> _download() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    final NoticeImageDownloadResult result =
        await downloadCommunityNoticeImage(
      service: _service,
      imageUrl: widget.item.url,
      imageStoragePath: widget.item.storagePath,
      fileName: widget.item.name,
    );
    if (!mounted) return;
    setState(() => _isDownloading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  Future<void> _share() async {
    final String url = widget.item.url.trim();
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
        title: const Text("사진"),
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
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: CommunityNoticeImage(
            imageUrl: widget.item.url,
            imageStoragePath: widget.item.storagePath,
            fit: BoxFit.contain,
            communityNoticeService: _service,
          ),
        ),
      ),
    );
  }
}
