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
  static const double barPillHeight = 64;
  static const double barInnerBottomPadding = 10;
  static const double scrollBottomGap = 8;
  /// 하단 navbar pill 좌·우 inset ([MainNavigationScreen] padding과 동일).
  static const double barHorizontalInset = 14;

  /// overlay(공지 서브 nav, FAB 등) 배치용 — navbar 컨테이너 + safe area.
  /// [MediaQuery.viewPadding] 사용 — 메인 탭 body는 padding.bottom이 0으로 strip됩니다.
  static double bottomInset(BuildContext context) =>
      barHeight + MediaQuery.viewPaddingOf(context).bottom;

  /// navbar pill 상단 — FAB는 이 기준으로 [fabGapAboveNav]만큼 위에 둡니다.
  static double navPillTopFromBottom(BuildContext context) =>
      MediaQuery.viewPaddingOf(context).bottom +
      barInnerBottomPadding +
      barPillHeight;

  /// 메인 탭 안 FAB — navbar pill 위 여백(px). 줄이면 FAB가 내려갑니다.
  static const double fabGapAboveNav = 32;

  /// Stack [Positioned] FAB bottom.
  static double fabBottomOffset(BuildContext context) {
    if (MainNavigationScope.maybeNavigate(context) == null) {
      return MediaQuery.viewPaddingOf(context).bottom + 16;
    }
    return navPillTopFromBottom(context) + fabGapAboveNav;
  }

  /// 시간표 FAB 지름 — 스크롤 하단 여백 계산용.
  static const double timetableFabSize = 58;

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
