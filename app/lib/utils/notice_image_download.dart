import "dart:typed_data";

import "package:http/http.dart" as http;
import "package:mjc_in_one/utils/notice_image_download_platform.dart"
    as platform;

/// 공지 본문 이미지를 기기에 저장합니다.
Future<NoticeImageDownloadResult> downloadNoticeImage(String url) async {
  final String trimmed = url.trim();
  if (trimmed.isEmpty) {
    return const NoticeImageDownloadResult.failure("이미지 주소가 없습니다.");
  }

  try {
    final http.Response response = await http.get(Uri.parse(trimmed));
    if (response.statusCode != 200) {
      return NoticeImageDownloadResult.failure(
        "이미지를 불러오지 못했습니다. (${response.statusCode})",
      );
    }

    final Uint8List bytes = response.bodyBytes;
    if (bytes.isEmpty) {
      return const NoticeImageDownloadResult.failure("이미지 데이터가 비어 있습니다.");
    }

    return platform.saveNoticeImageBytes(bytes, _fileNameFromUrl(trimmed));
  } catch (e) {
    return NoticeImageDownloadResult.failure("저장에 실패했습니다. ($e)");
  }
}

String _fileNameFromUrl(String url) {
  final Uri? uri = Uri.tryParse(url);
  if (uri != null) {
    final String last =
        uri.pathSegments.isNotEmpty ? uri.pathSegments.last : "";
    if (last.isNotEmpty && last.contains(".")) {
      return last;
    }
  }
  return "mjc_notice_${DateTime.now().millisecondsSinceEpoch}.jpg";
}

class NoticeImageDownloadResult {
  const NoticeImageDownloadResult.success(this.message) : ok = true;

  const NoticeImageDownloadResult.failure(this.message) : ok = false;

  final bool ok;
  final String message;
}
