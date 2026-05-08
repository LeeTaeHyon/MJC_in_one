import "package:cloud_firestore/cloud_firestore.dart";

class NoticeReportService {
  NoticeReportService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<void> submitReport({
    required String boardId,
    required String postId,
    required String postTitle,
    required String postUrl,
    required String reason,
    required String reasonLabel,
    required String comment,
    required String platform,
  }) async {
    final reportRef = _db.collection("notice_reports").doc();
    final postRef = _db
        .collection("notices")
        .doc(boardId)
        .collection("posts")
        .doc(postId);

    bool reportSuccess = false;
    bool updateSuccess = false;

    try {
      await reportRef.set(<String, dynamic>{
        "board_id": boardId,
        "post_id": postId,
        "post_title": postTitle,
        "post_url": postUrl,
        "reason": reason,
        "reason_label": reasonLabel,
        "comment": comment,
        "platform": platform,
        "created_at": FieldValue.serverTimestamp(),
        "status": "open",
      });
      reportSuccess = true;
    } catch (_) {}

    try {
      await postRef.update(
        <String, dynamic>{"reports_count": FieldValue.increment(1)},
      );
      updateSuccess = true;
    } catch (_) {}

    if (!reportSuccess && !updateSuccess) {
      throw Exception("report_write_failed");
    }
  }
}

