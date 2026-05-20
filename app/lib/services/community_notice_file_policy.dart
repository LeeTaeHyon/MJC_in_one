import "package:file_picker/file_picker.dart";

/// 학과 공지 업로드 허용 형식.
abstract final class CommunityNoticeFilePolicy {
  CommunityNoticeFilePolicy._();

  static const int maxImages = 3;
  static const int maxAttachments = 3;

  static const List<String> imageExtensions = <String>[
    "jpg",
    "jpeg",
    "png",
  ];

  static const List<String> attachmentExtensions = <String>[
    "pdf",
    "hwp",
    "hwpx",
    "zip",
  ];

  static const String imagePickerHint =
      "JPG·PNG 사진은 아래 「사진」에서 올려 주세요. "
      "최대 $maxImages장, 업로드 전 자동 압축됩니다.";

  static const String attachmentPickerHint =
      "첨부 허용: PDF, HWP, HWPX, ZIP (최대 $maxAttachments개). "
      "JPG·PNG는 「사진」란을 이용해 주세요.";

  static String? validateImagePick(PlatformFile file) {
    final String ext = _ext(file.extension);
    if (!imageExtensions.contains(ext)) {
      return "사진은 JPG·PNG만 올릴 수 있습니다.";
    }
    return null;
  }

  static String? validateAttachmentPick(PlatformFile file) {
    final String ext = _ext(file.extension);
    if (imageExtensions.contains(ext)) {
      return "JPG·PNG는 「사진」란에서 올려 주세요.";
    }
    if (!attachmentExtensions.contains(ext)) {
      return "첨부는 PDF, HWP, HWPX, ZIP만 가능합니다.";
    }
    return null;
  }

  static String contentTypeForAttachment(String fileName) {
    switch (_extFromName(fileName)) {
      case "pdf":
        return "application/pdf";
      case "zip":
        return "application/zip";
      case "hwp":
        return "application/x-hwp";
      case "hwpx":
        return "application/vnd.hancom.hwpx";
      default:
        return "application/octet-stream";
    }
  }

  static String sanitizeFileName(String name) {
    final String base = name.trim().isEmpty ? "file" : name.trim();
    return base
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), "_")
        .replaceAll(RegExp(r"\s+"), "_");
  }

  static String _ext(String? extension) =>
      (extension ?? "").toLowerCase().replaceAll(".", "");

  static String _extFromName(String name) {
    final int i = name.lastIndexOf(".");
    if (i < 0) return "";
    return name.substring(i + 1).toLowerCase();
  }
}
