import "package:flutter/material.dart";
import "package:mjc_in_one/screens/notices_tab_screen.dart";

typedef MainNavigationNavigate = void Function(
  int tabIndex, {
  NoticesSubTab? noticesSubTab,
  int? myPageBookmarkTabIndex,
});

/// [MainNavigationScreen] 하단 탭 전환. 하위 화면·유틸에서 `maybeNavigate`로 조회합니다.
class MainNavigationScope extends InheritedWidget {
  const MainNavigationScope({
    super.key,
    required this.navigate,
    required super.child,
  });

  final MainNavigationNavigate navigate;

  static MainNavigationNavigate? maybeNavigate(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<MainNavigationScope>()
        ?.navigate;
  }

  @override
  bool updateShouldNotify(MainNavigationScope oldWidget) {
    return navigate != oldWidget.navigate;
  }
}
