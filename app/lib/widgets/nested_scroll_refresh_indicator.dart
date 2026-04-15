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
    // Pass child as ListenableBuilder.child so it is NOT rebuilt when the
    // overlap handle fires (which happens on every scroll frame). Only the
    // RefreshIndicator wrapper is rebuilt; the heavy CustomScrollView subtree
    // is reused as-is.
    return ListenableBuilder(
      listenable: handle,
      child: child,
      builder: (context, theChild) {
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
          child: theChild!,
        );
      },
    );
  }
}
