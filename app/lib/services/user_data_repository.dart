import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:mio_notice/home_dashboard_prefs.dart";
import "package:mio_notice/mpu_profile_prefs.dart";
import "package:mio_notice/notification_sources.dart";
import "package:mio_notice/services/notice_filter.dart";
import "package:shared_preferences/shared_preferences.dart";

const String _pinnedPrefix = "pinned_notices_";
const String _favoritePrefix = "favorite_notices_";
const String _allNoticesEnabledKey = "allNoticesEnabled";
const String _keywordNoticesEnabledKey = "keywordNoticesEnabled";

class UserDataRepository {
  UserDataRepository._({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static final UserDataRepository instance = UserDataRepository._();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _userDoc(User user) {
    return _firestore.collection("users").doc(user.uid);
  }

  Future<void> hydrateFromCloudOnLogin(User user) async {
    final DocumentReference<Map<String, dynamic>> ref = _userDoc(user);
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await ref.get();

    if (!snapshot.exists) {
      await pushSnapshotToCloud(userOverride: user, includeCreatedAt: true);
      return;
    }

    final Map<String, dynamic> data = snapshot.data() ?? {};
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await _setStringList(
      prefs,
      kNoticeKeywordsPrefKey,
      data["notificationKeywords"],
    );
    await _setStringList(
      prefs,
      kNotificationSourcesPrefKey,
      data["notificationSources"],
    );
    await _setBool(prefs, _allNoticesEnabledKey, data["allNoticesEnabled"]);
    await _setBool(
      prefs,
      _keywordNoticesEnabledKey,
      data["keywordNoticesEnabled"],
    );
    await _setBool(
      prefs,
      kNoticeFilterEnabledPrefKey,
      data["noticeFilterEnabled"],
    );
    await _setBool(
      prefs,
      kNoticeFilterRequireKeywordPrefKey,
      data["noticeFilterRequireKeyword"],
    );
    await _setStringList(
      prefs,
      kNoticeFilterSourcesPrefKey,
      data["interestSources"],
    );
    await _setStringList(
      prefs,
      kNoticeFilterTypesPrefKey,
      data["interestCategories"],
    );
    await _setStringList(
      prefs,
      kNoticeFilterExcludesPrefKey,
      data["noticeFilterExcludes"],
    );
    await _setStringList(
      prefs,
      kNoticeFilterIncludesPrefKey,
      data["noticeFilterIncludes"],
    );

    await _setStringList(
      prefs,
      kHomeDashboardEnabledSectionsPrefKey,
      data["homeDashboardEnabledSections"],
    );
    await _setStringList(
      prefs,
      kHomeDashboardSectionOrderPrefKey,
      data["homeDashboardSectionOrder"],
    );

    final Map<String, dynamic> bookmarks =
        _asMap(data["bookmarks"]) ?? const {};
    await _hydrateBookmarkGroup(
      prefs,
      prefix: _pinnedPrefix,
      data: _asMap(bookmarks["pinned"]) ?? const {},
    );
    await _hydrateBookmarkGroup(
      prefs,
      prefix: _favoritePrefix,
      data: _asMap(bookmarks["favorites"]) ?? const {},
    );

    final Map<String, dynamic>? mpu = _asMap(data["mpuProfile"]);
    if (mpu != null) {
      await saveMpuProfile(
        MpuProfile(
          name: (mpu["name"] ?? "").toString(),
          department: (mpu["department"] ?? "").toString(),
          grade: (mpu["grade"] ?? "").toString(),
          studentId: (mpu["studentId"] ?? "").toString(),
          mileage: (mpu["mileage"] ?? "").toString(),
        ),
      );
    } else {
      await clearMpuProfile();
    }
  }

  Future<void> pushSnapshotToCloud({
    User? userOverride,
    bool includeCreatedAt = false,
  }) async {
    final User? user = userOverride ?? _auth.currentUser;
    if (user == null) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> payload = {
      "email": user.email,
      "emailDomain": "mjc.ac.kr",
      "updatedAt": FieldValue.serverTimestamp(),
      "notificationKeywords":
          prefs.getStringList(kNoticeKeywordsPrefKey) ?? const <String>[],
      "notificationSources": prefs.getStringList(kNotificationSourcesPrefKey) ??
          defaultNotificationSources(),
      "allNoticesEnabled": prefs.getBool(_allNoticesEnabledKey) ?? true,
      "keywordNoticesEnabled": prefs.getBool(_keywordNoticesEnabledKey) ?? true,
      "noticeFilterEnabled":
          prefs.getBool(kNoticeFilterEnabledPrefKey) ?? false,
      "noticeFilterRequireKeyword":
          prefs.getBool(kNoticeFilterRequireKeywordPrefKey) ?? false,
      "interestSources": prefs.getStringList(kNoticeFilterSourcesPrefKey) ??
          kNoticeFilterSourceOptions,
      "interestCategories": prefs.getStringList(kNoticeFilterTypesPrefKey) ??
          kNoticeFilterTypeOptions,
      "noticeFilterExcludes":
          prefs.getStringList(kNoticeFilterExcludesPrefKey) ?? const <String>[],
      "noticeFilterIncludes":
          prefs.getStringList(kNoticeFilterIncludesPrefKey) ?? const <String>[],
      "homeDashboardEnabledSections":
          prefs.getStringList(kHomeDashboardEnabledSectionsPrefKey) ??
              defaultHomeDashboardEnabledSections(),
      "homeDashboardSectionOrder":
          prefs.getStringList(kHomeDashboardSectionOrderPrefKey) ??
              defaultHomeDashboardSectionOrder(),
      "bookmarks": {
        "pinned": _collectBookmarkPrefs(prefs, _pinnedPrefix),
        "favorites": _collectBookmarkPrefs(prefs, _favoritePrefix),
      },
      "mpuProfile": {
        "name": prefs.getString(kMpuProfileNamePrefKey) ?? "",
        "department": prefs.getString(kMpuProfileDepartmentPrefKey) ?? "",
        "grade": prefs.getString(kMpuProfileGradePrefKey) ?? "",
        "studentId": prefs.getString(kMpuProfileStudentIdPrefKey) ?? "",
        "mileage": prefs.getString(kMpuProfileMileagePrefKey) ?? "",
      },
    };

    if (includeCreatedAt) {
      payload["createdAt"] = FieldValue.serverTimestamp();
    }

    await _userDoc(user).set(payload, SetOptions(merge: true));
  }

  Future<void> updateKeywords(List<String> keywords) async {
    await _updateSignedInUser({
      "notificationKeywords": keywords,
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateSources(List<String> sources) async {
    await _updateSignedInUser({
      "notificationSources": sources,
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateNoticeFilter(NoticeFilterState state) async {
    await _updateSignedInUser({
      "noticeFilterEnabled": state.enabled,
      "noticeFilterRequireKeyword": state.requireKeywordHit,
      "interestSources": state.sources,
      "interestCategories": state.types,
      "noticeFilterExcludes": state.excludes,
      "noticeFilterIncludes": state.includes,
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateBookmarks(
    String boardId, {
    required bool pinned,
    required List<String> values,
  }) async {
    final String group = pinned ? "pinned" : "favorites";
    await _updateSignedInUser({
      "bookmarks.$group.$boardId": values,
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateSignedInUser(Map<String, dynamic> data) async {
    final User? user = _auth.currentUser;
    if (user == null) return;
    await _userDoc(user).set(data, SetOptions(merge: true));
  }

  Map<String, List<String>> _collectBookmarkPrefs(
    SharedPreferences prefs,
    String prefix,
  ) {
    final Map<String, List<String>> result = {};
    for (final String key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final String boardId = key.substring(prefix.length);
      result[boardId] = prefs.getStringList(key) ?? const <String>[];
    }
    return result;
  }

  Future<void> _hydrateBookmarkGroup(
    SharedPreferences prefs, {
    required String prefix,
    required Map<String, dynamic> data,
  }) async {
    for (final String key in prefs.getKeys().toList()) {
      if (key.startsWith(prefix)) {
        await prefs.remove(key);
      }
    }
    for (final MapEntry<String, dynamic> entry in data.entries) {
      await _setStringList(prefs, "$prefix${entry.key}", entry.value);
    }
  }

  Future<void> _setStringList(
    SharedPreferences prefs,
    String key,
    dynamic value,
  ) async {
    if (value is Iterable) {
      await prefs.setStringList(
        key,
        value.map((Object? item) => item.toString()).toList(),
      );
    }
  }

  Future<void> _setBool(
    SharedPreferences prefs,
    String key,
    dynamic value,
  ) async {
    if (value is bool) {
      await prefs.setBool(key, value);
    }
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) {
      return value.map(
        (Object? key, Object? value) => MapEntry(key.toString(), value),
      );
    }
    return null;
  }
}
