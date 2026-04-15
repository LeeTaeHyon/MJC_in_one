import "dart:convert";

import "package:shared_preferences/shared_preferences.dart";

const String kNotificationHistoryPrefKey = "notification_history";
const String kNotificationReadKeysPrefKey = "notification_history_read_keys";

String notificationHistoryItemKey(Map<String, dynamic> item) {
  final String receivedAt = (item["received_at"] ?? "").toString().trim();
  final String title = (item["title"] ?? "").toString().trim();
  final String body = (item["body"] ?? "").toString().trim();
  final String url = ((item["data"] is Map)
          ? ((item["data"] as Map)["url"] ?? (item["data"] as Map)["link"] ?? "")
          : (item["url"] ?? item["link"] ?? ""))
      .toString()
      .trim();

  // received_at가 가장 안정적인 키(저장 시점에 항상 들어감). 누락되면 title/body/url 조합.
  if (receivedAt.isNotEmpty) {
    return "t=$receivedAt|u=$url|title=$title";
  }
  if (url.isNotEmpty) return "u=$url|title=$title|body=$body";
  return "title=$title|body=$body";
}

/// 파싱에 성공한 항목만, 최신순.
Future<List<Map<String, dynamic>>> loadNotificationHistoryNewestFirst() async {
  final prefs = await SharedPreferences.getInstance();
  final historyStrings = prefs.getStringList(kNotificationHistoryPrefKey) ?? [];
  final out = <Map<String, dynamic>>[];
  for (final s in historyStrings) {
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      if (m.isNotEmpty) out.add(m);
    } catch (_) {}
  }
  return out.reversed.toList();
}

Future<Set<String>> loadNotificationReadKeys() async {
  final prefs = await SharedPreferences.getInstance();
  final list = prefs.getStringList(kNotificationReadKeysPrefKey) ?? [];
  return list.toSet();
}

Future<void> markNotificationHistoryItemRead(Map<String, dynamic> item) async {
  final String key = notificationHistoryItemKey(item);
  if (key.isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  final Set<String> keys = (prefs.getStringList(kNotificationReadKeysPrefKey) ?? []).toSet();
  if (keys.contains(key)) return;
  keys.add(key);
  // 너무 많이 쌓이지 않게 200개까지만 유지
  final List<String> out = keys.toList();
  if (out.length > 200) {
    out.removeRange(0, out.length - 200);
  }
  await prefs.setStringList(kNotificationReadKeysPrefKey, out);
}

/// [newestFirstIndex]: 0이 가장 최근 알림.
Future<void> removeNotificationHistoryAtNewestFirstIndex(int newestFirstIndex) async {
  final prefs = await SharedPreferences.getInstance();
  final historyStrings = List<String>.from(prefs.getStringList(kNotificationHistoryPrefKey) ?? []);

  final validRawIndices = <int>[];
  for (var i = 0; i < historyStrings.length; i++) {
    try {
      final m = jsonDecode(historyStrings[i]) as Map<String, dynamic>;
      if (m.isNotEmpty) validRawIndices.add(i);
    } catch (_) {}
  }
  if (newestFirstIndex < 0 || newestFirstIndex >= validRawIndices.length) return;
  final rawIndex = validRawIndices[validRawIndices.length - 1 - newestFirstIndex];
  historyStrings.removeAt(rawIndex);
  await prefs.setStringList(kNotificationHistoryPrefKey, historyStrings);
}

Future<void> clearNotificationHistory() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(kNotificationHistoryPrefKey);
  await prefs.remove(kNotificationReadKeysPrefKey);
}
