import "dart:typed_data";

import "package:gal/gal.dart";
import "package:mjc_in_one/utils/notice_image_download.dart";

Future<NoticeImageDownloadResult> saveNoticeImageBytes(
  Uint8List bytes,
  String fileName,
) async {
  final bool hasAccess = await Gal.hasAccess(toAlbum: true);
  if (!hasAccess) {
    final bool granted = await Gal.requestAccess(toAlbum: true);
    if (!granted) {
      return const NoticeImageDownloadResult.failure(
        "사진 저장 권한이 필요합니다.",
      );
    }
  }

  await Gal.putImageBytes(bytes, name: fileName);
  return const NoticeImageDownloadResult.success("사진 앱에 저장했습니다.");
}
