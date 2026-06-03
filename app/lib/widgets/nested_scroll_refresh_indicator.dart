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
    this.tabBarHeight = 48,
    this.includeNestedHeaderOffset = true,
    this.notificationPredicate = defaultScrollNotificationPredicate,
  });

  final RefreshCallback onRefresh;
  final Widget child;
  final Color? color;
  final Color? backgroundColor;
  final double? strokeWidth;
  final double displacement;
  /// [NestedScrollView] 헤더 [TabBar] 높이. 통합 리스트처럼 헤더 탭이 없으면 0.
  final double tabBarHeight;
  /// false이면 [SliverOverlapAbsorber] spacer 아래 inner [TabBarView] 페이지용.
  final bool includeNestedHeaderOffset;
  final ScrollNotificationPredicate notificationPredicate;

  @override
  Widget build(BuildContext context) {
    final double edgeOffset;
    if (includeNestedHeaderOffset) {
      final top = MediaQuery.paddingOf(context).top;
      const double collapsedBar = 52;
      edgeOffset = top + collapsedBar + tabBarHeight;
    } else {
      edgeOffset = 0;
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: color,
      backgroundColor: backgroundColor,
      strokeWidth: strokeWidth ?? RefreshProgressIndicator.defaultStrokeWidth,
      edgeOffset: edgeOffset,
      displacement: displacement,
      notificationPredicate: notificationPredicate,
      child: child,
    );
  }
}
