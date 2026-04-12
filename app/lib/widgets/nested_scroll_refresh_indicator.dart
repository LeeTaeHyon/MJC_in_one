import "package:flutter/material.dart";

/// [NestedScrollView] 본문([TabBarView] 등)에서 [RefreshIndicator]가
/// 고정 헤더 뒤에 가려지지 않도록, 겹침 높이([SliverOverlapAbsorberHandle.layoutExtent])만큼
/// 인디케이터를 아래로 옮깁니다.
class NestedScrollRefreshIndicator extends StatelessWidget {
  const NestedScrollRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color,
    this.backgroundColor,
    this.strokeWidth,
    this.displacement = 16,
  });

  final RefreshCallback onRefresh;
  final Widget child;
  final Color? color;
  final Color? backgroundColor;
  final double? strokeWidth;
  final double displacement;

  @override
  Widget build(BuildContext context) {
    final handle = NestedScrollView.sliverOverlapAbsorberHandleFor(context);
    return ListenableBuilder(
      listenable: handle,
      builder: (context, _) {
        final extent = handle.layoutExtent;
        final top = MediaQuery.paddingOf(context).top;
        const double collapsedBar = 52;
        const double tabBarH = 48;
        final fallback = top + collapsedBar + tabBarH;
        final edgeOffset =
            (extent != null && extent > 0) ? extent : fallback;
        return RefreshIndicator(
          onRefresh: onRefresh,
          color: color,
          backgroundColor: backgroundColor,
          strokeWidth: strokeWidth ?? RefreshProgressIndicator.defaultStrokeWidth,
          edgeOffset: edgeOffset,
          displacement: displacement,
          child: child,
        );
      },
    );
  }
}
