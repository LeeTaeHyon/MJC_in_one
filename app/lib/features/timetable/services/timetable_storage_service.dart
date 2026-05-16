import "package:mjc_in_one/features/timetable/models/timetable_models.dart";
import "package:shared_preferences/shared_preferences.dart";

const String _kEnrolledOfferingsKey = "timetable_enrolled_offerings_json_v1";

/// Persists the user’s selected courses (local only).
abstract final class TimetableStorageService {
  static List<ParsedCourseOffering> _uniqueByOfferingId(
    List<ParsedCourseOffering> list,
  ) {
    final Set<String> seen = <String>{};
    final List<ParsedCourseOffering> out = <ParsedCourseOffering>[];
    for (final ParsedCourseOffering o in list) {
      if (seen.add(o.offeringId)) {
        out.add(o);
      }
    }
    return out;
  }

  static Future<List<ParsedCourseOffering>> loadEnrolled() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_kEnrolledOfferingsKey);
    if (raw == null || raw.isEmpty) return const <ParsedCourseOffering>[];
    try {
      final List<ParsedCourseOffering> list =
          ParsedCourseOffering.decodeOfferingsList(raw);
      final List<ParsedCourseOffering> unique = _uniqueByOfferingId(list);
      if (unique.length != list.length) {
        await prefs.setString(
          _kEnrolledOfferingsKey,
          ParsedCourseOffering.encodeOfferingsList(unique),
        );
      }
      return unique;
    } catch (_) {
      return const <ParsedCourseOffering>[];
    }
  }

  /// Saves [list] with at most one row per [ParsedCourseOffering.offeringId]
  /// (first occurrence kept). Returns how many duplicate rows were dropped.
  static Future<int> saveEnrolled(List<ParsedCourseOffering> list) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<ParsedCourseOffering> unique = _uniqueByOfferingId(list);
    final int removed = list.length - unique.length;
    await prefs.setString(
      _kEnrolledOfferingsKey,
      ParsedCourseOffering.encodeOfferingsList(unique),
    );
    return removed;
  }
}
