import "dart:typed_data";

import "package:mjc_in_one/utils/notice_image_download.dart";

Future<NoticeImageDownloadResult> saveNoticeImageBytes(
  Uint8List bytes,
  String fileName,
) {
  return Future<NoticeImageDownloadResult>.value(
    const NoticeImageDownloadResult.failure("이미지 저장을 지원하지 않는 환경입니다."),
  );
}
