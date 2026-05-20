import "package:mjc_in_one/utils/notice_image_download.dart";

Future<NoticeImageDownloadResult> communityNoticeWebAnchorDownload(
  String url,
  String fileName,
) async {
  return const NoticeImageDownloadResult.failure("웹 다운로드를 사용할 수 없습니다.");
}
