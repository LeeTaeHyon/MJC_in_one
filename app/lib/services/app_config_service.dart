import "dart:convert";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:shared_preferences/shared_preferences.dart";

class NoticesUiConfig {
  const NoticesUiConfig({
    required this.boards,
    required this.aiTagChips,
    required this.filterSourceOptions,
    required this.filterTypeOptions,
  });

  final List<Map<String, dynamic>> boards;
  final List<String> aiTagChips;
  final List<String> filterSourceOptions;
  final List<String> filterTypeOptions;
}

class FoodcourtMetaConfig {
  const FoodcourtMetaConfig({
    required this.preferredShopOrder,
    required this.shopEmoji,
  });

  final List<String> preferredShopOrder;
  final Map<String, String> shopEmoji;
}

class AppConfigService {
  static const Duration _ttlLong = Duration(days: 7);
  static const Duration _ttlShort = Duration(days: 1);

  static Future<String?> loadLink(String key) async {
    final Map<String, dynamic>? data =
        await _loadConfigDoc("links", ttl: _ttlLong);
    final Object? v = data?[key];
    final String s = (v ?? "").toString().trim();
    return s.isEmpty ? null : s;
  }

  static Future<NoticesUiConfig?> loadNoticesUi() async {
    final Map<String, dynamic>? data =
        await _loadConfigDoc("notices_ui", ttl: _ttlLong);
    if (data == null) return null;

    final List<Map<String, dynamic>> boards = _asMapList(data["boards"]);
    final List<String> aiTagChips = _asStringList(data["aiTagChips"]);
    final List<String> filterSourceOptions =
        _asStringList(data["filterSourceOptions"]);
    final List<String> filterTypeOptions =
        _asStringList(data["filterTypeOptions"]);

    return NoticesUiConfig(
      boards: boards,
      aiTagChips: aiTagChips,
      filterSourceOptions: filterSourceOptions,
      filterTypeOptions: filterTypeOptions,
    );
  }

  static Future<List<String>?> loadShuttleStops() async {
    final Map<String, dynamic>? data =
        await _loadConfigDoc("shuttle_route", ttl: _ttlShort);
    final List<String> stops = _asStringList(data?["stops"]);
    return stops.isEmpty ? null : stops;
  }

  static Future<FoodcourtMetaConfig?> loadFoodcourtMeta() async {
    final Map<String, dynamic>? data =
        await _loadConfigDoc("foodcourt_meta", ttl: _ttlShort);
    if (data == null) return null;
    final List<String> order = _asStringList(data["preferredShopOrder"]);
    final Map<String, String> emoji = _asStringMap(data["shopEmoji"]);
    return FoodcourtMetaConfig(preferredShopOrder: order, shopEmoji: emoji);
  }

  static Future<Map<String, dynamic>?> _loadConfigDoc(
    String docId, {
    required Duration ttl,
  }) async {
    final String cacheJsonKey = "config_${docId}_json_v1";
    final String cacheAtKey = "config_${docId}_at_ms_v1";

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int cachedAt = prefs.getInt(cacheAtKey) ?? 0;
    if (cachedAt > 0) {
      final int now = DateTime.now().millisecondsSinceEpoch;
      if (now - cachedAt <= ttl.inMilliseconds) {
        final String raw = prefs.getString(cacheJsonKey) ?? "";
        if (raw.trim().isNotEmpty) {
          final Object? decoded = jsonDecode(raw);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        }
      }
    }

    final DocumentSnapshot<Map<String, dynamic>> snap = await FirebaseFirestore
        .instance
        .collection("config")
        .doc(docId)
        .get();
    final Map<String, dynamic>? data = snap.data();
    if (data == null) return null;

    final Map<String, dynamic> copied = Map<String, dynamic>.from(data);
    await prefs.setString(cacheJsonKey, jsonEncode(copied));
    await prefs.setInt(cacheAtKey, DateTime.now().millisecondsSinceEpoch);
    return copied;
  }
}

List<String> _asStringList(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((e) => e.toString().trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

List<Map<String, dynamic>> _asMapList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> out = [];
  for (final item in value) {
    if (item is Map) out.add(Map<String, dynamic>.from(item));
  }
  return out;
}

Map<String, String> _asStringMap(Object? value) {
  if (value is! Map) return const <String, String>{};
  return value.map(
    (k, v) => MapEntry(k.toString().trim(), v.toString()),
  )..removeWhere((k, v) => k.isEmpty || v.trim().isEmpty);
}

