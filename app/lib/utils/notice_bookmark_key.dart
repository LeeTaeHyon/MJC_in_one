/// 고정·즐겨찾기 SharedPreferences 키 후보.
///
/// 화면마다 저장 형식이 조금씩 달라, 마이페이지에서는 후보 전체를 검사합니다.
const String kDepartmentNoticeBoardPrefix = "dept_";

/// 학과 공지 Firestore `community_notices/{deptSlug}` 게시판 ID.
String departmentNoticeBoardId(String deptSlug) =>
    "$kDepartmentNoticeBoardPrefix${deptSlug.trim()}";

/// 학과 공지 고정·즐겨찾기 키.
String departmentNoticeBookmarkKey(
  String boardId,
  Map<String, dynamic> data,
) {
  final String id = (data["id"] ?? "").toString().trim();
  if (id.isNotEmpty) return "$boardId|$id";
  final String title = (data["title"] ?? "").toString().trim();
  final String date = (data["date"] ?? "").toString().trim();
  return "$boardId|$title|$date";
}

Set<String> noticeBookmarkKeyCandidates(
  String boardId,
  Map<String, dynamic> data,
) {
  final String title = (data["title"] ?? "").toString().trim();
  final String id = (data["id"] ?? "").toString().trim();

  String pickDate({required bool preferRegDate}) {
    final String reg = (data["reg_date"] ?? "").toString().trim();
    final String date = (data["date"] ?? "").toString().trim();
    if (preferRegDate) {
      return reg.isNotEmpty ? reg : date;
    }
    return date.isNotEmpty ? date : reg;
  }

  final Set<String> keys = <String>{};

  if (boardId == "mpu_programs") {
    final String branch = (data["branch"] ?? "").toString().trim();
    final String dDay = (data["d_day"] ?? "").toString().trim();
    final String date = pickDate(preferRegDate: true);
    keys.add("$title|$branch|$dDay|$date");
    final String altDate = pickDate(preferRegDate: false);
    if (altDate != date) {
      keys.add("$title|$branch|$dDay|$altDate");
    }
    return keys;
  }

  if (boardId.startsWith(kDepartmentNoticeBoardPrefix)) {
    keys.add(departmentNoticeBookmarkKey(boardId, data));
    return keys;
  }

  if (boardId.startsWith("ctl_")) {
    final String link = (data["link"] ?? data["url"] ?? "").toString().trim();
    final String date = pickDate(preferRegDate: true);
    keys.add("$link|$title|$date");
    final String altDate = pickDate(preferRegDate: false);
    if (altDate != date) {
      keys.add("$link|$title|$altDate");
    }
    return keys;
  }

  final String url = (data["url"] ?? data["link"] ?? "").toString().trim();
  final String date = pickDate(preferRegDate: false);

  if (id.isNotEmpty) {
    keys.add(id);
    keys.add("$boardId|$id");
  }
  keys.add("$url|$title|$date");
  keys.add("$boardId|$url|$title|$date");
  return keys;
}

bool noticeBookmarkMatches(
  String boardId,
  Map<String, dynamic> data,
  Set<String> storedKeys,
) {
  if (storedKeys.isEmpty) return false;
  return noticeBookmarkKeyCandidates(boardId, data).any(storedKeys.contains);
}
