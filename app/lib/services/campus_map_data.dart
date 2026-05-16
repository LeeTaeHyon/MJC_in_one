import "dart:convert";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/services.dart";
import "package:latlong2/latlong.dart";
import "package:shared_preferences/shared_preferences.dart";

class CampusMapData {
  const CampusMapData({
    required this.mapCenter,
    required this.buildings,
    required this.aliases,
  });

  static const String defaultAssetPath = "assets/data/campus_buildings.json";
  static const String _cacheJsonKey = "campus_map_data_json_v1";
  static const String _cacheAtKey = "campus_map_data_cached_at_ms_v1";
  static const Duration _cacheTtl = Duration(days: 7);

  final LatLng mapCenter;
  final List<CampusBuilding> buildings;
  final Map<String, CampusAlias> aliases;

  static Future<CampusMapData> load({
    String assetPath = defaultAssetPath,
  }) async {
    final Map<String, dynamic>? cached = await _tryLoadCache();
    if (cached != null) {
      return _parse(cached);
    }

    try {
      final Map<String, dynamic>? remote = await _loadFromFirestore();
      if (remote != null) {
        await _saveCache(remote);
        return _parse(remote);
      }
    } catch (_) {
      // Fall back to bundled asset.
    }

    return _loadFromAsset(assetPath);
  }

  static Future<CampusMapData> _loadFromAsset(String assetPath) async {
    final String raw = await rootBundle.loadString(assetPath);
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
    return _parse(json);
  }

  static Future<Map<String, dynamic>?> _loadFromFirestore() async {
    final DocumentSnapshot<Map<String, dynamic>> snap = await FirebaseFirestore
        .instance
        .collection("config")
        .doc("campus_map")
        .get();
    final Map<String, dynamic>? data = snap.data();
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  static Future<Map<String, dynamic>?> _tryLoadCache() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int cachedAt = prefs.getInt(_cacheAtKey) ?? 0;
    if (cachedAt <= 0) return null;
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (now - cachedAt > _cacheTtl.inMilliseconds) return null;
    final String raw = prefs.getString(_cacheJsonKey) ?? "";
    if (raw.trim().isEmpty) return null;
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return Map<String, dynamic>.from(decoded);
  }

