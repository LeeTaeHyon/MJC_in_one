import "dart:convert";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/services.dart";
import "package:shared_preferences/shared_preferences.dart";

/// 학과 표시명 목록 — [ProfileForm]과 동일 소스(캐시 → Firestore → asset).
class DepartmentsListService {
  DepartmentsListService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String cacheJsonKey = "departments_config_json_v1";
  static const String cacheAtKey = "departments_config_cached_at_ms_v1";
  static const Duration cacheTtl = Duration(days: 7);

  final FirebaseFirestore _firestore;

  Future<List<String>> loadSortedDepartments() async {
    final List<String>? cached = await _tryLoadCache();
    if (cached != null && cached.isNotEmpty) {
      return _dedupeSorted(cached);
    }

    try {
      final List<String>? remote = await _loadFromFirestore();
      if (remote != null && remote.isNotEmpty) {
        await _saveCache(remote);
        return _dedupeSorted(remote);
      }
    } catch (_) {
      // Fall back to asset.
    }

    return _dedupeSorted(await _loadFromAsset());
  }

  List<String> _dedupeSorted(List<String> departments) {
    final List<String> unique = <String>[];
    final Set<String> seen = <String>{};
    for (final String name in departments) {
      final String trimmed = name.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) continue;
      unique.add(trimmed);
    }
    unique.sort();
    return unique;
  }

  Future<List<String>?> _tryLoadCache() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int cachedAt = prefs.getInt(cacheAtKey) ?? 0;
    if (cachedAt <= 0) return null;
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (now - cachedAt > cacheTtl.inMilliseconds) return null;
    final String raw = prefs.getString(cacheJsonKey) ?? "";
    if (raw.trim().isEmpty) return null;
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List) return null;
    final List<String> list = decoded
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
    list.sort();
    return list;
  }

  Future<void> _saveCache(List<String> departments) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(cacheJsonKey, jsonEncode(departments));
    await prefs.setInt(cacheAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<List<String>?> _loadFromFirestore() async {
    final DocumentSnapshot<Map<String, dynamic>> snap =
        await _firestore.collection("config").doc("departments").get();
    final Map<String, dynamic>? data = snap.data();
    final Object? raw = data?["departments"];
    if (raw is! List) return null;
    final List<String> list = raw
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
    list.sort();
    return list;
  }

  Future<List<String>> _loadFromAsset() async {
    try {
      final String raw =
          await rootBundle.loadString("assets/data/mjc_departments.json");
      final Map<String, dynamic> data = jsonDecode(raw) as Map<String, dynamic>;
      final List<String> departments = (data["departments"] as List<dynamic>)
          .map((dynamic value) => value.toString().trim())
          .where((String value) => value.isNotEmpty)
          .toList();
      departments.sort();
      return departments;
    } catch (_) {
      return const <String>[];
    }
  }
}
