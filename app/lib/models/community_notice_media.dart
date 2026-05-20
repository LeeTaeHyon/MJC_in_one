/// 학과 공지 이미지·첨부 메타 (Firestore `images` / `attachments` 배열).
class CommunityNoticeMediaItem {
  const CommunityNoticeMediaItem({
    required this.url,
    required this.storagePath,
    required this.name,
    this.contentType,
    this.sizeBytes,
  });

  final String url;
  final String storagePath;
  final String name;
  final String? contentType;
  final int? sizeBytes;

  Map<String, dynamic> toMap() => <String, dynamic>{
        "url": url,
        "storage_path": storagePath,
        "name": name,
        if (contentType != null) "content_type": contentType,
        if (sizeBytes != null) "size_bytes": sizeBytes,
      };

  static CommunityNoticeMediaItem? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final String url = (raw["url"] as String?)?.trim() ?? "";
    final String path = (raw["storage_path"] as String?)?.trim() ?? "";
    if (url.isEmpty && path.isEmpty) return null;
    return CommunityNoticeMediaItem(
      url: url,
      storagePath: path,
      name: (raw["name"] as String?)?.trim() ?? _nameFromPath(path),
      contentType: raw["content_type"] as String?,
      sizeBytes: (raw["size_bytes"] as num?)?.toInt(),
    );
  }

  static String _nameFromPath(String path) {
    if (path.isEmpty) return "file";
    final int i = path.lastIndexOf("/");
    return i >= 0 ? path.substring(i + 1) : path;
  }
}

/// Firestore 글 문서 → 이미지·첨부 목록 (구형 단일 필드 호환).
abstract final class CommunityNoticePostMedia {
  CommunityNoticePostMedia._();

  static const int maxImages = 3;
  static const int maxAttachments = 3;

  static List<CommunityNoticeMediaItem> imagesFromPost(
    Map<String, dynamic> data,
  ) {
    final Object? raw = data["images"];
    if (raw is List) {
      final List<CommunityNoticeMediaItem> list = raw
          .map(CommunityNoticeMediaItem.fromMap)
          .whereType<CommunityNoticeMediaItem>()
          .toList(growable: false);
      if (list.isNotEmpty) return list;
    }

    final String url = (data["image_url"] as String?)?.trim() ?? "";
    final String path = (data["image_storage_path"] as String?)?.trim() ?? "";
    if (url.isEmpty && path.isEmpty) return const [];
    return [
      CommunityNoticeMediaItem(
        url: url,
        storagePath: path,
        name: "image.jpg",
      ),
    ];
  }

  static List<CommunityNoticeMediaItem> attachmentsFromPost(
    Map<String, dynamic> data,
  ) {
    final Object? raw = data["attachments"];
    if (raw is! List) return const [];
    return raw
        .map(CommunityNoticeMediaItem.fromMap)
        .whereType<CommunityNoticeMediaItem>()
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> imagesToMaps(
    List<CommunityNoticeMediaItem> items,
  ) =>
      items.map((e) => e.toMap()).toList(growable: false);

  static List<Map<String, dynamic>> attachmentsToMaps(
    List<CommunityNoticeMediaItem> items,
  ) =>
      items.map((e) => e.toMap()).toList(growable: false);
}