  static Future<void> _saveCache(Map<String, dynamic> json) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheJsonKey, jsonEncode(json));
    await prefs.setInt(
      _cacheAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static CampusMapData _parse(Map<String, dynamic> json) {

    final List<dynamic> buildingList =
        (json["buildings"] as List<dynamic>? ?? const <dynamic>[]);
    final Map<String, CampusBuilding> buildingsById =
        <String, CampusBuilding>{};
    final List<CampusBuilding> buildings = <CampusBuilding>[
      for (final dynamic item in buildingList)
        CampusBuilding.fromJson(item as Map<String, dynamic>),
    ];
    for (final CampusBuilding building in buildings) {
      buildingsById[building.id] = building;
    }

    final Map<String, dynamic> aliasesJson =
        (json["aliases"] as Map<String, dynamic>? ?? const <String, dynamic>{});

    return CampusMapData(
      mapCenter: _latLngFromJson(
        json["mapCenter"] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      buildings: buildings,
      aliases: aliasesJson.map(
        (String key, dynamic value) => MapEntry<String, CampusAlias>(
          key.trim(),
          CampusAlias.fromJson(
            key,
            value as Map<String, dynamic>,
            buildingsById,
          ),
        ),
      ),
    );
  }

  CampusBuilding? findBuildingById(String id) {
    for (final CampusBuilding building in buildings) {
      if (building.id == id) return building;
    }
    return null;
  }

  CampusBuilding? findBuildingByPrefix(String prefix) {
    final String normalized = prefix.trim();
    if (normalized.isEmpty) return null;

    for (final CampusBuilding building in buildings) {
      if (building.prefixes.contains(normalized)) return building;
    }

    for (final CampusBuilding building in buildings) {
      if (building.name.startsWith(normalized)) return building;
    }

    return null;
  }

  CampusAlias? findAlias(String query) {
    final String normalized = query.trim();
    if (normalized.isEmpty) return null;
    return aliases[normalized];
  }

  List<CampusFacilityMatch> matchFacilities(String rawQuery, {int limit = 20}) {
    final String q = rawQuery.trim();
    if (q.isEmpty) return <CampusFacilityMatch>[];

    final List<CampusFacilityMatch> out = <CampusFacilityMatch>[];
    for (final CampusBuilding b in buildings) {
      for (final CampusBuildingFacility f in b.facilities) {
        if (_campusFacilityMatchesQuery(f, q)) {
          out.add(CampusFacilityMatch(building: b, facility: f));
          if (out.length >= limit) return out;
        }
      }
    }
    return out;
  }
}

class CampusFacilityMatch {
  const CampusFacilityMatch({
    required this.building,
    required this.facility,
  });

  final CampusBuilding building;
  final CampusBuildingFacility facility;
}

/// 단일 위치 시설. [floor]는 지상 양수, 지하는 -1·-2·… (호실 검색과 동일 규칙).
class CampusBuildingFacility {
  const CampusBuildingFacility({
    required this.name,
    required this.floor,
    this.keywords = const <String>[],
    this.note = "",
  });

  final String name;
  final int floor;
  final List<String> keywords;
  final String note;

  factory CampusBuildingFacility.fromJson(Map<String, dynamic> json) {
    return CampusBuildingFacility(
      name: (json["name"] ?? "").toString().trim(),
      floor: _toInt(json["floor"], fallback: 1),
      keywords: [
        for (final dynamic item
            in (json["keywords"] as List<dynamic>? ?? const <dynamic>[]))
          item.toString().trim(),
      ].where((String s) => s.isNotEmpty).toList(),
      note: (json["note"] ?? "").toString(),
    );
  }
}

class CampusBuilding {
  const CampusBuilding({
    required this.id,
    required this.name,
    required this.prefixes,
    required this.floors,
    required this.basementFloors,
    required this.description,
    required this.location,
    this.facilities = const <CampusBuildingFacility>[],
  });

  final String id;
  final String name;
  final List<String> prefixes;
  final int floors;
  final int basementFloors;
  final String description;
  final LatLng location;
  final List<CampusBuildingFacility> facilities;

  factory CampusBuilding.fromJson(Map<String, dynamic> json) {
    return CampusBuilding(
      id: (json["id"] ?? "").toString(),
      name: (json["name"] ?? "").toString(),
      prefixes: [
        for (final dynamic item
            in (json["prefixes"] as List<dynamic>? ?? const <dynamic>[]))
          item.toString().trim(),
      ],
      floors: _toInt(json["floors"], fallback: 1),
      basementFloors: _toInt(json["basementFloors"], fallback: 0),
      description: (json["description"] ?? "").toString(),
      location: _latLngFromJson(json),
      facilities: [
        for (final dynamic item
            in (json["facilities"] as List<dynamic>? ?? const <dynamic>[]))
          if (item is Map)
            CampusBuildingFacility.fromJson(
              Map<String, dynamic>.from(item),
            ),
      ].where((CampusBuildingFacility f) => f.name.isNotEmpty).toList(),
    );
  }
}

class CampusAlias {
  const CampusAlias({
    required this.query,
    required this.building,
    required this.floor,
    required this.message,
  });

  final String query;
  final CampusBuilding building;
  final int? floor;
  final String message;

  factory CampusAlias.fromJson(
    String query,
    Map<String, dynamic> json,
    Map<String, CampusBuilding> buildingsById,
  ) {
    final String buildingId = (json["buildingId"] ?? "").toString();
    final CampusBuilding? building = buildingsById[buildingId];
    if (building == null) {
      throw FormatException("Unknown campus building id: $buildingId");
    }

    return CampusAlias(
      query: query,
      building: building,
      floor: json["floor"] == null ? null : _toInt(json["floor"]),
      message: (json["message"] ?? "").toString(),
    );
  }
}

LatLng _latLngFromJson(Map<String, dynamic> json) {
  return LatLng(_toDouble(json["lat"]), _toDouble(json["lng"]));
}

double _toDouble(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int _toInt(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

String _compactSearchWhitespace(String s) => s.replaceAll(RegExp(r"\s+"), "");

bool _campusFacilityTextMatches(String haystack, String needle) {
  if (needle.isEmpty) return false;
  if (haystack.contains(needle)) return true;
  final String n = needle.toLowerCase();
  if (haystack.toLowerCase().contains(n)) return true;
  final String hc = _compactSearchWhitespace(haystack);
  final String nc = _compactSearchWhitespace(needle);
  if (nc.isEmpty) return false;
  if (hc.contains(nc)) return true;
  return hc.toLowerCase().contains(nc.toLowerCase());
}

bool _campusFacilityMatchesQuery(CampusBuildingFacility f, String q) {
  if (_campusFacilityTextMatches(f.name, q)) return true;
  if (f.note.isNotEmpty && _campusFacilityTextMatches(f.note, q)) return true;
  for (final String k in f.keywords) {
    if (_campusFacilityTextMatches(k, q)) return true;
  }
  return false;
}
