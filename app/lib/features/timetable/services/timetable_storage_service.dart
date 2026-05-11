import "package:mio_notice/features/timetable/models/timetable_models.dart";
import "package:shared_preferences/shared_preferences.dart";

const String _kEnrolledOfferingsKey = "timetable_enrolled_offerings_json_v1";

/// Persists the user’s selected courses (local only).
abstract final class TimetableStorageService {
  static Future<List<ParsedCourseOffering>> loadEnrolled() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_kEnrolledOfferingsKey);
    if (raw == null || raw.isEmpty) return const <ParsedCourseOffering>[];
    try {
      return ParsedCourseOffering.decodeOfferingsList(raw);
    } catch (_) {
      return const <ParsedCourseOffering>[];
    }
  }

  static Future<void> saveEnrolled(List<ParsedCourseOffering> list) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kEnrolledOfferingsKey,
      ParsedCourseOffering.encodeOfferingsList(list),
    );
  }
}
