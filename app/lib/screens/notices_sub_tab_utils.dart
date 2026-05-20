import "package:mjc_in_one/screens/notices_tab_screen.dart";

/// 실험실 학과 공지 ON일 때만 [NoticesSubTab.dept] 포함.
List<NoticesSubTab> visibleNoticeSubTabs(bool departmentLabEnabled) {
  if (departmentLabEnabled) {
    return NoticesSubTab.values;
  }
  return NoticesSubTab.values.where((t) => t != NoticesSubTab.dept).toList();
}

NoticesSubTab noticeSubTabFromVisibleIndex(
  List<NoticesSubTab> visible,
  int index,
) {
  if (index < 0 || index >= visible.length) {
    return NoticesSubTab.main;
  }
  return visible[index];
}

int visibleIndexOfNoticeSubTab(
  List<NoticesSubTab> visible,
  NoticesSubTab tab,
) {
  final int index = visible.indexOf(tab);
  return index >= 0 ? index : 0;
}
