import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/foundation.dart";

/// 모든 공지사항 데이터를 통합 관리하고 캐싱하는 매니저 (싱글톤)
class NoticeManager {
  static final NoticeManager _instance = NoticeManager._internal();
  factory NoticeManager() => _instance;
  NoticeManager._internal();

  final Map<String, List<Map<String, dynamic>>> _cache = {};
  final Map<String, bool> _isLoading = {};

  Future<List<Map<String, dynamic>>> getNotices({
    required String boardId,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cache.containsKey(boardId) && _cache[boardId] != null) {
      return _cache[boardId]!;
    }

    if (_isLoading[boardId] == true) {
      while (_isLoading[boardId] == true) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _cache[boardId] ?? [];
    }

    _isLoading[boardId] = true;
    debugPrint("Firebase에서 데이터를 새로 읽어옵니다: $boardId");

    try {
      List<Map<String, dynamic>> results = [];

      if (boardId == "combined_dashboard") {
        results = await _fetchDashboardCombined();
      } else if (boardId == "mpu_programs") {
        // MPU: 실제 컬렉션 경로
        // MPU 실제 경로
        final snap = await FirebaseFirestore.instance.collection("core_competencies").doc("all").collection("programs").get();
        results = snap.docs.map((doc) => {...doc.data(), "id": doc.id, "date": doc.data()["reg_date"] ?? ""}).toList();
      } else if (boardId == "ctl_notice" || boardId == "ctl_programs") {
        // CTL 실제 경로
        final subPath = boardId == "ctl_programs" ? "programs" : "notices";
        final snap = await FirebaseFirestore.instance.collection("ctl_data").doc(subPath).collection("items").get();
        results = snap.docs.map((doc) => {...doc.data(), "id": doc.id, "date": doc.data()["date"] ?? doc.data()["reg_date"] ?? ""}).toList();
      } else {
        // MJC 개별 게시판
        final snap = await FirebaseFirestore.instance.collection("notices").doc(boardId).collection("posts").get();
        results = snap.docs.map((doc) => {...doc.data(), "id": doc.id, "date": doc.data()["date"] ?? doc.data()["reg_date"] ?? ""}).toList();
      }

      // 공통 날짜 정렬
      results.sort((a, b) => (b["date"] ?? "").compareTo(a["date"] ?? ""));
      
      _cache[boardId] = results;
      return results;
    } catch (e) {
      debugPrint("데이터 로딩 중 에러 발생 ($boardId): $e");
      return _cache[boardId] ?? [];
    } finally {
      _isLoading[boardId] = false;
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

    for (var entry in sources.entries) {
      final items = await getNotices(boardId: entry.key);
      for (var item in items) {
        final date = _parseDate(item["date"] ?? "");
        if (date != null && date.isAfter(twoWeeksAgo)) {
          combined.add({
            ...item,
            "source": entry.key.contains("main") ? "MJC" : (entry.key.contains("mpu") ? "MPU" : "CTL"),
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
