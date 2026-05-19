import "package:flutter/material.dart";
import "package:mjc_in_one/utils/notice_image_download.dart";
import "package:share_plus/share_plus.dart";

/// 공지 HTML 본문 이미지 전체 화면 뷰어.
class NoticeHtmlImageViewer extends StatefulWidget {
  const NoticeHtmlImageViewer({
    super.key,
    required this.imageUrl,
  });

  final String imageUrl;

  static Future<void> open(BuildContext context, String imageUrl) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => NoticeHtmlImageViewer(imageUrl: imageUrl),
      ),
    );
  }

  @override
  State<NoticeHtmlImageViewer> createState() => _NoticeHtmlImageViewerState();
}

class _NoticeHtmlImageViewerState extends State<NoticeHtmlImageViewer> {
  bool _isDownloading = false;

  Future<void> _download() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    final NoticeImageDownloadResult result =
        await downloadNoticeImage(widget.imageUrl);
    if (!mounted) return;
    setState(() => _isDownloading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  Future<void> _share() async {
    await Share.shareUri(Uri.parse(widget.imageUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text("이미지"),
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
          child: Image.network(
            widget.imageUrl,
            fit: BoxFit.contain,
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
        ),
      ),
    );
  }
}
