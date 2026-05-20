import "package:flutter/foundation.dart";
import "package:mjc_in_one/services/community_notice_service.dart";
import "package:mjc_in_one/utils/community_notice_web_download_stub.dart"
    if (dart.library.html) "package:mjc_in_one/utils/community_notice_web_download.dart";
import "package:mjc_in_one/utils/notice_image_download.dart";
import "package:mjc_in_one/utils/notice_image_download_platform.dart"
    as platform;

/// 학과 공지 사진 저장 (Storage 경로 우선, 웹은 URL 직접 다운로드).
Future<NoticeImageDownloadResult> downloadCommunityNoticeImage({
  required CommunityNoticeService service,
  String? imageUrl,
  String? imageStoragePath,
  String? fileName,
}) async {
  final String name = (fileName ?? "community_notice.jpg").trim();

  if (!kIsWeb) {
    final bytes = await service.loadImageBytes(
      imageStoragePath: imageStoragePath,
      imageUrl: imageUrl,
    );
    if (bytes != null && bytes.isNotEmpty) {
      return platform.saveNoticeImageBytes(bytes, name);
    }
  }

  final String? url = await service.resolveImageDownloadUrl(
    imageUrl: imageUrl,
    imageStoragePath: imageStoragePath,
    preferStoredUrlOnWeb: true,
  );
  if (url == null || url.isEmpty) {
    return const NoticeImageDownloadResult.failure("이미지 주소가 없습니다.");
  }

  if (kIsWeb) {
    return communityNoticeWebAnchorDownload(url, name);
  }

  return downloadNoticeImage(url);
}
