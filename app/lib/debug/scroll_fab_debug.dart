import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/scheduler.dart";
import "package:mjc_in_one/debug/app_debug_flags.dart";

/// 맨 위로 FAB 중복 디버깅용 (debug/profile with asserts 빌드에서만 동작).
///
/// on/off: [app_debug_flags.dart] — `kAppDevFeaturesEnabled`(일괄) +
/// `kScrollFabDebugEnabled`(이 기능만).
abstract final class ScrollFabDebug {
  ScrollFabDebug._();

  static final ValueNotifier<ScrollFabDebugSnapshot> snapshot =
      ValueNotifier<ScrollFabDebugSnapshot>(ScrollFabDebugSnapshot.empty);

  static final List<String> _routeStack = <String>[];
  static final List<String> _recentEvents = <String>[];
  static const int _maxRecentEvents = 12;

  static bool _flushScheduled = false;
  static ScrollFabDebugSnapshot Function(ScrollFabDebugSnapshot)? _pendingPatch;

  static bool get enabled => AppDevFeatures.scrollFabDebug;

  static bool get logToConsole => enabled;

  static final NavigatorObserver navigatorObserver = _ScrollFabNavObserver();

  static void reportCanPop(bool canPop) {
    if (!enabled) return;
    _schedulePatch((ScrollFabDebugSnapshot s) => s.copyWith(canPop: canPop));
  }

  static void reportFabSlot({required String tag, required bool visible}) {
    if (!enabled) return;
    _schedulePatch((ScrollFabDebugSnapshot s) {
      final Map<String, bool> slots = Map<String, bool>.of(s.fabSlotVisible);
      slots[tag] = visible;
      return s.copyWith(fabSlotVisible: slots);
    });
  }

  static void reportCoordinator({
    required bool fabVisible,
    required int activeMainTab,
    required int routeHandlersCount,
    required List<int> mainTabHandlerKeys,
  }) {
    if (!enabled) return;
    _schedulePatch(
      (ScrollFabDebugSnapshot s) => s.copyWith(
        fabVisible: fabVisible,
        activeMainTab: activeMainTab,
        routeHandlersCount: routeHandlersCount,
        mainTabHandlerKeys: mainTabHandlerKeys,
      ),
    );
  }

  static void _onNavEvent(String kind, Route<dynamic> route) {
    if (!enabled) return;
    final String label = _routeLabel(route);
    if (kind == "push") {
      _routeStack.add(label);
    } else if (kind == "pop" && _routeStack.isNotEmpty) {
      _routeStack.removeLast();
    } else if (kind == "remove") {
      _routeStack.remove(label);
    } else if (kind == "replace") {
      if (_routeStack.isEmpty) {
        _routeStack.add(label);
      } else {
        _routeStack[_routeStack.length - 1] = label;
      }
    }

    final NavigatorState? nav = route.navigator;
    final bool canPop = nav?.canPop() ?? false;
    final String line =
        "${DateTime.now().toIso8601String().substring(11, 19)} "
        "$kind $label canPop=$canPop depth=${_routeStack.length}";
    _recentEvents.insert(0, line);
    if (_recentEvents.length > _maxRecentEvents) {
      _recentEvents.removeLast();
    }
    if (logToConsole) {
      debugPrint("[ScrollFab] $line");
      if (_routeStack.isNotEmpty) {
        debugPrint("[ScrollFab] stack: ${_routeStack.join(" → ")}");
      }
    }

    _schedulePatch(
      (ScrollFabDebugSnapshot s) => s.copyWith(
        canPop: canPop,
        routeStack: List<String>.unmodifiable(_routeStack),
        lastNavEvent: line,
        recentNavEvents: List<String>.unmodifiable(_recentEvents),
      ),
    );
  }

  static String _routeLabel(Route<dynamic> route) {
    final String? name = route.settings.name;
    if (name != null && name.isNotEmpty) return name;
    return route.runtimeType.toString();
  }

  /// [ValueNotifier] 갱신은 빌드·레이아웃 중에 하면 `markNeedsBuild during build`가 납니다.
  static void _schedulePatch(
    ScrollFabDebugSnapshot Function(ScrollFabDebugSnapshot) fn,
  ) {
    if (!enabled) return;

    final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      _commit(fn(snapshot.value));
      return;
    }

    final ScrollFabDebugSnapshot Function(ScrollFabDebugSnapshot)? prev =
        _pendingPatch;
    _pendingPatch = prev == null
        ? fn
        : (ScrollFabDebugSnapshot s) => fn(prev(s));

    if (_flushScheduled) return;
    _flushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _flushScheduled = false;
      final ScrollFabDebugSnapshot Function(ScrollFabDebugSnapshot)? pending =
          _pendingPatch;
      _pendingPatch = null;
      if (pending == null) return;
      _commit(pending(snapshot.value));
    });
  }

  static void _commit(ScrollFabDebugSnapshot next) {
    if (logToConsole &&
        next.duplicateSuspected &&
        !snapshot.value.duplicateSuspected) {
      debugPrint(
        "[ScrollFab] ⚠ duplicate suspected: mainNav+pushed FAB both visible "
        "(${next.fabSlotVisible})",
      );
    }
    snapshot.value = next;
  }
}

