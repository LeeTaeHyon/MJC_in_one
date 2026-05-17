import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:mjc_in_one/debug/scroll_fab_debug.dart";
import "package:mjc_in_one/theme/app_colors.dart";
import "package:mjc_in_one/widgets/safe_tooltip.dart";
import "package:mjc_in_one/widgets/scroll_to_top_scope.dart";

/// [ScrollToTopCoordinator]에 등록된 대상으로 스크롤·웹뷰를 맨 위로 올립니다.
/// [ValueListenableBuilder]는 [fabVisibleNotifier] 갱신이 프레임 콜백에서만 일어날 때
/// 빌드 중 재진입 없이 안전하게 리빌드됩니다.
///
/// [debugTag] — debug 빌드 전용. `mainNav`(초록·M) / `pushed`(주황·P)로 슬롯 구분.
class ScrollToTopFab extends StatefulWidget {
  const ScrollToTopFab({super.key, this.debugTag});

  /// [ScrollFabDebug]에서 FAB 슬롯을 구분할 때만 사용합니다.
  final String? debugTag;

  @override
  State<ScrollToTopFab> createState() => _ScrollToTopFabState();
}

class _ScrollToTopFabState extends State<ScrollToTopFab> {
  @override
  void dispose() {
    if (ScrollFabDebug.enabled && widget.debugTag != null) {
      ScrollFabDebug.reportFabSlot(tag: widget.debugTag!, visible: false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ScrollToTopCoordinator coordinator = ScrollToTopScope.of(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String? debugTag = widget.debugTag;
    final bool debug = ScrollFabDebug.enabled && debugTag != null;
    final Color? debugBorder = debug
        ? (debugTag == "mainNav"
            ? Colors.lightGreenAccent
            : Colors.deepOrange)
        : null;

    return ValueListenableBuilder<bool>(
      valueListenable: coordinator.fabVisibleNotifier,
      builder: (BuildContext context, bool visible, Widget? child) {
        if (ScrollFabDebug.enabled && debugTag != null) {
          ScrollFabDebug.reportFabSlot(tag: debugTag, visible: visible);
        }
        if (!visible) return const SizedBox.shrink();
        return RepaintBoundary(
          child: Material(
            elevation: 6,
            shadowColor: Colors.black.withValues(alpha: isDark ? 0.50 : 0.26),
            shape: const CircleBorder(),
            color: AppColors.primary,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => coordinator.scrollToTop(),
              splashColor: Colors.white.withValues(alpha: 0.28),
              highlightColor: Colors.white.withValues(alpha: 0.14),
              child: SafeTooltip(
                message: debug ? "맨 위로 ($debugTag)" : "맨 위로",
                child: Semantics(
                  button: true,
                  label: "맨 위로 스크롤",
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        if (debug && debugBorder != null)
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: debugBorder,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                        const Center(
                          child: Icon(
                            Icons.vertical_align_top_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        if (debug)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 16,
                              height: 16,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: debugBorder,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                              child: Text(
                                debugTag == "mainNav" ? "M" : "P",
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
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

/// 설정·웹뷰 등 [Navigator.push]된 전체 화면용. [Scaffold.body] [Stack] 맨 위에 둡니다.
class PushedRouteScrollToTopLayer extends StatelessWidget {
  const PushedRouteScrollToTopLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 14,
      bottom: MediaQuery.paddingOf(context).bottom + 16,
      child: ScrollToTopFab(
        debugTag: ScrollFabDebug.enabled ? "pushed" : null,
      ),
    );
  }
}
