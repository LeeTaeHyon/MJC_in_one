import "dart:js_interop";
import "dart:typed_data";

import "package:mjc_in_one/utils/notice_image_download.dart";
import "package:web/web.dart" as web;

Future<NoticeImageDownloadResult> saveNoticeImageBytes(
  Uint8List bytes,
  String fileName,
) async {
  final web.Blob blob = web.Blob(<web.BlobPart>[bytes.toJS].toJS);
  final String objectUrl = web.URL.createObjectURL(blob);
  final web.HTMLAnchorElement anchor = web.HTMLAnchorElement()
    ..href = objectUrl
    ..download = fileName;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(objectUrl);
  return const NoticeImageDownloadResult.success("다운로드를 시작했습니다.");
}
