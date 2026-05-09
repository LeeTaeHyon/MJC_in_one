import "package:flutter_test/flutter_test.dart";
import "package:mio_notice/services/campus_map_data.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("campus_buildings.json loads facilities; CU matches", () async {
    final CampusMapData data = await CampusMapData.load();
    int total = 0;
    for (final CampusBuilding b in data.buildings) {
      total += b.facilities.length;
    }
    expect(total, greaterThan(0));
    final List<CampusFacilityMatch> cu = data.matchFacilities("CU");
    expect(cu, isNotEmpty);
    expect(cu.first.facility.name, contains("CU"));
  });
}
