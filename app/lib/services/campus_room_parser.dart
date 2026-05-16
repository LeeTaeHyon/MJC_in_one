import "package:mjc_in_one/services/campus_map_data.dart";

class CampusRoomParser {
  const CampusRoomParser(this.data);

  final CampusMapData data;

  static final RegExp roomQueryPattern =
      RegExp(r"^\s*([가-힣]+)\s*([Bb]?\d{3,4})\s*$");

  static bool looksLikeRoomQuery(String raw) {
    return roomQueryPattern.hasMatch(raw.trim());
  }

  CampusLookupResult resolve(String rawQuery) {
    final String query = rawQuery.trim();
    if (query.isEmpty) {
      return CampusLookupResult.empty();
    }

    final CampusAlias? alias = data.findAlias(query);
    if (alias != null) {
      return CampusLookupResult.alias(alias);
    }

    final RegExpMatch? match = roomQueryPattern.firstMatch(query);
    if (match == null) {
      return CampusLookupResult.failure(
        query,
        "건물 약칭과 호실을 함께 입력해 주세요. 예: 공512, 사212, 본B102",
      );
    }

    final String prefix = match.group(1)!.trim();
    final String roomCode = match.group(2)!;
    final CampusBuilding? building = data.findBuildingByPrefix(prefix);
    if (building == null) {
      return CampusLookupResult.failure(
        query,
        "'$prefix'에 해당하는 건물을 아직 찾을 수 없습니다.",
      );
    }

    final bool isBasement = roomCode.toLowerCase().startsWith('b');
    final String numericRoomCode = isBasement ? roomCode.substring(1) : roomCode;
    final int floor = int.parse(numericRoomCode.substring(0, 1));
    
    if (isBasement) {
      if (floor > building.basementFloors) {
        return CampusLookupResult.failure(
          query,
          "${building.name}은 현재 데이터 기준 지하 ${building.basementFloors}층까지 안내할 수 있습니다.",
          building: building,
        );
      }
    } else {
      if (floor > building.floors) {
        return CampusLookupResult.failure(
          query,
          "${building.name}은 현재 데이터 기준 지상 ${building.floors}층까지 안내할 수 있습니다.",
          building: building,
        );
      }
    }

    return CampusLookupResult.room(
      query: query,
      building: building,
      floor: isBasement ? -floor : floor,
      roomCode: roomCode,
      roomSuffix: numericRoomCode.substring(1),
    );
  }
}

class CampusLookupResult {
  const CampusLookupResult._({
    required this.query,
    required this.building,
    required this.floor,
    required this.roomCode,
    required this.roomSuffix,
    required this.message,
    required this.isError,
    required this.isEmpty,
    this.facility,
  });

  final String query;
  final CampusBuilding? building;
  final int? floor;
  final String? roomCode;
  final String? roomSuffix;
  final String message;
  final bool isError;
  final bool isEmpty;
  final CampusBuildingFacility? facility;

  bool get hasBuilding => building != null;

  String get title {
    final CampusBuildingFacility? fac = facility;
    final CampusBuilding? selected = building;
    if (fac != null && selected != null) return fac.name;
    if (selected == null) return "검색 안내";
    if (roomCode == null) return selected.name;
    final String floorString = floor! < 0 ? "지하 ${-floor!}" : "$floor";
    return "${selected.name} $floorString층 $roomCode호";
  }

  String get guidance {
    if (message.isNotEmpty) return message;
    final CampusBuildingFacility? fac = facility;
    final CampusBuilding? selected = building;
    if (fac != null && selected != null) {
      final String floorString =
          fac.floor < 0 ? "지하 ${-fac.floor}" : "${fac.floor}";
      final String base = "${selected.name} $floorString층";
      if (fac.note.isNotEmpty) return "$base. ${fac.note}";
      return "$base으로 이동하세요.";
    }
    if (selected == null) return "";
    if (roomCode == null) {
      if (floor == null) return "${selected.name} 건물로 이동하세요.";
      final String floorString = floor! < 0 ? "지하 ${-floor!}" : "$floor";
      return "${selected.name} $floorString층으로 이동하세요.";
    }
    final String floorString = floor! < 0 ? "지하 ${-floor!}" : "$floor";
    return "${selected.name} 건물로 이동한 뒤 $floorString층 $roomCode호를 찾으세요.";
  }

  factory CampusLookupResult.empty() {
    return const CampusLookupResult._(
      query: "",
      building: null,
      floor: null,
      roomCode: null,
      roomSuffix: null,
      message: "",
      isError: false,
      isEmpty: true,
      facility: null,
    );
  }

  factory CampusLookupResult.failure(
    String query,
    String message, {
    CampusBuilding? building,
  }) {
    return CampusLookupResult._(
      query: query,
      building: building,
      floor: null,
      roomCode: null,
      roomSuffix: null,
      message: message,
      isError: true,
      isEmpty: false,
      facility: null,
    );
  }

  factory CampusLookupResult.room({
    required String query,
    required CampusBuilding building,
    required int floor,
    required String roomCode,
    required String roomSuffix,
  }) {
    return CampusLookupResult._(
      query: query,
      building: building,
      floor: floor,
      roomCode: roomCode,
      roomSuffix: roomSuffix,
      message: "",
      isError: false,
      isEmpty: false,
      facility: null,
    );
  }

  factory CampusLookupResult.alias(CampusAlias alias) {
    return CampusLookupResult._(
      query: alias.query,
      building: alias.building,
      floor: alias.floor,
      roomCode: null,
      roomSuffix: null,
      message: alias.message,
      isError: false,
      isEmpty: false,
      facility: null,
    );
  }

  factory CampusLookupResult.facilityPick({
    required String query,
    required CampusBuilding building,
    required CampusBuildingFacility facility,
  }) {
    return CampusLookupResult._(
      query: query,
      building: building,
      floor: facility.floor,
      roomCode: null,
      roomSuffix: null,
      message: "",
      isError: false,
      isEmpty: false,
      facility: facility,
    );
  }
}
