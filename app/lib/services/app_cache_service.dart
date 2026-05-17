import "package:flutter/painting.dart";
import "package:mjc_in_one/services/notice_manager.dart";
import "package:shared_preferences/shared_preferences.dart";

/// 앱에서 다시 받을 수 있는 임시·캐시 데이터만 관리합니다.
/// 알림 설정, 북마크, 시간표, 프로필 등 사용자 데이터는 건드리지 않습니다.
class AppCacheService {
  AppCacheService._();

  static const List<String> _configDocIds = <String>[
    "links",
    "notices_ui",
    "shuttle_route",
    "foodcourt_meta",
  ];

  static const List<String> _prefKeys = <String>[
    "timetable_official_catalog_json_v1",
    "timetable_official_cached_at_ms_v1",
    "campus_map_data_json_v1",
    "campus_map_data_cached_at_ms_v1",
    "shuttle_schedule_rows_json_v1",
    "shuttle_schedule_cached_at_ms_v1",
    "foodcourt_menu_rows_json_v1",
    "foodcourt_menu_cached_at_ms_v1",
    "departments_config_json_v1",
    "departments_config_cached_at_ms_v1",
  ];

  static List<String> get _allPrefKeys {
    final List<String> keys = List<String>.from(_prefKeys);
    for (final String docId in _configDocIds) {
      keys.add("config_${docId}_json_v1");
      keys.add("config_${docId}_at_ms_v1");
    }
    return keys;
  }

  /// 저장된 캐시 prefs 항목의 대략적인 크기(문자열 길이 합)를 반환합니다.
  static Future<int> estimateCacheBytes() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    int total = 0;
    for (final String key in _allPrefKeys) {
      final String? raw = prefs.getString(key);
      if (raw != null) total += raw.length;
    }
    return total;
  }

  static String formatCacheSize(int bytes) {
    if (bytes <= 0) return "0 B";
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) {
      return "${(bytes / 1024).toStringAsFixed(1)} KB";
    }
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  static Future<void> clearAppCache() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    for (final String key in _allPrefKeys) {
      await prefs.remove(key);
    }
    NoticeManager().clearCache();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }
}
