import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

const String kThemeModePrefKey = "themeMode";

String _encodeThemeMode(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return "light";
    case ThemeMode.dark:
      return "dark";
    case ThemeMode.system:
      return "system";
  }
}

ThemeMode _decodeThemeMode(String? raw) {
  switch (raw) {
    case "light":
      return ThemeMode.light;
    case "dark":
      return ThemeMode.dark;
    case "system":
    default:
      return ThemeMode.system;
  }
}

class ThemeModeController extends ValueNotifier<ThemeMode> {
  ThemeModeController(super.value);

  static Future<ThemeModeController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kThemeModePrefKey);
    return ThemeModeController(_decodeThemeMode(raw));
  }

  Future<void> setAndPersist(ThemeMode mode) async {
    if (value == mode) return;
    value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kThemeModePrefKey, _encodeThemeMode(mode));
  }
}

class ThemeModeScope extends InheritedNotifier<ThemeModeController> {
  const ThemeModeScope({
    super.key,
    required ThemeModeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeModeController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ThemeModeScope>()
        ?.notifier;
  }

  static ThemeModeController of(BuildContext context) {
    final c = maybeOf(context);
    assert(c != null, "ThemeModeScope not found in widget tree.");
    return c!;
  }
}
