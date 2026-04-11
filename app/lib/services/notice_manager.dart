import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/foundation.dart";

/// 모든 공지사항 데이터를 통합 관리하고 캐싱하는 매니저 (싱글톤)
class NoticeManager {
  static final NoticeManager _instance = NoticeManager._internal();
  factory NoticeManager() => _instance;
  NoticeManager._internal();

  // 소스별 데이터 캐시 저장소
  final Map<String, List<Map<String, dynamic>>> _cache = {};
  
  // 데이터 로딩 중인지 여부 (중복 요청 방지)
  final Map<String, bool> _isLoading = {};

  /// 특정 보드 또는 소스의 데이터를 가져옴 (기본적으로 캐시 우선)
  Future<List<Map<String, dynamic>>> getNotices({
    required String boardId,
    bool forceRefresh = false,
  }) async {
    // 캐시가 있고 강제 새로고침이 아니면 즉시 반환
    if (!forceRefresh && _cache.containsKey(boardId) && _cache[boardId] != null) {
      debugPrint("캐시된 데이터를 반환합니다: $boardId");
      return _cache[boardId]!;
    }

    // 중복 로딩 방지
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
        // 대시보드용 통합 공지 (MJC + MPU + CTL)
        results = await _fetchDashboardCombined();
      } else if (boardId == "mpu_programs") {
        results = await _fetchMpuPrograms();
      } else if (boardId == "ctl_notices" || boardId == "ctl_programs") {
        results = await _fetchCtlSource(boardId == "ctl_programs" ? "programs" : "notices");
      } else {
        // MJC 개별 게시판 (main_notice, main_academic, main_scholarship)
        results = await _fetchMjcSource(boardId);
      }

      _cache[boardId] = results;
      return results;
    } catch (e) {
      debugPrint("데이터 로딩 중 에러 발생 ($boardId): $e");
      return _cache[boardId] ?? [];
    } finally {
      _isLoading[boardId] = false;
    }
  }

  /// MJC 게시판 직접 읽기
  Future<List<Map<String, dynamic>>> _fetchMjcSource(String boardId) async {
    final snap = await FirebaseFirestore.instance
        .collection("notices")
        .doc(boardId)
        .collection("posts")
        .get();
    
    final docs = snap.docs.map((doc) => {...doc.data(), "id": doc.id}).toList();
    docs.sort((a,b) => (b["date"] ?? "").compareTo(a["date"] ?? ""));
    return docs;
  }

  /// MPU 프로그램 직접 읽기
  Future<List<Map<String, dynamic>>> _fetchMpuPrograms() async {
    final snap = await FirebaseFirestore.instance
        .collection("core_competencies")
        .doc("all")
        .collection("programs")
        .get();
    return snap.docs.map((doc) => {...doc.data(), "id": doc.id}).toList();
  }

  /// CTL 데이터 직접 읽기
  Future<List<Map<String, dynamic>>> _fetchCtlSource(String subPath) async {
    final snap = await FirebaseFirestore.instance
        .collection("ctl_data")
        .doc(subPath)
        .collection("items")
        .get();
    return snap.docs.map((doc) => {...doc.data(), "id": doc.id}).toList();
  }

  /// 대시보드용 최근 2주 통합 데이터 (요청하신 복잡한 로직 통합)
  Future<List<Map<String, dynamic>>> _fetchDashboardCombined() async {
    final now = DateTime.now();
    final twoWeeksAgo = now.subtract(const Duration(days: 14));
    final List<Map<String, dynamic>> combined = [];

    // 1. MJC (notices)
    const mjcBoards = ["main_notice", "main_academic", "main_scholarship"];
    for (var bid in mjcBoards) {
      final items = await _fetchMjcSource(bid);
      for (var item in items) {
        final date = _parseDate(item["date"] ?? "");
        if (date != null && date.isAfter(twoWeeksAgo)) {
          combined.add({
            ...item,
            "source": "MJC",
            "type": bid == "main_notice" ? "공지사항" : (bid == "main_academic" ? "학사공지" : "장학공지"),
            "reg_date": item["date"],
            "parsedDate": date,
          });
        }
      }
    }

    // 2. MPU
    final mpuItems = await _fetchMpuPrograms();
    for (var item in mpuItems) {
      final date = _parseDate(item["reg_date"] ?? "");
      if (date != null && date.isAfter(twoWeeksAgo)) {
        combined.add({
          ...item,
          "source": "MPU",
          "type": item["branch"] ?? "역량관리",
          "parsedDate": date,
        });
      }
    }

    // 3. CTL
    final ctlItems = await _fetchCtlSource("notices");
    for (var item in ctlItems) {
      final date = _parseDate(item["reg_date"] ?? item["date"] ?? "");
      if (date != null && date.isAfter(twoWeeksAgo)) {
        combined.add({
          ...item,
          "source": "CTL",
          "type": "학습공지",
          "parsedDate": date,
        });
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

  /// 캐시 완전히 삭제 (로그아웃이나 초기화 시 사용)
  void clearCache() {
    _cache.clear();
    _isLoading.clear();
  }
}
