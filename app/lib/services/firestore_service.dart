import "package:cloud_firestore/cloud_firestore.dart";
import "package:mio_notice/models/notice_model.dart";

/// `notices/{category_id}/posts/{post_id}` 하위 컬렉션을 구독합니다.
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// [categoryId] 예: main_notice, main_academic, main_scholarship
  Stream<List<Notice>> streamNotices(String categoryId) {
    return _db
        .collection("notices")
        .doc(categoryId)
        .collection("posts")
        .orderBy("date", descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(Notice.fromDocument).toList(),
        );
  }
}
