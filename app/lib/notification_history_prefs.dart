import "dart:convert";

import "package:shared_preferences/shared_preferences.dart";

const String kNotificationHistoryPrefKey = "notification_history";

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
}
