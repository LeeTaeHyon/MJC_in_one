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

  /// 본문 plain text (크롤러/백필이 채움. 누락 시 빈 문자열).
  final String body;

  /// AI 요약 (휴리스틱 또는 LLM). 누락 시 빈 문자열.
  final String summary;

  /// 요약 생성 방식: `heuristic-v1` / `lmstudio-v1` / `manual` / 빈 문자열.
  final String summaryVersion;

  const Notice({
    required this.id,
    required this.title,
    required this.date,
    required this.url,
    required this.source,
    required this.category,
    required this.isNew,
    this.body = "",
    this.summary = "",
    this.summaryVersion = "",
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
      body: data["body"] as String? ?? "",
      summary: data["summary"] as String? ?? "",
      summaryVersion: data["summary_version"] as String? ?? "",
    );
  }

  factory Notice.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Notice.fromFirestore(doc.id, data);
  }
}
