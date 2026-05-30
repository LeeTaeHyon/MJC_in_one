import "package:cloud_firestore/cloud_firestore.dart";
import "package:file_picker/file_picker.dart";
import "package:firebase_storage/firebase_storage.dart";
import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;
import "package:mjc_in_one/firebase_options.dart";
import "package:mjc_in_one/models/community_notice_media.dart";
import "package:mjc_in_one/services/community_notice_file_policy.dart";
import "package:mjc_in_one/utils/community_image_compressor.dart";
import "package:mjc_in_one/utils/community_image_file_bytes_stub.dart"
    if (dart.library.io) "package:mjc_in_one/utils/community_image_file_bytes_io.dart";

/// 학과 공지 `community_notices/{deptSlug}/posts`.
class CommunityNoticeService {
  CommunityNoticeService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? _defaultStorage();

  static FirebaseStorage _defaultStorage() {
    final String? bucket =
        DefaultFirebaseOptions.currentPlatform.storageBucket;
    if (bucket == null || bucket.isEmpty) {
      return FirebaseStorage.instance;
    }
    return FirebaseStorage.instanceFor(bucket: bucket);
  }

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> _boardRef(String deptSlug) =>
      _db.collection("community_notices").doc(deptSlug).collection("posts");

  DocumentReference<Map<String, dynamic>> _metaRef(String deptSlug) => _db
      .collection("community_notices")
      .doc(deptSlug)
      .collection("meta")
      .doc("info");

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> streamPublishedPosts(
    String deptSlug, {
    int limit = 100,
  }) {
    return _boardRef(deptSlug)
        .where("status", isEqualTo: "published")
        .orderBy("created_at", descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs);
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchPublishedPosts(
    String deptSlug, {
    int limit = 100,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _boardRef(deptSlug)
        .where("status", isEqualTo: "published")
        .orderBy("created_at", descending: true)
        .limit(limit)
        .get();
    return snap.docs;
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> streamAdminPosts(
    String deptSlug, {
    String? statusFilter,
    int limit = 200,
  }) {
    Query<Map<String, dynamic>> q = _boardRef(deptSlug)
        .orderBy("created_at", descending: true)
        .limit(limit);
    if (statusFilter != null && statusFilter != "all") {
      q = q.where("status", isEqualTo: statusFilter);
    }
    return q.snapshots().map((snap) => snap.docs);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getPost({
    required String deptSlug,
    required String postId,
  }) {
    return _boardRef(deptSlug).doc(postId).get();
  }

  Future<void> ensureBoardMeta({
    required String deptSlug,
    required String displayName,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> snap = await _metaRef(deptSlug).get();
    if (snap.exists) return;
    await _metaRef(deptSlug).set(<String, dynamic>{
      "display_name": displayName,
      "active": true,
      "post_count": 0,
      "updated_at": FieldValue.serverTimestamp(),
    });
  }

  Future<String> createPostId(String deptSlug) async {
    return _boardRef(deptSlug).doc().id;
  }

  static const int attachmentMaxBytes = 10 * 1024 * 1024;

  Future<CommunityNoticeMediaItem> uploadImageAtIndex({
    required String deptSlug,
    required String postId,
    required int index,
    required PlatformFile file,
  }) async {
    final String? err = CommunityNoticeFilePolicy.validateImagePick(file);
    if (err != null) throw CommunityNoticeException(err);

    final CompressedCommunityImage compressed =
        await CommunityImageCompressor.compress(file);

    final String storagePath =
        "community_notices/$deptSlug/$postId/images/$index.jpg";
    final Reference ref = _storage.ref().child(storagePath);

    await ref.putData(
      compressed.bytes,
      SettableMetadata(
        contentType: "image/jpeg",
        cacheControl: "public,max-age=31536000",
      ),
    );

    final String url = await ref.getDownloadURL();
    return CommunityNoticeMediaItem(
      url: url,
      storagePath: storagePath,
      name: "$index.jpg",
      contentType: "image/jpeg",
      sizeBytes: compressed.compressedBytes,
    );
  }

  Future<CommunityNoticeMediaItem> uploadAttachment({
    required String deptSlug,
    required String postId,
    required PlatformFile file,
  }) async {
    final String? err = CommunityNoticeFilePolicy.validateAttachmentPick(file);
    if (err != null) throw CommunityNoticeException(err);

    final Uint8List raw = await readPlatformFileBytes(file);
    if (raw.isEmpty) {
      throw CommunityNoticeException("파일을 읽을 수 없습니다.");
    }
    if (raw.length > attachmentMaxBytes) {
      throw CommunityNoticeException(
        "첨부파일은 ${attachmentMaxBytes ~/ (1024 * 1024)}MB 이하여야 합니다.",
      );
    }

    final String safeName =
        CommunityNoticeFilePolicy.sanitizeFileName(file.name);
    final String storagePath =
        "community_notices/$deptSlug/$postId/attachments/$safeName";
    final String contentType =
        CommunityNoticeFilePolicy.contentTypeForAttachment(safeName);

    final Reference ref = _storage.ref().child(storagePath);
    await ref.putData(
      raw,
      SettableMetadata(
        contentType: contentType,
        cacheControl: "public,max-age=31536000",
      ),
    );

    final String url = await ref.getDownloadURL();
    return CommunityNoticeMediaItem(
      url: url,
      storagePath: storagePath,
      name: safeName,
      contentType: contentType,
      sizeBytes: raw.length,
    );
  }

  Future<void> deleteStoragePaths(Iterable<String> paths) async {
    for (final String path in paths) {
      await deleteStoragePath(path);
    }
  }

  static const int imageDownloadMaxBytes = 512 * 1024;

  /// Storage 경로 우선으로 이미지 바이트 로드 (표시용, 네이티브 전용).
  Future<Uint8List?> loadImageBytes({
    String? imageStoragePath,
    String? imageUrl,
    int maxBytes = imageDownloadMaxBytes,
  }) async {
    if (kIsWeb) return null;

    final String path = imageStoragePath?.trim() ?? "";
    if (path.isNotEmpty) {
      try {
        final Uint8List? data =
            await _storage.ref().child(path).getData(maxBytes);
        if (data != null && data.isNotEmpty) {
          return data;
        }
        debugPrint("loadImageBytes: empty getData for $path");
      } catch (e, st) {
        debugPrint("loadImageBytes getData($path): $e\n$st");
      }
    }

    final String? url = await resolveImageDownloadUrl(
      imageUrl: imageUrl,
      imageStoragePath: null,
    );
    if (url == null || url.isEmpty) return null;

    try {
      final http.Response response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
      debugPrint(
        "loadImageBytes http ${response.statusCode} for ${url.length} chars",
      );
    } catch (e, st) {
      debugPrint("loadImageBytes http: $e\n$st");
    }
    return null;
  }

  /// 표시용 다운로드 URL. [imageStoragePath]가 있으면 Storage에서 최신 URL을 받는다.
  Future<String?> resolveImageDownloadUrl({
    String? imageUrl,
    String? imageStoragePath,
    bool preferStoredUrlOnWeb = false,
  }) async {
    final String stored = _normalizeLegacyStorageUrl(imageUrl?.trim() ?? "");
    if (preferStoredUrlOnWeb && kIsWeb && stored.startsWith("https://")) {
      return stored;
    }

    final String path = imageStoragePath?.trim() ?? "";
    if (path.isNotEmpty) {
      try {
        return await _storage.ref().child(path).getDownloadURL();
      } catch (e, st) {
        debugPrint("resolveImageDownloadUrl(path): $e\n$st");
      }
    }

    if (stored.isEmpty) return null;
    final String url = stored;

    if (url.startsWith("gs://")) {
      try {
        return await _storage.refFromURL(url).getDownloadURL();
      } catch (e, st) {
        debugPrint("resolveImageDownloadUrl(gs): $e\n$st");
      }
      return null;
    }

    return url;
  }

  String _normalizeLegacyStorageUrl(String url) {
    if (url.isEmpty) return url;
    final String? bucket = DefaultFirebaseOptions.currentPlatform.storageBucket;
    if (bucket == null || bucket.isEmpty) return url;
    return url.replaceAll(
      "mjcinone.appspot.com",
      bucket,
    );
  }

  Future<void> deleteStoragePath(String? storagePath) async {
    final String path = storagePath?.trim() ?? "";
    if (path.isEmpty) return;
    try {
      await _storage.ref().child(path).delete();
    } catch (_) {
      // Best-effort cleanup.
    }
  }

  Future<void> savePost({
    required String deptSlug,
    required String postId,
    required String departmentName,
    required String title,
    required String author,
    required String body,
    required String date,
    required String status,
    required String createdByUid,
    String? sourceNote,
    List<CommunityNoticeMediaItem> images = const [],
    List<CommunityNoticeMediaItem> attachments = const [],
    bool isNew = true,
  }) async {
    await ensureBoardMeta(deptSlug: deptSlug, displayName: departmentName);

    final Map<String, dynamic> data = <String, dynamic>{
      "title": title.trim(),
      "author": author.trim(),
      "body": body.trim(),
      "department_name": departmentName,
      "department_slug": deptSlug,
      "date": date,
      "status": status,
      "source_note": sourceNote?.trim() ?? "",
      "updated_at": FieldValue.serverTimestamp(),
      "created_by_uid": createdByUid,
      "images": CommunityNoticePostMedia.imagesToMaps(images),
      "attachments": CommunityNoticePostMedia.attachmentsToMaps(attachments),
    };

    if (!isNew) {
      data["image_url"] = FieldValue.delete();
      data["image_storage_path"] = FieldValue.delete();
    }

    final DocumentReference<Map<String, dynamic>> ref =
        _boardRef(deptSlug).doc(postId);
    if (isNew) {
      data["created_at"] = FieldValue.serverTimestamp();
      await ref.set(data);
    } else {
      await ref.set(data, SetOptions(merge: true));
    }
  }

  Future<void> deletePost({
    required String deptSlug,
    required String postId,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> snap =
        await getPost(deptSlug: deptSlug, postId: postId);
    final Map<String, dynamic> data = snap.data() ?? {};
    final List<String> paths = <String>[
      ...CommunityNoticePostMedia.imagesFromPost(data)
          .map((e) => e.storagePath)
          .where((p) => p.isNotEmpty),
      ...CommunityNoticePostMedia.attachmentsFromPost(data)
          .map((e) => e.storagePath)
          .where((p) => p.isNotEmpty),
    ];
    await deleteStoragePaths(paths);
    await _boardRef(deptSlug).doc(postId).delete();
  }

}

class CommunityNoticeException implements Exception {
  CommunityNoticeException(this.message);
  final String message;

  @override
  String toString() => message;
}
