import "package:flutter/material.dart";

/// 하단 탭·공지 서브탭 등 인덱스 기반 화면 전환용 슬라이드+페이드 애니메이션.
abstract final class MjcDirectionalScreenTransition {
  static const Duration duration = Duration(milliseconds: 280);
  static const double slideDistance = 0.1;

  static int directionForStep(int fromIndex, int toIndex) {
    return toIndex > fromIndex ? 1 : -1;
  }

  static Widget transitionBuilder({
    required Widget child,
    required Animation<double> animation,
    required Object activeKey,
    required int direction,
  }) {
    final bool isIncoming = child.key == ValueKey<Object>(activeKey);
    final CurvedAnimation curved = CurvedAnimation(
      parent: animation,
      curve: isIncoming ? Curves.easeOutCubic : Curves.easeInCubic,
    );
    final Animation<double> opacity =
        Tween<double>(begin: 0, end: 1).animate(curved);
    final Animation<Offset> offset = isIncoming
        ? Tween<Offset>(
            begin: Offset(direction * slideDistance, 0),
            end: Offset.zero,
          ).animate(curved)
        : Tween<Offset>(
            begin: Offset.zero,
            end: Offset(-direction * slideDistance, 0),
          ).animate(curved);
    return FadeTransition(
      opacity: opacity,
      child: SlideTransition(position: offset, child: child),
    );
  }

  static Widget animatedSwitcher({
    required Object activeKey,
    required int direction,
    required Widget child,
  }) {
    return ClipRect(
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (Widget c, Animation<double> a) => transitionBuilder(
          child: c,
          animation: a,
          activeKey: activeKey,
          direction: direction,
        ),
        child: KeyedSubtree(
          key: ValueKey<Object>(activeKey),
          child: child,
        ),
      ),
    );
  }
}
