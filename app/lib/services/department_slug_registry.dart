import "dart:convert";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/services.dart";

/// 학과 표시명 ↔ Firestore `deptSlug` 매핑.
class DepartmentSlugRegistry {
  DepartmentSlugRegistry({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  Map<String, String>? _byDisplayName;
  bool _loading = false;

  Future<void> ensureLoaded() async {
    if (_byDisplayName != null || _loading) return;
    _loading = true;
    try {
      final Map<String, String>? remote = await _loadFromFirestore();
      if (remote != null && remote.isNotEmpty) {
        _byDisplayName = remote;
        return;
      }
    } catch (_) {
      // Fall back to asset.
    }
    _byDisplayName = await _loadFromAsset();
  }

  Future<String?> slugForDisplayName(String displayName) async {
    await ensureLoaded();
    final String key = displayName.trim();
    if (key.isEmpty) return null;
    return _byDisplayName?[key];
  }

  Future<Map<String, String>> allMappings() async {
    await ensureLoaded();
    return Map<String, String>.from(_byDisplayName ?? const {});
  }

  Future<Map<String, String>?> _loadFromFirestore() async {
    final DocumentSnapshot<Map<String, dynamic>> snap =
        await _firestore.collection("config").doc("department_slugs").get();
    final Map<String, dynamic>? data = snap.data();
    final Object? raw = data?["by_display_name"];
    if (raw is! Map) return null;
    return raw.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }

  Future<Map<String, String>> _loadFromAsset() async {
    try {
      final String raw =
          await rootBundle.loadString("assets/data/department_slugs.json");
      final Map<String, dynamic> data = jsonDecode(raw) as Map<String, dynamic>;
      final Object? rawMap = data["by_display_name"];
      if (rawMap is! Map) return {};
      return rawMap.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return {};
    }
  }
}
