import "dart:convert";
import "dart:math" as math;

import "package:flutter/services.dart";

class CampusMapData {
  const CampusMapData({
    required this.imageAsset,
    required this.imageSize,
    required this.buildings,
    required this.aliases,
    required this.calibration,
  });

  static const String defaultAssetPath = "assets/data/campus_buildings.json";

  final String imageAsset;
  final Size imageSize;
  final List<CampusBuilding> buildings;
  final Map<String, CampusAlias> aliases;
  final GeoCalibration calibration;

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
      imageAsset:
          (json["imageAsset"] ?? "assets/images/campus_map.png").toString(),
      imageSize: Size(
        _toDouble(json["imageWidth"], fallback: 1200),
        _toDouble(json["imageHeight"], fallback: 900),
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
      calibration: GeoCalibration.fromJson(
        json["calibration"] as Map<String, dynamic>? ??
            const <String, dynamic>{},
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
    required this.labelAnchor,
    required this.polygon,
  });

  final String id;
  final String name;
  final List<String> prefixes;
  final int floors;
  final String description;
  final Offset labelAnchor;
  final List<Offset> polygon;

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
      labelAnchor: _offsetFromJson(
        json["labelAnchor"] as Map<String, dynamic>? ??
            const <String, dynamic>{},
      ),
      polygon: [
        for (final dynamic item
            in (json["polygon"] as List<dynamic>? ?? const <dynamic>[]))
          _offsetFromJson(item as Map<String, dynamic>),
      ],
    );
  }

  Offset get center {
    if (polygon.isEmpty) return labelAnchor;
    double x = 0;
    double y = 0;
    for (final Offset point in polygon) {
      x += point.dx;
      y += point.dy;
    }
    return Offset(x / polygon.length, y / polygon.length);
  }

  bool contains(Offset point) {
    if (polygon.length < 3) return false;

    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final Offset pi = polygon[i];
      final Offset pj = polygon[j];
      final bool intersects = ((pi.dy > point.dy) != (pj.dy > point.dy)) &&
          (point.dx <
              (pj.dx - pi.dx) *
                      (point.dy - pi.dy) /
                      ((pj.dy - pi.dy) == 0 ? 0.0001 : (pj.dy - pi.dy)) +
                  pi.dx);
      if (intersects) inside = !inside;
    }
    return inside;
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

class GeoCalibration {
  const GeoCalibration({required this.points});

  final List<GeoCalibrationPoint> points;

  bool get isReady => points.length >= 2;

  factory GeoCalibration.fromJson(Map<String, dynamic> json) {
    return GeoCalibration(
      points: [
        for (final dynamic item
            in (json["points"] as List<dynamic>? ?? const <dynamic>[]))
          GeoCalibrationPoint.fromJson(item as Map<String, dynamic>),
      ],
    );
  }

  Offset? latLngToPixel(double lat, double lng) {
    if (!isReady) return null;

    final GeoCalibrationPoint origin = points.first;
    final GeoCalibrationPoint target = _farthestPointFrom(origin);
    final Offset geoTarget = _latLngToMeters(
      target.lat,
      target.lng,
      originLat: origin.lat,
      originLng: origin.lng,
    );

    final double geoLen2 =
        geoTarget.dx * geoTarget.dx + geoTarget.dy * geoTarget.dy;
    if (geoLen2 == 0) return null;

    final Offset pixelTarget = Offset(
        target.pixel.dx - origin.pixel.dx, target.pixel.dy - origin.pixel.dy);

    final double a =
        (pixelTarget.dx * geoTarget.dx + pixelTarget.dy * geoTarget.dy) /
            geoLen2;
    final double b =
        (pixelTarget.dy * geoTarget.dx - pixelTarget.dx * geoTarget.dy) /
            geoLen2;

    final Offset geo = _latLngToMeters(
      lat,
      lng,
      originLat: origin.lat,
      originLng: origin.lng,
    );

    return Offset(
      origin.pixel.dx + a * geo.dx - b * geo.dy,
      origin.pixel.dy + b * geo.dx + a * geo.dy,
    );
  }

  GeoCalibrationPoint _farthestPointFrom(GeoCalibrationPoint origin) {
    GeoCalibrationPoint farthest = points[1];
    double farthestDistance = -1;
    for (final GeoCalibrationPoint point in points.skip(1)) {
      final Offset meters = _latLngToMeters(
        point.lat,
        point.lng,
        originLat: origin.lat,
        originLng: origin.lng,
      );
      final double distance = meters.distanceSquared;
      if (distance > farthestDistance) {
        farthest = point;
        farthestDistance = distance;
      }
    }
    return farthest;
  }

  Offset _latLngToMeters(
    double lat,
    double lng, {
    required double originLat,
    required double originLng,
  }) {
    final double latMeters = (lat - originLat) * 110540;
    final double lngMeters =
        (lng - originLng) * 111320 * math.cos(originLat * math.pi / 180);
    return Offset(lngMeters, latMeters);
  }
}

class GeoCalibrationPoint {
  const GeoCalibrationPoint({
    required this.label,
    required this.lat,
    required this.lng,
    required this.pixel,
  });

  final String label;
  final double lat;
  final double lng;
  final Offset pixel;

  factory GeoCalibrationPoint.fromJson(Map<String, dynamic> json) {
    return GeoCalibrationPoint(
      label: (json["label"] ?? "").toString(),
      lat: _toDouble(json["lat"]),
      lng: _toDouble(json["lng"]),
      pixel: Offset(
        _toDouble(json["px"]),
        _toDouble(json["py"]),
      ),
    );
  }
}

Offset _offsetFromJson(Map<String, dynamic> json) {
  return Offset(_toDouble(json["x"]), _toDouble(json["y"]));
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
