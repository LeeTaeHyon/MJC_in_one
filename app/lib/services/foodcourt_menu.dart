import "dart:convert";

import "package:cp949_codec/cp949_codec.dart";
import "package:flutter/services.dart";

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
