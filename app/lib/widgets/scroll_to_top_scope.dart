import "package:flutter/material.dart";
import "package:flutter/scheduler.dart";

import "package:mio_notice/agent_debug_log.dart";

/// [ScrollController] 뷰포트 크기를 안전히 읽어 맨 위로 버튼 임계값에 씁니다.
/// Flutter 웹 등에서 [ScrollPosition] 프록시가 깨지는 경우를 막습니다.
abstract final class ScrollFabMetrics {
  ScrollFabMetrics._();

  /// [ScrollController] 리스너는 **레이아웃 단계**에서도 호출될 수 있습니다.
  /// 이때 [MediaQuery.sizeOf] 등 [BuildContext] 의존 조회를 하면 `markNeedsBuild`가 겹쳐
  /// `setState() or markNeedsBuild() called during build` 예외가 납니다.
  static double viewportHeightInScrollListener(ScrollController controller) {
    try {
      if (controller.hasClients) {
        final double v = controller.position.viewportDimension;
        if (v.isFinite && v > 0) {
          return v;
        }
      }
    } catch (_) {
      // 웹·전환 프레임에서 position 접근 실패 시 무시
    }
    return 400;
  }

  /// [didChangeDependencies]·[addPostFrameCallback] 등 [context] 사용이 안전할 때만 씁니다.
  static double viewportHeightForThreshold(
    ScrollController controller,
    BuildContext context,
  ) {
    try {
      if (controller.hasClients) {
        final double v = controller.position.viewportDimension;
        if (v.isFinite && v > 0) {
          return v;
        }
      }
    } catch (_) {
      // 웹·전환 프레임에서 position 접근 실패 시 무시
    }
    return MediaQuery.sizeOf(context).height;
  }
}

/// [NestedScrollView] + [TabBarView]에서 맨 위로 FAB용 스크롤 깊이를 잡습니다.
///
/// 외부 [ScrollController]는 헤더(접힘) 위주로만 움직이고, 본문 리스트 스크롤은
/// 내부 [Scrollable]의 [ScrollMetrics.pixels]에 쌓이는 경우가 많습니다(웹·모바일 공통).
/// 둘 중 큰 값을 [ScrollToTopCoordinator.reportMainTabScroll]에 넘깁니다.
final class NestedScrollFabScrollReporter {
  NestedScrollFabScrollReporter({
    required this.tabIndex,
    required this.outerController,
  });

  final int tabIndex;
  final ScrollController outerController;
  ScrollToTopCoordinator? coordinator;

  double _innerListPixels = 0;
  double _innerViewportDimension = 0;
  TabController? _tabController;

  void attachCoordinator(ScrollToTopCoordinator? c) {
    coordinator = c;
  }

  /// [DefaultTabController] 하위에서 호출하면 서브탭 전환 시 내부 스크롤 추적을 초기화합니다.
  void bindTabController(TabController? controller) {
    if (identical(_tabController, controller)) return;
    _tabController?.removeListener(_handleSubtabChanged);
    _tabController = controller;
    _tabController?.addListener(_handleSubtabChanged);
  }

  void disposeTabBinding() {
    _tabController?.removeListener(_handleSubtabChanged);
    _tabController = null;
  }

  void _handleSubtabChanged() {
    final TabController? t = _tabController;
    if (t == null || t.indexIsChanging) return;
    _innerListPixels = 0;
    _innerViewportDimension = 0;
    reportOuterScroll();
  }

  void reportOuterScroll() {
    _dispatchReport();
  }

  /// [TabBarView] 등 본문을 감싼 [NotificationListener.onNotification]에 연결합니다.
  bool handleInnerScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is ScrollUpdateNotification ||
        notification is ScrollMetricsNotification) {
      _innerListPixels = notification.metrics.pixels;
      final double d = notification.metrics.viewportDimension;
      if (d.isFinite && d > 0) {
        _innerViewportDimension = d;
      }
      _dispatchReport();
    }
    return false;
  }

  void _dispatchReport() {
    final ScrollToTopCoordinator? c = coordinator;
    if (c == null) return;
    void send() {
      final double outerPixels =
          outerController.hasClients ? outerController.offset : 0.0;
      final double combinedPixels = outerPixels > _innerListPixels
          ? outerPixels
          : _innerListPixels;
      double viewportHeight =
          ScrollFabMetrics.viewportHeightInScrollListener(outerController);
      if (_innerViewportDimension > 0) {
        viewportHeight = viewportHeight > _innerViewportDimension
            ? viewportHeight
            : _innerViewportDimension;
      }
      c.reportMainTabScroll(tabIndex, combinedPixels, viewportHeight);
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      send();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => send());
    }
  }
}

/// [DefaultTabController] **아래**에 두어 서브탭 전환 시 [NestedScrollFabScrollReporter]를 연결합니다.
class NestedScrollFabTabBinding extends StatefulWidget {
  const NestedScrollFabTabBinding({
    super.key,
    required this.reporter,
    required this.child,
  });

  final NestedScrollFabScrollReporter reporter;
  final Widget child;

