import "dart:convert";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:cp949_codec/cp949_codec.dart";
import "package:flutter/services.dart";
import "package:shared_preferences/shared_preferences.dart";

class FoodcourtMenuItem {
  const FoodcourtMenuItem({
    required this.shop,
    required this.menu,
    required this.price,
  });

  final String shop;
  final String menu;
  final int price;

  String get formattedPrice => "${price.toString()}원";
}

class FoodcourtMenuService {
  static const String assetPath = "assets/data/foodcourt.csv";

  static const String _cacheJsonKey = "foodcourt_menu_rows_json_v1";
  static const String _cacheAtKey = "foodcourt_menu_cached_at_ms_v1";
  static const Duration _cacheTtl = Duration(days: 1);

  Future<List<FoodcourtMenuItem>> load() async {
    final List<Map<String, dynamic>>? cached = await _tryLoadCache();
    if (cached != null) {
      final List<FoodcourtMenuItem> parsed = _parseRows(cached);
      if (parsed.isNotEmpty) return parsed;
    }

    try {
      final List<Map<String, dynamic>> remote = await _loadFromFirestore();
      if (remote.isNotEmpty) {
        await _saveCache(remote);
        final List<FoodcourtMenuItem> parsed = _parseRows(remote);
        if (parsed.isNotEmpty) return parsed;
      }
    } catch (_) {
      // Fall back to asset.
    }

    return loadFromAsset();
  }

  Future<List<FoodcourtMenuItem>> loadFromAsset() async {
    final ByteData data = await rootBundle.load(assetPath);
    final Uint8List bytes = data.buffer.asUint8List();
    final String raw = _decodeText(bytes);
    final List<String> lines = raw
        .split(RegExp(r"\r?\n"))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length <= 1) return const [];

    final List<String> headers = _splitCsvLine(lines.first)
        .map((value) => value.trim().toLowerCase())
        .toList();
    final List<FoodcourtMenuItem> rows = [];
    for (final String line in lines.skip(1)) {
      final Map<String, String> row = _rowMap(headers, _splitCsvLine(line));
      final String shop = (row["shop"] ?? "").trim();
      final String menu = (row["menu"] ?? "").trim();
      final int? price = int.tryParse((row["price"] ?? "").trim());
      if (shop.isEmpty || menu.isEmpty || price == null) continue;
      rows.add(FoodcourtMenuItem(shop: shop, menu: menu, price: price));
    }
    return rows;
  }

  Future<List<Map<String, dynamic>>> _loadFromFirestore() async {
    final QuerySnapshot<Map<String, dynamic>> snap =
        await FirebaseFirestore.instance.collection("foodcourt_menu").get();
    return [
      for (final d in snap.docs)
        if (d.data().isNotEmpty) Map<String, dynamic>.from(d.data()),
    ];
  }

  List<FoodcourtMenuItem> _parseRows(List<Map<String, dynamic>> rows) {
    final List<FoodcourtMenuItem> out = [];
    for (final Map<String, dynamic> row in rows) {
      final String shop = (row["shop"] ?? "").toString().trim();
      final String menu = (row["menu"] ?? "").toString().trim();
      final int? price = _toInt(row["price"]);
      if (shop.isEmpty || menu.isEmpty || price == null) continue;
      out.add(FoodcourtMenuItem(shop: shop, menu: menu, price: price));
    }
    return out;
  }

  Future<List<Map<String, dynamic>>?> _tryLoadCache() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int cachedAt = prefs.getInt(_cacheAtKey) ?? 0;
    if (cachedAt <= 0) return null;
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (now - cachedAt > _cacheTtl.inMilliseconds) return null;
    final String raw = prefs.getString(_cacheJsonKey) ?? "";
    if (raw.trim().isEmpty) return null;
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List) return null;
    final List<Map<String, dynamic>> out = [];
    for (final item in decoded) {
      if (item is Map) out.add(Map<String, dynamic>.from(item));
    }
    return out;
  }

  Future<void> _saveCache(List<Map<String, dynamic>> rows) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheJsonKey, jsonEncode(rows));
    await prefs.setInt(_cacheAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  Map<String, List<FoodcourtMenuItem>> groupByShop(
    List<FoodcourtMenuItem> items,
  ) {
    final Map<String, List<FoodcourtMenuItem>> grouped = {};
    for (final FoodcourtMenuItem item in items) {
      grouped.putIfAbsent(item.shop, () => []).add(item);
    }
    return grouped;
  }

  String _decodeText(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return cp949.decode(bytes);
    }
  }

  Map<String, String> _rowMap(List<String> headers, List<String> values) {
    final Map<String, String> result = {};
    for (int i = 0; i < headers.length; i++) {
      result[headers[i]] = i < values.length ? values[i].trim() : "";
    }
    return result;
  }

  List<String> _splitCsvLine(String line) {
    final List<String> values = [];
    final StringBuffer current = StringBuffer();
    bool quoted = false;
    for (int i = 0; i < line.length; i++) {
      final String char = line[i];
      if (char == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (char == "," && !quoted) {
        values.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    values.add(current.toString());
    return values;
  }
}

int? _toInt(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim());
}
