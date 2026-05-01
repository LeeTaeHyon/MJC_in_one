import "dart:convert";

import "package:flutter/services.dart";
import "package:latlong2/latlong.dart";

class CampusMapData {
  const CampusMapData({
    required this.mapCenter,
    required this.buildings,
    required this.aliases,
  });

  static const String defaultAssetPath = "assets/data/campus_buildings.json";

  final LatLng mapCenter;
  final List<CampusBuilding> buildings;
  final Map<String, CampusAlias> aliases;

  static Future<CampusMapData> load({
    String assetPath = defaultAssetPath,
  }) async {
    final String raw = await rootBundle.loadString(assetPath);
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;

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
}

class CampusBuilding {
  const CampusBuilding({
    required this.id,
    required this.name,
    required this.prefixes,
    required this.floors,
    required this.description,
    required this.location,
  });

  final String id;
  final String name;
  final List<String> prefixes;
  final int floors;
  final String description;
  final LatLng location;

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
      description: (json["description"] ?? "").toString(),
      location: _latLngFromJson(json),
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