  @override
  State<NestedScrollFabTabBinding> createState() =>
      _NestedScrollFabTabBindingState();
}

class _NestedScrollFabTabBindingState extends State<NestedScrollFabTabBinding> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.reporter.bindTabController(DefaultTabController.of(context));
  }

  @override
  void dispose() {
    widget.reporter.disposeTabBinding();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

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
  static const double fabRevealScrollViewportFraction = 0.3;
  // 히스테리시스: 보일 때/숨길 때 임계값을 분리해서 토글 떨림(연속 setState)을 줄입니다.
  static const double fabHideHysteresisViewportFraction = 0.22;

  int _activeMainTab = 0;
  final Map<int, VoidCallback> _mainTabHandlers = <int, VoidCallback>{};
  final Map<int, double> _lastMainScrollPixels = <int, double>{};
  final Map<int, double> _lastMainViewportHeight = <int, double>{};
  final List<VoidCallback> _routeHandlers = <VoidCallback>[];

  final ValueNotifier<bool> fabVisibleNotifier = ValueNotifier<bool>(false);

  bool _fabVisibilityFlushScheduled = false;
  bool? _fabVisibilityPending;
  int _logSeq = 0;

  static double _scrollRevealThreshold(double viewportHeight) {
    final double h = viewportHeight > 0 ? viewportHeight : 400;
    return h * fabRevealScrollViewportFraction;
  }

  static double _scrollHideThreshold(double viewportHeight) {
    final double h = viewportHeight > 0 ? viewportHeight : 400;
    return h * fabHideHysteresisViewportFraction;
  }

  /// 빌드 중([build] / [didChangeDependencies])에는 [ValueNotifier]를 건드리면
  /// `setState() or markNeedsBuild() called during build`가 날 수 있어 프레임 이후에 반영합니다.
  void _setFabVisible(bool visible) {
    // #region agent log
    _logSeq += 1;
    if (_logSeq % 50 == 0 &&
        SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      agentDebugNdjson(
        hypothesisId: "H3",
        location: "scroll_to_top_scope.dart:_setFabVisible",
        message: "_setFabVisible while scheduler not idle",
        data: <String, dynamic>{
          "visible": visible,
          "phase": SchedulerBinding.instance.schedulerPhase.name,
        },
      );
    }
    // #endregion
    _fabVisibilityPending = visible;
    if (_fabVisibilityFlushScheduled) return;
    _fabVisibilityFlushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fabVisibilityFlushScheduled = false;
      final bool next =
          _fabVisibilityPending ?? fabVisibleNotifier.value;
      _fabVisibilityPending = null;
      if (fabVisibleNotifier.value != next) {
        // #region agent log
        agentDebugNdjson(
          hypothesisId: "H3b",
          location: "scroll_to_top_scope.dart:_setFabVisible:pfc",
          message: "fabVisibleNotifier value commit",
          data: <String, dynamic>{"next": next},
        );
        // #endregion
        fabVisibleNotifier.value = next;
      }
    });
  }

  void setActiveMainTab(int index) {
    _activeMainTab = index;
    final double? y = _lastMainScrollPixels[index];
    final double? vh = _lastMainViewportHeight[index];
    if (y == null || vh == null) {
      _setFabVisible(false);
      return;
    }
    final bool cur = fabVisibleNotifier.value;
    final bool next = cur
        ? (y > _scrollHideThreshold(vh))
        : (y > _scrollRevealThreshold(vh));
    _setFabVisible(next);
  }

  /// [pixels]: 스크롤 오프셋(또는 웹뷰 `scrollY`). [viewportHeight]: 같은 축의 뷰포트 높이(스크롤뷰 뷰포트 또는 `innerHeight` 등).
  void reportMainTabScroll(
    int tabIndex,
    double pixels,
    double viewportHeight,
  ) {
    // #region agent log
    _logSeq += 1;
    if (_logSeq % 50 == 0 &&
        SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      agentDebugNdjson(
        hypothesisId: "H1",
        location: "scroll_to_top_scope.dart:reportMainTabScroll",
        message: "reportMainTabScroll during non-idle scheduler phase",
        data: <String, dynamic>{
          "tabIndex": tabIndex,
          "pixels": pixels,
          "viewportHeight": viewportHeight,
          "phase": SchedulerBinding.instance.schedulerPhase.name,
        },
      );
    }
    // #endregion
    _lastMainScrollPixels[tabIndex] = pixels;
    _lastMainViewportHeight[tabIndex] = viewportHeight;
    if (tabIndex != _activeMainTab) return;
    // 스크롤 리스너/노티는 transient/persistent 중에도 불려, 즉시 ValueNotifier를 건드리면
    // 빌드 예약이 겹치면서 build jank로 커질 수 있어 idle 프레임에서만 반영합니다.
    void decideAndSet() {
      final bool cur = fabVisibleNotifier.value;
      final bool next = cur
          ? (pixels > _scrollHideThreshold(viewportHeight))
          : (pixels > _scrollRevealThreshold(viewportHeight));
      _setFabVisible(next);
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      decideAndSet();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => decideAndSet());
    }
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
