import "package:shared_preferences/shared_preferences.dart";

const String kNoticeFilterEnabledPrefKey = "feed_filter_enabled";
const String kNoticeFilterRequireKeywordPrefKey = "feed_filter_require_kw";
const String kNoticeFilterSourcesPrefKey = "feed_filter_sources";
const String kNoticeFilterTypesPrefKey = "feed_filter_types";
const String kNoticeFilterExcludesPrefKey = "feed_filter_excludes";
const String kNoticeFilterIncludesPrefKey = "feed_filter_includes";
const String kNoticeKeywordsPrefKey = "keywords";

const List<String> kNoticeFilterSourceOptions = ["MJC", "CTL", "MPU"];
const List<String> kNoticeFilterTypeOptions = [
  "공지사항",
  "학사공지",
  "장학공지",
  "역량관리",
  "학습공지",
  "CTL 프로그램",
  "학사일정",
];

class NoticeFilterState {
  const NoticeFilterState({
    this.enabled = false,
    this.requireKeywordHit = false,
    this.sources = kNoticeFilterSourceOptions,
    this.types = kNoticeFilterTypeOptions,
    this.excludes = const [],
    this.includes = const [],
    this.quickQuery = "",
  });

  final bool enabled;
  final bool requireKeywordHit;
  final List<String> sources;
  final List<String> types;
  final List<String> excludes;
  /// 화면 필터 전용. 비어 있지 않으면 제목·본문 등에 **하나라도** 포함된 공지만 표시.
  final List<String> includes;
  final String quickQuery;

  NoticeFilterState copyWith({
    bool? enabled,
    bool? requireKeywordHit,
    List<String>? sources,
    List<String>? types,
    List<String>? excludes,
    List<String>? includes,
    String? quickQuery,
  }) {
    return NoticeFilterState(
      enabled: enabled ?? this.enabled,
      requireKeywordHit: requireKeywordHit ?? this.requireKeywordHit,
      sources: sources ?? this.sources,
      types: types ?? this.types,
      excludes: excludes ?? this.excludes,
      includes: includes ?? this.includes,
      quickQuery: quickQuery ?? this.quickQuery,
    );
  }

  bool get hasPersistentRules {
    return enabled ||
        requireKeywordHit ||
        sources.length != kNoticeFilterSourceOptions.length ||
        types.length != kNoticeFilterTypeOptions.length ||
        excludes.isNotEmpty ||
        includes.isNotEmpty;
  }

  bool get hasAnyRule => hasPersistentRules || quickQuery.trim().isNotEmpty;

