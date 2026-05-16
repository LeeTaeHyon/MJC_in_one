import "package:cloud_firestore/cloud_firestore.dart";
import "package:mjc_in_one/features/timetable/models/timetable_models.dart";
import "package:shared_preferences/shared_preferences.dart";

class TimetableOfficialCatalogService {
  static const String _cacheJsonKey = "timetable_official_catalog_json_v1";
  static const String _cacheAtKey = "timetable_official_cached_at_ms_v1";
  static const Duration _cacheTtl = Duration(days: 7);

  Future<List<ParsedCourseOffering>> load() async {
    final List<ParsedCourseOffering>? cached = await _tryLoadCache();
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final List<ParsedCourseOffering> remote = await _loadFromFirestore();
      if (remote.isNotEmpty) {
        await _saveCache(remote);
        return remote;
      }
    } catch (_) {
      // fall through
    }

    return const <ParsedCourseOffering>[];
  }

  Future<List<ParsedCourseOffering>> _loadFromFirestore() async {
    final QuerySnapshot<Map<String, dynamic>> snap = await FirebaseFirestore
        .instance
        .collection("timetable_official")
        .get();
    final List<ParsedCourseOffering> out = [];
    for (final d in snap.docs) {
      final Map<String, dynamic> data = d.data();
      if (data.isEmpty) continue;
      out.add(ParsedCourseOffering.fromJson(data));
    }
    return out;
  }

  Future<List<ParsedCourseOffering>?> _tryLoadCache() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int cachedAt = prefs.getInt(_cacheAtKey) ?? 0;
    if (cachedAt <= 0) return null;
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (now - cachedAt > _cacheTtl.inMilliseconds) return null;

    final String raw = prefs.getString(_cacheJsonKey) ?? "";
    if (raw.trim().isEmpty) return null;
    try {
      return ParsedCourseOffering.decodeOfferingsList(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCache(List<ParsedCourseOffering> list) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheJsonKey, ParsedCourseOffering.encodeOfferingsList(list));
    await prefs.setInt(_cacheAtKey, DateTime.now().millisecondsSinceEpoch);
  }
}