@immutable
class ScrollFabDebugSnapshot {
  const ScrollFabDebugSnapshot({
    required this.canPop,
    required this.fabVisible,
    required this.activeMainTab,
    required this.routeHandlersCount,
    required this.mainTabHandlerKeys,
    required this.routeStack,
    required this.fabSlotVisible,
    required this.lastNavEvent,
    required this.recentNavEvents,
  });

  static const ScrollFabDebugSnapshot empty = ScrollFabDebugSnapshot(
    canPop: false,
    fabVisible: false,
    activeMainTab: 0,
    routeHandlersCount: 0,
    mainTabHandlerKeys: <int>[],
    routeStack: <String>[],
    fabSlotVisible: <String, bool>{},
    lastNavEvent: "",
    recentNavEvents: <String>[],
  );

  final bool canPop;
  final bool fabVisible;
  final int activeMainTab;
  final int routeHandlersCount;
  final List<int> mainTabHandlerKeys;
  final List<String> routeStack;
  final Map<String, bool> fabSlotVisible;
  final String lastNavEvent;
  final List<String> recentNavEvents;

  bool get duplicateSuspected {
    if (!fabVisible) return false;
    final bool mainNavOn = fabSlotVisible["mainNav"] == true;
    final bool pushedOn = fabSlotVisible["pushed"] == true;
    return mainNavOn && pushedOn;
  }

  ScrollFabDebugSnapshot copyWith({
    bool? canPop,
    bool? fabVisible,
    int? activeMainTab,
    int? routeHandlersCount,
    List<int>? mainTabHandlerKeys,
    List<String>? routeStack,
    Map<String, bool>? fabSlotVisible,
    String? lastNavEvent,
    List<String>? recentNavEvents,
  }) {
    return ScrollFabDebugSnapshot(
      canPop: canPop ?? this.canPop,
      fabVisible: fabVisible ?? this.fabVisible,
      activeMainTab: activeMainTab ?? this.activeMainTab,
      routeHandlersCount: routeHandlersCount ?? this.routeHandlersCount,
      mainTabHandlerKeys: mainTabHandlerKeys ?? this.mainTabHandlerKeys,
      routeStack: routeStack ?? this.routeStack,
      fabSlotVisible: fabSlotVisible ?? this.fabSlotVisible,
      lastNavEvent: lastNavEvent ?? this.lastNavEvent,
      recentNavEvents: recentNavEvents ?? this.recentNavEvents,
    );
  }
}

/// 화면 좌상단에 스냅샷을 표시합니다.
class ScrollFabDebugOverlay extends StatelessWidget {
  const ScrollFabDebugOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    if (!ScrollFabDebug.enabled) return const SizedBox.shrink();

    return ValueListenableBuilder<ScrollFabDebugSnapshot>(
      valueListenable: ScrollFabDebug.snapshot,
      builder: (BuildContext context, ScrollFabDebugSnapshot s, Widget? _) {
        final bool dup = s.duplicateSuspected;
        final String mainNavFab =
            s.fabSlotVisible["mainNav"] == true ? "ON" : "off";
        final String pushedFab =
            s.fabSlotVisible["pushed"] == true ? "ON" : "off";

        return Positioned(
          top: MediaQuery.paddingOf(context).top + 4,
          left: 4,
          right: 72,
          child: IgnorePointer(
            child: Material(
              color: dup
                  ? Colors.red.withValues(alpha: 0.88)
                  : Colors.black.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: DefaultTextStyle(
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    height: 1.25,
                    fontFamily: "monospace",
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        dup ? "ScrollFab ⚠ DUPLICATE?" : "ScrollFab debug",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: dup ? Colors.yellowAccent : Colors.white,
                        ),
                      ),
                      Text("canPop: ${s.canPop}  fabVisible: ${s.fabVisible}"),
                      Text(
                        "FAB mainNav(M/초록): $mainNavFab  "
                        "pushed(P/주황): $pushedFab",
                      ),
                      Text(
                        "activeTab: ${s.activeMainTab}  "
                        "routeHandlers: ${s.routeHandlersCount}  "
                        "mainTabs: ${s.mainTabHandlerKeys}",
                      ),
                      if (s.routeStack.isNotEmpty)
                        Text("stack: ${s.routeStack.join(" → ")}"),
                      if (s.lastNavEvent.isNotEmpty)
                        Text("last: ${s.lastNavEvent}"),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

final class _ScrollFabNavObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    ScrollFabDebug._onNavEvent("push", route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    ScrollFabDebug._onNavEvent("pop", route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    ScrollFabDebug._onNavEvent("remove", route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      ScrollFabDebug._onNavEvent("replace", newRoute);
    }
  }
}
