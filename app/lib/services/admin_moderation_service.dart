import "package:cloud_firestore/cloud_firestore.dart";

class AdminModerationService {
  AdminModerationService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Query<Map<String, dynamic>> inquiryQuery({required String statusFilter}) {
    Query<Map<String, dynamic>> q = _db
        .collection("developer_inquiries")
        .orderBy("created_at", descending: true)
        .limit(200);
    if (statusFilter != "all") {
      q = q.where("status", isEqualTo: statusFilter);
    }
    return q;
  }

  Future<void> setInquiryStatus({
    required DocumentReference<Map<String, dynamic>> ref,
    required String status,
    required String resolverUid,
  }) async {
    await ref.set(<String, dynamic>{
      "status": status,
      "resolved_by": resolverUid,
      "resolved_at": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveInquiryMemo({
    required DocumentReference<Map<String, dynamic>> ref,
    required String memo,
  }) async {
    await ref.set(<String, dynamic>{
      "admin_memo": memo,
    }, SetOptions(merge: true));
  }

  Future<void> deleteInquiry({
    required DocumentReference<Map<String, dynamic>> ref,
  }) async {
    await ref.delete();
  }

  Query<Map<String, dynamic>> reportQuery({required String statusFilter}) {
    Query<Map<String, dynamic>> q = _db
        .collection("notice_reports")
        .orderBy("created_at", descending: true)
        .limit(200);
    if (statusFilter != "all") {
      q = q.where("status", isEqualTo: statusFilter);
    }
    return q;
  }

  Future<void> setReportStatus({
    required DocumentReference<Map<String, dynamic>> ref,
    required String status,
    required String resolverUid,
  }) async {
    await ref.set(<String, dynamic>{
      "status": status,
      "resolved_by": resolverUid,
      "resolved_at": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteReport({
    required DocumentReference<Map<String, dynamic>> ref,
  }) async {
    await ref.delete();
  }

  Future<void> flagPostForResummary({
    required String boardId,
    required String postId,
  }) async {
    await _db
        .collection("notices")
        .doc(boardId)
        .collection("posts")
        .doc(postId)
        .set(<String, dynamic>{"needs_resummary": true}, SetOptions(merge: true));
  }

  Future<void> clearPostResummaryFlag({
    required String boardId,
    required String postId,
  }) async {
    await _db
        .collection("notices")
        .doc(boardId)
        .collection("posts")
        .doc(postId)
        .set(<String, dynamic>{"needs_resummary": false}, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchNoticePost({
    required String boardId,
    required String postId,
  }) {
    return _db
        .collection("notices")
        .doc(boardId)
        .collection("posts")
        .doc(postId)
        .snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getNoticePost({
    required String boardId,
    required String postId,
  }) async {
    return _db
        .collection("notices")
        .doc(boardId)
        .collection("posts")
        .doc(postId)
        .get();
  }

  Future<void> saveManualSummary({
    required String boardId,
    required String postId,
    required String summary,
    required String editorUid,
    String? relatedReportId,
  }) async {
    final batch = _db.batch();
    final postRef = _db
        .collection("notices")
        .doc(boardId)
        .collection("posts")
        .doc(postId);
    batch.set(postRef, <String, dynamic>{
      "summary": summary,
      "summary_version": "manual",
      "summary_generated_at": DateTime.now().toIso8601String(),
      "needs_resummary": false,
    }, SetOptions(merge: true));

    final rid = relatedReportId ?? "";
    if (rid.isNotEmpty) {
      final reportRef = _db.collection("notice_reports").doc(rid);
      batch.set(reportRef, <String, dynamic>{
        "status": "resolved",
        "resolved_by": editorUid,
        "resolved_at": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }
}

