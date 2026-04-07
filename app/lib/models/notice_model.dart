import "package:cloud_firestore/cloud_firestore.dart";

/// Firestore 경로 `notices/{category_id}/posts/{post_id}` 문서에 대응하는 모델입니다.
class Notice {
  final String id;
  final String title;
  final String date;
  final String url;
  final String source;
  final String category;
  final bool isNew;

  const Notice({
    required this.id,
    required this.title,
    required this.date,
    required this.url,
    required this.source,
    required this.category,
    required this.isNew,
  });

  factory Notice.fromFirestore(String id, Map<String, dynamic> data) {
    return Notice(
      id: id,
      title: data["title"] as String? ?? "",
      date: data["date"] as String? ?? "",
      url: data["url"] as String? ?? "",
      source: data["source"] as String? ?? "",
      category: data["category"] as String? ?? "",
      isNew: data["is_new"] as bool? ?? false,
    );
  }

  factory Notice.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Notice.fromFirestore(doc.id, data);
  }
}