  static Future<NoticeFilterState> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> storedSources =
        prefs.getStringList(kNoticeFilterSourcesPrefKey) ??
            kNoticeFilterSourceOptions;
    final List<String> storedTypes =
        prefs.getStringList(kNoticeFilterTypesPrefKey) ??
            kNoticeFilterTypeOptions;
    return NoticeFilterState(
      enabled: prefs.getBool(kNoticeFilterEnabledPrefKey) ?? false,
      requireKeywordHit:
          prefs.getBool(kNoticeFilterRequireKeywordPrefKey) ?? false,
      sources: kNoticeFilterSourceOptions
          .where((source) => storedSources.contains(source))
          .toList(),
      types: kNoticeFilterTypeOptions
          .where((type) => storedTypes.contains(type))
          .toList(),
      excludes: prefs.getStringList(kNoticeFilterExcludesPrefKey) ?? const [],
      includes: prefs.getStringList(kNoticeFilterIncludesPrefKey) ?? const [],
    )._ensureNonEmptyDefaults();
  }

  Future<void> save() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kNoticeFilterEnabledPrefKey, enabled);
    await prefs.setBool(
      kNoticeFilterRequireKeywordPrefKey,
      requireKeywordHit,
    );
    await prefs.setStringList(kNoticeFilterSourcesPrefKey, sources);
    await prefs.setStringList(kNoticeFilterTypesPrefKey, types);
    await prefs.setStringList(kNoticeFilterExcludesPrefKey, excludes);
    await prefs.setStringList(kNoticeFilterIncludesPrefKey, includes);
  }

  List<Map<String, dynamic>> apply(
    Iterable<Map<String, dynamic>> items, {
    required List<String> sharedKeywords,
    String fallbackSource = "",
    String fallbackType = "",
  }) {
    final String query = _normalize(quickQuery);
    final List<String> normalizedIncludes =
        sharedKeywords.map(_normalize).where((s) => s.isNotEmpty).toList();
    final List<String> normalizedExcludes =
        excludes.map(_normalize).where((s) => s.isNotEmpty).toList();
    final List<String> normalizedIncludesOnly =
        includes.map(_normalize).where((s) => s.isNotEmpty).toList();

    return items.where((Map<String, dynamic> item) {
      final String searchable = _normalize(_searchableText(item));
      if (query.isNotEmpty && !searchable.contains(query)) return false;

      if (!enabled) return true;

      final String source = _normalizedSource(item, fallbackSource);
      final String type = _normalizedType(item, fallbackType);
      if (!sources.contains(source)) return false;
      if (!types.contains(type)) return false;
      if (normalizedExcludes.any(searchable.contains)) return false;
      if (normalizedIncludesOnly.isNotEmpty &&
          !normalizedIncludesOnly.any(searchable.contains)) {
        return false;
      }
      if (requireKeywordHit &&
          (normalizedIncludes.isEmpty ||
              !normalizedIncludes.any(searchable.contains))) {
        return false;
      }
      return true;
    }).toList();
  }

  NoticeFilterState _ensureNonEmptyDefaults() {
    return copyWith(
      sources: sources.isEmpty ? kNoticeFilterSourceOptions : sources,
      types: types.isEmpty ? kNoticeFilterTypeOptions : types,
    );
  }
}

Future<List<String>> loadSharedNoticeKeywords() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(kNoticeKeywordsPrefKey) ?? const [];
}

String _normalize(String value) => value.trim().toLowerCase();

String _aiTagsSearchText(Map<String, dynamic> item) {
  final Object? v = item["ai_tags"];
  if (v is! List) return "";
  return v.map((e) => e.toString()).join(" ");
}

String _searchableText(Map<String, dynamic> item) {
  return [
    item["title"],
    item["body"],
    item["category"],
    item["type"],
    item["branch"],
    item["status"],
    item["op_period"],
    _aiTagsSearchText(item),
  ].whereType<Object>().map((v) => v.toString()).join(" ");
}

String _normalizedSource(Map<String, dynamic> item, String fallbackSource) {
  final String raw = (item["source"] ?? fallbackSource).toString().trim();
  if (raw == "MJC" || raw == "main_schedule" || raw.startsWith("main_")) {
    return "MJC";
  }
  if (raw == "CTL" || raw.startsWith("ctl")) return "CTL";
  if (raw == "MPU" || raw.startsWith("mpu")) return "MPU";
  return fallbackSource.isEmpty ? "MJC" : fallbackSource;
}

String _normalizedType(Map<String, dynamic> item, String fallbackType) {
  final String raw =
      (item["type"] ?? item["category"] ?? fallbackType).toString().trim();
  if (raw.isEmpty) return fallbackType.isEmpty ? "공지사항" : fallbackType;
  if (raw.contains("장학")) return "장학공지";
  if (raw.contains("학사일정")) return "학사일정";
  if (raw.contains("학사")) return "학사공지";
  if (raw.contains("역량")) return "역량관리";
  if (raw.contains("CTL") && raw.contains("프로그램")) return "CTL 프로그램";
  if (raw.contains("학습")) return "학습공지";
  if (raw.contains("공지")) return "공지사항";
  return fallbackType.isEmpty ? raw : fallbackType;
}
