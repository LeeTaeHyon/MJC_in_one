import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";

const String kMainWebsiteNoticeViewModePrefKey = "mainWebsiteNoticeViewMode";

enum MainWebsiteNoticeViewMode {
  tabs,
  unified,
}

String _encode(MainWebsiteNoticeViewMode mode) => mode.name;

MainWebsiteNoticeViewMode _decode(String? raw) {
  switch ((raw ?? "").trim()) {
    case "tabs":
      return MainWebsiteNoticeViewMode.tabs;
    case "unified":
      return MainWebsiteNoticeViewMode.unified;
    default:
      // 기본값: 통합 보기
      return MainWebsiteNoticeViewMode.unified;
  }
}

class MainWebsitePrefs {
  MainWebsitePrefs._();

  static final ValueNotifier<MainWebsiteNoticeViewMode> noticeViewMode =
      ValueNotifier<MainWebsiteNoticeViewMode>(MainWebsiteNoticeViewMode.unified);

  static bool _loaded = false;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    noticeViewMode.value = _decode(prefs.getString(kMainWebsiteNoticeViewModePrefKey));
    _loaded = true;
  }

  static Future<void> setNoticeViewMode(MainWebsiteNoticeViewMode mode) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(kMainWebsiteNoticeViewModePrefKey, _encode(mode));
    noticeViewMode.value = mode;
  }
}

