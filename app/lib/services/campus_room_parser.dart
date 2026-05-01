import "package:mio_notice/services/campus_map_data.dart";

class CampusRoomParser {
  const CampusRoomParser(this.data);

  final CampusMapData data;

  CampusLookupResult resolve(String rawQuery) {
    final String query = rawQuery.trim();
    if (query.isEmpty) {
      return CampusLookupResult.empty();
    }

    final CampusAlias? alias = data.findAlias(query);
    if (alias != null) {
      return CampusLookupResult.alias(alias);
    }

    final RegExpMatch? match =
        RegExp(r"^\s*([가-힣]+)\s*(\d{3,4})\s*$").firstMatch(query);
    if (match == null) {
      return CampusLookupResult.failure(
        query,
        "건물 약칭과 호실을 함께 입력해 주세요. 예: 공512, 사212, 본 512",
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

    final int floor = int.parse(roomCode.substring(0, 1));
    if (floor > building.floors) {
      return CampusLookupResult.failure(
        query,
        "${building.name}은 현재 데이터 기준 ${building.floors}층까지 안내할 수 있습니다.",
        building: building,
      );
    }

    return CampusLookupResult.room(
      query: query,
      building: building,
      floor: floor,
      roomCode: roomCode,
      roomSuffix: roomCode.substring(1),
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
  });

  final String query;
  final CampusBuilding? building;
  final int? floor;
  final String? roomCode;
  final String? roomSuffix;
  final String message;
  final bool isError;
  final bool isEmpty;

  bool get hasBuilding => building != null;

  String get title {
    final CampusBuilding? selected = building;
    if (selected == null) return "검색 안내";
    if (roomCode == null) return selected.name;
    return "${selected.name} $floor층 $roomCode호";
  }

  String get guidance {
    if (message.isNotEmpty) return message;
    final CampusBuilding? selected = building;
    if (selected == null) return "";
    if (roomCode == null) {
      if (floor == null) return "${selected.name} 건물로 이동하세요.";
      return "${selected.name} $floor층으로 이동하세요.";
    }
    return "${selected.name} 건물로 이동한 뒤 $floor층 $roomCode호를 찾으세요.";
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
    );
  }
}
