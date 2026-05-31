import "package:flutter/material.dart";
import "package:mjc_in_one/screens/notices_tab_screen.dart";

typedef MainNavigationNavigate = void Function(
  int tabIndex, {
  NoticesSubTab? noticesSubTab,
  int? myPageBookmarkTabIndex,
});

/// [MainNavigationScreen] floating bottom bar 레이아웃 상수.
abstract final class MainNavLayout {
  static const double barHeight = 82;
  static const double scrollBottomGap = 8;

  /// overlay(공지 서브 nav, FAB 등) 배치용 — navbar + safe area.
  static double bottomInset(BuildContext context) =>
      barHeight + MediaQuery.paddingOf(context).bottom;

  /// 메인 탭 안 nested Scaffold FAB — navbar 위 여백(px). 이 값만 키우면 FAB가 위로 올라갑니다.
  static const double fabGapAboveNav = 16;

  /// Scaffold 기본 FAB 하단 inset(16)을 감안한 FAB [Padding.bottom].
  static double fabBottomPadding(BuildContext context) {
    if (MainNavigationScope.maybeNavigate(context) == null) {
      return 0;
    }
    const double scaffoldFabInset = 16;
    return barHeight + fabGapAboveNav - scaffoldFabInset;
  }

  /// 스크롤 맨 아래 여백 — pill 높이만. safe area는 navbar가 처리합니다.
  static double scrollBottomExtra(BuildContext context) {
    if (MainNavigationScope.maybeNavigate(context) == null) {
      return 0;
    }
    return barHeight + scrollBottomGap;
  }

  static Widget scrollBottomSpacer(BuildContext context) =>
      SizedBox(height: scrollBottomExtra(context));
}

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
