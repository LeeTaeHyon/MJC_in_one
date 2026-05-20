import "package:mjc_in_one/utils/notice_image_download.dart";
import "package:web/web.dart" as web;

Future<NoticeImageDownloadResult> communityNoticeWebAnchorDownload(
  String url,
  String fileName,
) async {
  try {
    final web.HTMLAnchorElement anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName
      ..target = "_blank";
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    return const NoticeImageDownloadResult.success("다운로드를 시작했습니다.");
  } catch (e) {
    return NoticeImageDownloadResult.failure("다운로드에 실패했습니다. ($e)");
  }
}
