import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/foundation.dart";
import "package:mio_notice/agent_debug_log.dart";

/// 모든 공지사항 데이터를 통합 관리하고 캐싱하는 매니저 (싱글톤)
class NoticeManager {
  static final NoticeManager _instance = NoticeManager._internal();
  factory NoticeManager() => _instance;
  NoticeManager._internal();

  final Map<String, List<Map<String, dynamic>>> _cache = {};
  final Map<String, bool> _isLoading = {};
  final Map<String, Future<List<Map<String, dynamic>>>> _inFlight = {};

  Future<List<Map<String, dynamic>>> getNotices({
    required String boardId,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cache.containsKey(boardId) && _cache[boardId] != null) {
      return _cache[boardId]!;
    }

    final inflight = _inFlight[boardId];
    if (inflight != null) {
      // #region agent log
      agentDebugNdjson(
        hypothesisId: "H5",
        location: "notice_manager.dart:getNotices",
        message: "join inflight request",
        data: <String, dynamic>{
          "boardId": boardId,
          "forceRefresh": forceRefresh,
        },
      );
      // #endregion
      return await inflight;
    }

    _isLoading[boardId] = true;
    debugPrint("Firebase에서 데이터를 새로 읽어옵니다: $boardId");

    try {
      // #region agent log
      final int t0 = DateTime.now().millisecondsSinceEpoch;
      agentDebugNdjson(
        hypothesisId: "H5",
        location: "notice_manager.dart:getNotices",
        message: "fetch start",
        data: <String, dynamic>{"boardId": boardId, "forceRefresh": forceRefresh},
      );
      // #endregion

      Future<List<Map<String, dynamic>>> doFetch() async {
        List<Map<String, dynamic>> results = [];

        if (boardId == "combined_dashboard") {
          results = await _fetchDashboardCombined();
        } else if (boardId == "mpu_programs") {
          // MPU: 실제 컬렉션 경로
          final snap = await FirebaseFirestore.instance
              .collection("core_competencies")
              .doc("all")
              .collection("programs")
              .get();
          results = snap.docs
              .map(
                (doc) => {
                  ...doc.data(),
                  "id": doc.id,
                  "date": doc.data()["reg_date"] ?? ""
                },
              )
              .toList();
        } else if (boardId == "ctl_notice" || boardId == "ctl_programs") {
          // CTL 실제 경로
          final subPath = boardId == "ctl_programs" ? "programs" : "notices";
          final snap = await FirebaseFirestore.instance
              .collection("ctl_data")
              .doc(subPath)
              .collection("items")
              .get();
          results = snap.docs
              .map(
                (doc) => {
                  ...doc.data(),
                  "id": doc.id,
                  "date": doc.data()["date"] ?? doc.data()["reg_date"] ?? ""
                },
              )
              .toList();
        } else {
          // MJC 개별 게시판
          final snap = await FirebaseFirestore.instance
              .collection("notices")
              .doc(boardId)
              .collection("posts")
              .get();
          results = snap.docs
              .map(
                (doc) => {
                  ...doc.data(),
                  "id": doc.id,
                  "date": doc.data()["date"] ?? doc.data()["reg_date"] ?? ""
                },
              )
              .toList();
        }

        // 공통 날짜 정렬
        results.sort((a, b) => (b["date"] ?? "").compareTo(a["date"] ?? ""));

        _cache[boardId] = results;
        return results;
      }

      final Future<List<Map<String, dynamic>>> future = doFetch();
      _inFlight[boardId] = future;
      final List<Map<String, dynamic>> results = await future;

      // #region agent log
      final int dt = DateTime.now().millisecondsSinceEpoch - t0;
      agentDebugNdjson(
        hypothesisId: "H5",
        location: "notice_manager.dart:getNotices",
        message: "fetch done",
        data: <String, dynamic>{
          "boardId": boardId,
          "ms": dt,
          "count": results.length,
        },
      );
      // #endregion
      return results;
    } catch (e) {
      debugPrint("데이터 로딩 중 에러 발생 ($boardId): $e");
      // #region agent log
      agentDebugNdjson(
        hypothesisId: "H5",
        location: "notice_manager.dart:getNotices",
        message: "fetch error",
        data: <String, dynamic>{"boardId": boardId, "error": e.toString()},
      );
      // #endregion
      return _cache[boardId] ?? [];
    } finally {
      _isLoading[boardId] = false;
      _inFlight.remove(boardId);
    }
  }

  /// 대시보드용 최근 2주 통합 데이터
  Future<List<Map<String, dynamic>>> _fetchDashboardCombined() async {
    final now = DateTime.now();
    final twoWeeksAgo = now.subtract(const Duration(days: 14));
    final List<Map<String, dynamic>> combined = [];

    // 대시보드에 표시할 소스들
    const sources = {
      "main_notice": "공지사항",
      "main_academic": "학사공지",
      "main_scholarship": "장학공지",
      "mpu_programs": "역량관리",
      "ctl_notice": "학습공지"
    };

    // 여러 보드를 순차로 당기면 1초+로 늘어져 jank를 만들기 쉬워 병렬로 가져옵니다.
    final entries = sources.entries.toList(growable: false);
    final fetched = await Future.wait<List<Map<String, dynamic>>>(
      entries.map((e) => getNotices(boardId: e.key)),
    );
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final items = fetched[i];
      for (var item in items) {
        final date = _parseDate(item["date"] ?? "");
        if (date != null && date.isAfter(twoWeeksAgo)) {
          combined.add({
            ...item,
            "source": entry.key.contains("main")
                ? "MJC"
                : (entry.key.contains("mpu") ? "MPU" : "CTL"),
            "type": entry.value,
            "parsedDate": date,
          });
        }
      }
    }

    combined.sort((a, b) {
      final dateA = a["parsedDate"] as DateTime? ?? DateTime(2000);
      final dateB = b["parsedDate"] as DateTime? ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

    return combined;
  }

  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      final RegExp dateRegExp = RegExp(r"(\d{2,4})[-.](\d{1,2})[-.](\d{1,2})");
      final match = dateRegExp.firstMatch(dateStr);
      if (match != null) {
        String year = match.group(1)!;
        if (year.length == 2) year = "20$year";
        final month = match.group(2)!.padLeft(2, "0");
        final day = match.group(3)!.padLeft(2, "0");
        return DateTime.parse("$year-$month-$day");
      }
      return null;
    } catch (e) { return null; }
  }

  void clearCache() {
    _cache.clear();
    _isLoading.clear();
  }
}
