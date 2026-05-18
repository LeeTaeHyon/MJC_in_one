import "dart:convert";

import "package:mjc_in_one/notification_sources.dart";
import "package:shared_preferences/shared_preferences.dart";

const String kKeywordNotificationDetailsPrefKey =
    "keyword_notification_details_json";

/// 키워드 알림 1개에 대한 세부 조건.
class KeywordNotificationDetail {
  const KeywordNotificationDetail({
    this.sources = const [],
    this.excludeKeywords = const [],
  });

  /// FCM 출처 id (`mjc` · `ctl` · `mpu`). 비어 있으면 전체 출처.
  final List<String> sources;
  final List<String> excludeKeywords;

  static const KeywordNotificationDetail empty = KeywordNotificationDetail();

  KeywordNotificationDetail copyWith({
    List<String>? sources,
    List<String>? excludeKeywords,
  }) {
    return KeywordNotificationDetail(
      sources: sources ?? this.sources,
      excludeKeywords: excludeKeywords ?? this.excludeKeywords,
    );
  }

  Map<String, dynamic> toJson() => {
        "sources": sources,
        "excludeKeywords": excludeKeywords,
      };

  factory KeywordNotificationDetail.fromJson(Map<String, dynamic> json) {
    return KeywordNotificationDetail(
      sources: _parseSources(json),
      excludeKeywords: _stringList(json["excludeKeywords"]),
    );
  }
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((e) => e.toString().trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

List<String> _parseSources(Map<String, dynamic> json) {
  final List<String> stored = _stringList(json["sources"])
      .where(kNotificationSourceIds.contains)
      .toList();
  if (stored.isNotEmpty) return stored;

  // 레거시 `boards`(게시판 유형) → 출처 id로 최대한 변환
  final List<String> legacyBoards = _stringList(json["boards"]);
  if (legacyBoards.isEmpty) return const [];

  final Set<String> migrated = {};
  for (final String board in legacyBoards) {
    if (board.contains("CTL")) {
      migrated.add("ctl");
    } else if (board.contains("MPU") ||
        board.contains("역량") ||
        board.contains("학습")) {
      migrated.add("mpu");
    } else {
      migrated.add("mjc");
    }
  }
  return kNotificationSourceIds.where(migrated.contains).toList();
}

Future<Map<String, KeywordNotificationDetail>>
    loadAllKeywordNotificationDetails() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String raw = prefs.getString(kKeywordNotificationDetailsPrefKey) ?? "";
  if (raw.trim().isEmpty) return {};
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    final Map<String, KeywordNotificationDetail> out = {};
    decoded.forEach((key, value) {
      final String kw = key.toString().trim();
      if (kw.isEmpty || value is! Map) return;
      out[kw] = KeywordNotificationDetail.fromJson(
        Map<String, dynamic>.from(value),
      );
    });
    return out;
  } catch (_) {
    return {};
  }
}

Future<KeywordNotificationDetail> loadKeywordNotificationDetail(
  String keyword,
) async {
  final Map<String, KeywordNotificationDetail> all =
      await loadAllKeywordNotificationDetails();
  return all[keyword] ?? KeywordNotificationDetail.empty;
}

Future<void> saveKeywordNotificationDetail(
  String keyword,
  KeywordNotificationDetail detail,
) async {
  final String kw = keyword.trim();
  if (kw.isEmpty) return;
  final Map<String, KeywordNotificationDetail> all =
      await loadAllKeywordNotificationDetails();
  all[kw] = detail;
  await _persistAll(all);
}

Future<void> removeKeywordNotificationDetail(String keyword) async {
  final String kw = keyword.trim();
  if (kw.isEmpty) return;
  final Map<String, KeywordNotificationDetail> all =
      await loadAllKeywordNotificationDetails();
  if (!all.containsKey(kw)) return;
  all.remove(kw);
  await _persistAll(all);
}

Future<void> _persistAll(Map<String, KeywordNotificationDetail> all) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final Map<String, dynamic> encoded = all.map(
    (key, value) => MapEntry(key, value.toJson()),
  );
  await prefs.setString(
    kKeywordNotificationDetailsPrefKey,
    jsonEncode(encoded),
  );
}

Map<String, dynamic> keywordNotificationDetailsForCloud(
  Map<String, KeywordNotificationDetail> all,
) {
  return all.map((key, value) => MapEntry(key, value.toJson()));
}

Map<String, KeywordNotificationDetail> keywordNotificationDetailsFromCloud(
  dynamic value,
) {
  if (value is! Map) return {};
  final Map<String, KeywordNotificationDetail> out = {};
  value.forEach((key, raw) {
    final String kw = key.toString().trim();
    if (kw.isEmpty || raw is! Map) return;
    out[kw] = KeywordNotificationDetail.fromJson(
      Map<String, dynamic>.from(raw),
    );
  });
  return out;
}

Future<void> applyKeywordNotificationDetailsFromCloud(
  dynamic value,
) async {
  await _persistAll(keywordNotificationDetailsFromCloud(value));
}

String _normalize(String value) => value.trim().toLowerCase();

/// 키워드 알림 모드에서 이 공지가 해당 키워드로 알림을 받을지 판별합니다.
bool matchesKeywordNotificationRule({
  required String keyword,
  required KeywordNotificationDetail detail,
  required String title,
  required String body,
  required Map<String, dynamic> data,
}) {
  final String kw = keyword.trim();
  if (kw.isEmpty) return false;

  final String searchable = _normalize("$title $body");
  if (!searchable.contains(_normalize(kw))) return false;

  for (final String exclude in detail.excludeKeywords) {
    final String ex = exclude.trim();
    if (ex.isNotEmpty && searchable.contains(_normalize(ex))) {
      return false;
    }
  }

  if (detail.sources.isEmpty) return true;

  final String source = resolveNotificationSource(data);
  return detail.sources.contains(source);
}

/// 등록된 키워드 중 하나라도 알림 조건을 만족하면 true.
Future<bool> shouldShowKeywordNotification({
  required List<String> keywords,
  required String title,
  required String body,
  required Map<String, dynamic> data,
}) async {
  if (keywords.isEmpty) return false;
  final Map<String, KeywordNotificationDetail> details =
      await loadAllKeywordNotificationDetails();
  for (final String kw in keywords) {
    final KeywordNotificationDetail detail =
        details[kw] ?? KeywordNotificationDetail.empty;
    if (matchesKeywordNotificationRule(
      keyword: kw,
      detail: detail,
      title: title,
      body: body,
      data: data,
    )) {
      return true;
    }
  }
  return false;
}
