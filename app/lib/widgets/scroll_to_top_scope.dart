import "package:flutter/material.dart";

/// [MainNavigationScreen] 하단 탭 순서와 같아야 합니다.
abstract final class MainNavTabIndex {
  static const int home = 0;
  static const int library = 1;
  static const int mainSite = 2;
  static const int ctl = 3;
  static const int mpu = 4;
}

/// 메인 탭·푸시 라우트에서 등록한 스크롤/웹뷰 맨 위로 동작을 한곳에서 호출합니다.
class ScrollToTopCoordinator {
  /// 스크롤이 **뷰포트 높이의 이 비율만큼** 이상 내려갔을 때만 맨 위로 버튼을 보입니다. (예: 0.18 → 약 18%)
  static const double fabRevealScrollViewportFraction = 0.8;

  int _activeMainTab = 0;
  final Map<int, VoidCallback> _mainTabHandlers = <int, VoidCallback>{};
  final Map<int, double> _lastMainScrollPixels = <int, double>{};
  final Map<int, double> _lastMainViewportHeight = <int, double>{};
  final List<VoidCallback> _routeHandlers = <VoidCallback>[];

  final ValueNotifier<bool> fabVisibleNotifier = ValueNotifier<bool>(false);

  static double _scrollRevealThreshold(double viewportHeight) {
    final double h = viewportHeight > 0 ? viewportHeight : 400;
    return h * fabRevealScrollViewportFraction;
  }

  void _setFabVisible(bool visible) {
    if (fabVisibleNotifier.value != visible) {
      fabVisibleNotifier.value = visible;
    }
  }

  void setActiveMainTab(int index) {
    _activeMainTab = index;
    final double? y = _lastMainScrollPixels[index];
    final double? vh = _lastMainViewportHeight[index];
    if (y == null || vh == null) {
      _setFabVisible(false);
      return;
    }
    _setFabVisible(y > _scrollRevealThreshold(vh));
  }

  /// [pixels]: 스크롤 오프셋(또는 웹뷰 `scrollY`). [viewportHeight]: 같은 축의 뷰포트 높이(스크롤뷰 뷰포트 또는 `innerHeight` 등).
  void reportMainTabScroll(
    int tabIndex,
    double pixels,
    double viewportHeight,
  ) {
    _lastMainScrollPixels[tabIndex] = pixels;
    _lastMainViewportHeight[tabIndex] = viewportHeight;
    if (tabIndex != _activeMainTab) return;
    _setFabVisible(pixels > _scrollRevealThreshold(viewportHeight));
  }

  /// 푸시된 라우트(설정·내역 등) 본문 스크롤.
  void reportRouteScroll(double pixels, double viewportHeight) {
    if (_routeHandlers.isEmpty) return;
    _setFabVisible(pixels > _scrollRevealThreshold(viewportHeight));
  }

  void registerMainTab(int tabIndex, VoidCallback handler) {
    _mainTabHandlers[tabIndex] = handler;
  }

  void unregisterMainTab(int tabIndex) {
    _mainTabHandlers.remove(tabIndex);
    _lastMainScrollPixels.remove(tabIndex);
    _lastMainViewportHeight.remove(tabIndex);
  }

  void pushRouteHandler(VoidCallback handler) {
    _routeHandlers.add(handler);
    _setFabVisible(false);
  }

  void popRouteHandler() {
    if (_routeHandlers.isEmpty) return;
    _routeHandlers.removeLast();
    _setFabVisible(false);
  }

  void scrollToTop() {
    if (_routeHandlers.isNotEmpty) {
      _routeHandlers.last();
    } else {
      _mainTabHandlers[_activeMainTab]?.call();
    }
  }
}

class ScrollToTopScope extends InheritedWidget {
  const ScrollToTopScope({
    super.key,
    required this.coordinator,
    required super.child,
  });

  final ScrollToTopCoordinator coordinator;

  static ScrollToTopCoordinator of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ScrollToTopScope>();
    assert(scope != null, "ScrollToTopScope가 없습니다.");
    return scope!.coordinator;
  }

  static ScrollToTopCoordinator? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<ScrollToTopScope>()?.coordinator;
  }

  @override
  bool updateShouldNotify(ScrollToTopScope oldWidget) =>
      oldWidget.coordinator != coordinator;
}
