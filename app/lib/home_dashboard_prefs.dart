import "package:shared_preferences/shared_preferences.dart";

/// 홈 대시보드에서 표시할 섹션을 사용자가 선택할 수 있게 하는 설정값입니다.
///
/// 저장 형식: enabled section id 목록(StringList)
const String kHomeDashboardEnabledSectionsPrefKey =
    "home_dashboard_enabled_sections";

/// 저장 형식: section id 전체 순서 목록(StringList)
const String kHomeDashboardSectionOrderPrefKey = "home_dashboard_section_order";

enum HomeDashboardSection {
  lectureReminder,
  quickButtons,
  shuttle,
  foodcourt,
  mpuDeadline,
  academicSchedule,
  recentNotices,
}

extension HomeDashboardSectionMeta on HomeDashboardSection {
  String get id => switch (this) {
        HomeDashboardSection.lectureReminder => "lecture_reminder",
        HomeDashboardSection.quickButtons => "quick_buttons",
        HomeDashboardSection.shuttle => "shuttle",
        HomeDashboardSection.foodcourt => "foodcourt",
        HomeDashboardSection.mpuDeadline => "mpu_deadline",
        HomeDashboardSection.academicSchedule => "academic_schedule",
        HomeDashboardSection.recentNotices => "recent_notices",
      };

  String get label => switch (this) {
        HomeDashboardSection.lectureReminder => "강의 알림",
        HomeDashboardSection.quickButtons => "바로가기 버튼",
        HomeDashboardSection.shuttle => "셔틀버스",
        HomeDashboardSection.foodcourt => "오늘의 학식",
        HomeDashboardSection.mpuDeadline => "MPU 신청 마감",
        HomeDashboardSection.academicSchedule => "다가오는 학사일정",
        HomeDashboardSection.recentNotices => "최근 공지사항",
      };
}

List<String> defaultHomeDashboardEnabledSections() {
  return HomeDashboardSection.values.map((s) => s.id).toList();
}

List<String> defaultHomeDashboardSectionOrder() {
  return <String>[
    HomeDashboardSection.lectureReminder.id,
    HomeDashboardSection.quickButtons.id,
    HomeDashboardSection.shuttle.id,
    HomeDashboardSection.foodcourt.id,
    HomeDashboardSection.mpuDeadline.id,
    HomeDashboardSection.academicSchedule.id,
    HomeDashboardSection.recentNotices.id,
  ];
}

Set<String> allowedHomeDashboardSectionIds() {
  return HomeDashboardSection.values.map((s) => s.id).toSet();
}

Future<Set<String>> loadHomeDashboardEnabledSections() async {
  final prefs = await SharedPreferences.getInstance();
  final List<String>? stored =
      prefs.getStringList(kHomeDashboardEnabledSectionsPrefKey);
  if (stored == null || stored.isEmpty) {
    return defaultHomeDashboardEnabledSections().toSet();
  }
  final Set<String> allowed = allowedHomeDashboardSectionIds();
  final Set<String> next =
      stored.where((id) => allowed.contains(id)).toSet();
  if (next.isEmpty) return defaultHomeDashboardEnabledSections().toSet();
  return next;
}

Future<List<String>> loadHomeDashboardSectionOrder() async {
  final prefs = await SharedPreferences.getInstance();
  final List<String>? stored =
      prefs.getStringList(kHomeDashboardSectionOrderPrefKey);
  final Set<String> allowed = allowedHomeDashboardSectionIds();

  final List<String> cleaned = (stored ?? const <String>[])
      .where((id) => allowed.contains(id))
      .toList();

  // 누락된 섹션이 있으면 뒤에 채웁니다.
  final Set<String> seen = cleaned.toSet();
  final List<String> out = [...cleaned];
  for (final s in HomeDashboardSection.values) {
    if (!seen.contains(s.id)) out.add(s.id);
  }
  if (out.isEmpty) return defaultHomeDashboardSectionOrder();
  // 신규 «강의 알림» 섹션: 저장된 순서에 없으면 바로가기 앞에 삽입
  const String lr = "lecture_reminder";
  if (!out.contains(lr)) {
    final int qb = out.indexOf("quick_buttons");
    if (qb >= 0) {
      out.insert(qb, lr);
    } else {
      out.insert(0, lr);
    }
  }
  return out;
}

Future<void> saveHomeDashboardEnabledSections(Set<String> enabled) async {
  final Set<String> allowed = allowedHomeDashboardSectionIds();
  final List<String> order = await loadHomeDashboardSectionOrder();
  final List<String> orderedEnabled =
      order.where((id) => enabled.contains(id) && allowed.contains(id)).toList();

  if (orderedEnabled.isEmpty) {
    // 홈은 비어 보이면 혼란스러우니 최소 하나는 유지합니다.
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(
    kHomeDashboardEnabledSectionsPrefKey,
    orderedEnabled,
  );
}

Future<void> saveHomeDashboardSectionOrder(List<String> order) async {
  final Set<String> allowed = allowedHomeDashboardSectionIds();
  final List<String> cleaned = order.where((id) => allowed.contains(id)).toList();
  final Set<String> seen = cleaned.toSet();
  final List<String> out = [...cleaned];
  for (final s in HomeDashboardSection.values) {
    if (!seen.contains(s.id)) out.add(s.id);
  }
  if (out.isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(kHomeDashboardSectionOrderPrefKey, out);
}

