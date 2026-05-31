import "package:flutter/material.dart";
import "package:mjc_in_one/screens/notices_tab_screen.dart";

typedef MainNavigationNavigate = void Function(
  int tabIndex, {
  NoticesSubTab? noticesSubTab,
  int? myPageBookmarkTabIndex,
});

/// [MainNavigationScreen] bottom bar / 공지 floating pill 레이아웃 상수.
abstract final class MainNavLayout {
  static const double barHeight = 64;
  static const double barTopCornerRadius = 24;
  static const double scrollBottomGap = 8;

  /// 공지 탭 하단 floating pill — 메인 navbar와 동일한 높이·inset.
  static const double noticeFloatingPillHorizontalInset = 14;

  /// FAB·overlay 좌·우 inset.
  static const double fabHorizontalInset = 14;

  /// overlay(공지 서브 nav, FAB 등) 배치용 — navbar + safe area.
  static double bottomInset(BuildContext context) =>
      barHeight + MediaQuery.viewPaddingOf(context).bottom;

  /// navbar 상단 — FAB는 이 기준으로 [fabGapAboveNav]만큼 위에 둡니다.
  static double navBarTopFromBottom(BuildContext context) =>
      MediaQuery.viewPaddingOf(context).bottom + barHeight;

  /// 메인 탭 안 FAB — navbar 위 여백(px).
  static const double fabGapAboveNav = 16;

  /// Stack [Positioned] FAB bottom.
  static double fabBottomOffset(BuildContext context) {
    if (MainNavigationScope.maybeNavigate(context) == null) {
      return MediaQuery.viewPaddingOf(context).bottom + 16;
    }
    return navBarTopFromBottom(context) + fabGapAboveNav;
  }

  /// 시간표 FAB 지름 — 스크롤 하단 여백 계산용.
  static const double timetableFabSize = 58;

  /// 스크롤 맨 아래 여백.
  static double scrollBottomExtra(BuildContext context) {
    if (MainNavigationScope.maybeNavigate(context) == null) {
      return 0;
    }
    return barHeight + scrollBottomGap;
  }

  /// [MainNavigationScreen] 하단 네비 위에 띄울 floating SnackBar 여백.
  static EdgeInsets snackBarMargin(BuildContext context) {
    if (MainNavigationScope.maybeNavigate(context) != null) {
      return EdgeInsets.fromLTRB(16, 0, 16, bottomInset(context));
    }
    return const EdgeInsets.fromLTRB(16, 0, 16, 16);
  }

  static Widget scrollBottomSpacer(BuildContext context) =>
      SizedBox(height: scrollBottomExtra(context));
}

/// [MainNavigationScreen] 하단 탭 전환. 하위 화면·유틸에서 `maybeNavigate`로 조회합니다.
class MainNavigationScope extends InheritedWidget {
  const MainNavigationScope({
    super.key,
    required this.navigate,
    required this.noticesFloatingNav,
    required super.child,
  });

  final MainNavigationNavigate navigate;

  /// 공지 탭에서 하단 메인 navbar 대신 floating pill을 같은 위치에 표시합니다.
  final bool noticesFloatingNav;

  static MainNavigationNavigate? maybeNavigate(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<MainNavigationScope>()
        ?.navigate;
  }

  static bool? maybeNoticesFloatingNav(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<MainNavigationScope>()
        ?.noticesFloatingNav;
  }

  @override
  bool updateShouldNotify(MainNavigationScope oldWidget) {
    return navigate != oldWidget.navigate ||
        noticesFloatingNav != oldWidget.noticesFloatingNav;
  }
}
