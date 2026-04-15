import "dart:ui" show lerpDouble;

import "package:flutter/foundation.dart";
import "package:mio_notice/agent_debug_log.dart";
import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:mio_notice/screens/common_webview_screen.dart";
import "package:mio_notice/screens/main_navigation_screen.dart";
import "package:mio_notice/services/notice_manager.dart";
import "package:mio_notice/perf_flags.dart";
import "package:mio_notice/widgets/nested_scroll_refresh_indicator.dart";
import "package:mio_notice/widgets/scroll_to_top_scope.dart";
import "package:url_launcher/url_launcher.dart";

class _CtlListEntrance {
  static bool _playedOnce = false;
  static bool _scheduleEntranceEnd = false;

  static bool get shouldAnimateList => !kPerfLowRasterMode && !_playedOnce;
  static const int maxAnimatedItems = 8;

  static void scheduleEndEntranceAnimation() {
    if (_playedOnce || _scheduleEntranceEnd) return;
    _scheduleEntranceEnd = true;
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      _playedOnce = true;
    });
  }
}

class CtlScreen extends StatefulWidget {
  const CtlScreen({super.key});

  @override
  State<CtlScreen> createState() => _CtlScreenState();
}

class _CtlScreenState extends State<CtlScreen> {
  final ScrollController _outerScrollController = ScrollController();
  ScrollToTopCoordinator? _scrollToTopCoordinator;
  late final NestedScrollFabScrollReporter _nestedFabReporter =
      NestedScrollFabScrollReporter(
    tabIndex: MainNavTabIndex.ctl,
    outerController: _outerScrollController,
  );

  @override
  void initState() {
    super.initState();
    _outerScrollController.addListener(_nestedFabReporter.reportOuterScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ScrollToTopCoordinator? c = ScrollToTopScope.maybeOf(context);
    if (c != null) {
      _scrollToTopCoordinator = c;
      _nestedFabReporter.attachCoordinator(c);
      c.registerMainTab(MainNavTabIndex.ctl, _scrollContentToTop);
    }
    if (_outerScrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _nestedFabReporter.reportOuterScroll();
      });
    }
  }

  void _scrollContentToTop() {
    if (!_outerScrollController.hasClients) return;
    _outerScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _outerScrollController.removeListener(_nestedFabReporter.reportOuterScroll);
    _scrollToTopCoordinator?.unregisterMainTab(MainNavTabIndex.ctl);
    _outerScrollController.dispose();
    // 성능상 재진입 때마다 전체 리스트 entrance 애니메이션을 다시 돌리면 jank가 커져서 유지합니다.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double topPad = MediaQuery.paddingOf(context).top;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: NestedScrollView(
          controller: _outerScrollController,
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverOverlapAbsorber(
                handle:
                    NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                sliver: SliverPersistentHeader(
                  pinned: true,
                  delegate: _CtlCollapsingHeaderDelegate(
                    topPadding: topPad,
                    tabBar: TabBar(
                      controller: DefaultTabController.of(context),
                      indicatorColor: const Color(0xFF2962FF),
                      indicatorWeight: 3,
                      labelColor: const Color(0xFF2962FF),
                      unselectedLabelColor: Colors.grey,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      tabs: const [
                        Tab(text: "학습 프로그램"),
                        Tab(text: "센터 공지사항"),
                      ],
                    ),
                  ),
                ),
              ),
            ];
          },
          body: NotificationListener<ScrollNotification>(
            onNotification: _nestedFabReporter.handleInnerScrollNotification,
            child: NestedScrollFabTabBinding(
              reporter: _nestedFabReporter,
              child: const TabBarView(
                children: [
                  _CtlListTab(isProgram: true),
                  _CtlListTab(isProgram: false),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CtlCollapsingHeaderDelegate extends SliverPersistentHeaderDelegate {
  _CtlCollapsingHeaderDelegate({
    required this.topPadding,
    required this.tabBar,
  });
  // #region agent log (H7A)
  static int _h7Count = 0;
  static int _h7WinStart = 0;
  // #endregion

  final double topPadding;
  final TabBar tabBar;

  static const double _heroBody = 200;
  static const double _collapsedBar = 52;

  double get _tabBarHeight => tabBar.preferredSize.height;

  @override
  double get maxExtent => topPadding + _heroBody + _tabBarHeight;

  @override
  double get minExtent => topPadding + _collapsedBar + _tabBarHeight;

  static const LinearGradient _headerGradient = LinearGradient(
    colors: [Color(0xFF2962FF), Color(0xFF448AFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // #region agent log (H7A)
    final int _h7Now = DateTime.now().millisecondsSinceEpoch;
    if (_h7WinStart == 0) _h7WinStart = _h7Now;
    _h7Count++;
    if (_h7Now - _h7WinStart >= 2000) {
      agentDebugNdjson(
        hypothesisId: "H7A",
        location: "ctl_screen.dart:_CtlCollapsingHeaderDelegate:build",
        message: "header build frequency",
        data: <String, dynamic>{"buildsIn2sec": _h7Count, "windowMs": _h7Now - _h7WinStart},
      );
      _h7Count = 0;
      _h7WinStart = _h7Now;
    }
    // #endregion
    final double extent =
        (maxExtent - shrinkOffset).clamp(minExtent, maxExtent);
    final double range = maxExtent - minExtent;
    final double t = range > 0 ? (shrinkOffset / range).clamp(0.0, 1.0) : 0.0;
    final double u = Curves.easeInOut.transform(t);
    final double heroH = extent - _tabBarHeight;
    // LayoutBuilder removed: ih = heroH - topPadding (SafeArea subtracts status bar)
    final double ih = heroH - topPadding;
    final double titleSize = lerpDouble(24, 17, u)!;
    final double titleLeft = lerpDouble(20, 50, u)!;
    const double bottomBlock = 20 + 13 + 6 + 24;
    final double expandedTitleTop = (ih - bottomBlock).clamp(0.0, ih);
    final double collapsedTitleTop = (ih - titleSize * 1.15) / 2;
    final double titleTop = lerpDouble(expandedTitleTop, collapsedTitleTop, u)!;
    final double subtitleOpacity = (1.0 - u * 1.35).clamp(0.0, 1.0);

    return SizedBox(
      height: extent,
      width: double.infinity,
      child: ClipRect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: heroH,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(gradient: _headerGradient),
                  ),
                  SafeArea(
                    bottom: false,
                    minimum: EdgeInsets.zero,
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned(
                          left: 0,
                          top: 0,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => MainNavigationScreen
                                  .scaffoldKey.currentState
                                  ?.openDrawer(),
                              splashColor:
                                  Colors.white.withValues(alpha: 0.35),
                              highlightColor:
                                  Colors.white.withValues(alpha: 0.14),
                              child: const Padding(
                                padding: EdgeInsets.all(10),
                                child: Icon(
                                  Icons.menu_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: titleLeft,
                          top: titleTop,
                          right: 12,
                          child: Text(
                            "교수학습센터 (CTL)",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: titleSize,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ),
                        if (subtitleOpacity > 0.02)
                          Positioned(
                            left: 20,
                            top: titleTop + titleSize * 0.95 + 6,
                            right: 16,
                            child: IgnorePointer(
                              child: Text(
                                "CTL의 다양한 학습 지원 프로그램을 만나보세요",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white
                                      .withValues(alpha: 0.7 * subtitleOpacity),
                                  fontSize: 13,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Material(
              color: Colors.white,
              elevation: overlapsContent ? 0.5 : 0,
              shadowColor: Colors.black12,
              child: SizedBox(
                height: _tabBarHeight,
                child: tabBar,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CtlCollapsingHeaderDelegate old) {
    return topPadding != old.topPadding || tabBar != old.tabBar;
  }
}

class _CtlListTab extends StatefulWidget {
  final bool isProgram;
  const _CtlListTab({required this.isProgram});
  @override
  State<_CtlListTab> createState() => _CtlListTabState();
}

class _CtlListTabState extends State<_CtlListTab> {
  late Future<List<Map<String, dynamic>>> _ctlFuture;
  bool get _lowRaster =>
      kPerfLowRasterMode || defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _ctlFuture = NoticeManager().getNotices(boardId: widget.isProgram ? "ctl_programs" : "ctl_notice");
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _ctlFuture = NoticeManager().getNotices(boardId: widget.isProgram ? "ctl_programs" : "ctl_notice", forceRefresh: true);
    });
    await _ctlFuture;
  }

  @override
  Widget build(BuildContext context) {
    return NestedScrollRefreshIndicator(
      onRefresh: _handleRefresh,
      color: const Color(0xFF2962FF),
      backgroundColor: Colors.white,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ctlFuture,
        builder: (context, snapshot) {
          return CustomScrollView(
            primary: true,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverOverlapInjector(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                  context,
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else ..._buildCtlSlivers(context, snapshot.data ?? []),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildCtlSlivers(
    BuildContext context,
    List<Map<String, dynamic>> items,
  ) {
    if (items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 48),
              Text(
                "등록된 항목이 없습니다.",
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              if (index == 0 && _CtlListEntrance.shouldAnimateList) {
                _CtlListEntrance.scheduleEndEntranceAnimation();
              }
              final data = items[index];
              final Widget card = RepaintBoundary(
                child: _buildCtlCard(context, data),
              );
              final bool animate = _CtlListEntrance.shouldAnimateList &&
                  index < _CtlListEntrance.maxAnimatedItems;
              if (animate) {
                return card
                    .animate()
                    .fadeIn(
                      delay: (index * 24).clamp(0, 240).ms,
                      duration: 240.ms,
                    );
              }
              return card;
            },
            childCount: items.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildCtlCard(BuildContext context, Map<String, dynamic> data) {
    final String title = data["title"] ?? "";
    final String date = data["reg_date"] ?? data["date"] ?? "";
    final String opPeriod = data["op_period"] ?? "";
    final String url = data["link"] ?? "";
    final String status = data["status"] ?? "진행중";
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: _lowRaster ? 0 : 2,
        shadowColor: _lowRaster ? Colors.transparent : Colors.black12,
        clipBehavior: _lowRaster ? Clip.hardEdge : Clip.none,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            if (url.isEmpty) return;
            if (kIsWeb) {
              await launchUrl(Uri.parse(url), webOnlyWindowName: "_blank");
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (_) => CommonWebViewScreen(url: url, title: title)));
            }
          },
          child: (_lowRaster)
              ? Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 4,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2962FF),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 48, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (widget.isProgram)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8EAF6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    status,
                                    style: const TextStyle(
                                      color: Color(0xFF2962FF),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              const Text(
                                "CTL",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF222222),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (widget.isProgram && opPeriod.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.timer_outlined,
                                      size: 14, color: Color(0xFF2962FF)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      "진행: $opPeriod",
                                      style: const TextStyle(
                                        color: Color(0xFF2962FF),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined,
                                  size: 14, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                "신청: $date",
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 13),
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Positioned(
                      right: 12,
                      top: 0,
                      bottom: 0,
                      child: Icon(Icons.chevron_right,
                          color: Colors.grey, size: 24),
                    ),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.hardEdge,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 4,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2962FF),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12),
                              bottomLeft: Radius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 48, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (widget.isProgram)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8EAF6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      status,
                                      style: const TextStyle(
                                        color: Color(0xFF2962FF),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                const Text(
                                  "CTL",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF222222),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (widget.isProgram && opPeriod.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.timer_outlined,
                                        size: 14, color: Color(0xFF2962FF)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        "진행: $opPeriod",
                                        style: const TextStyle(
                                          color: Color(0xFF2962FF),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  "신청: $date",
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 13),
                                )
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Positioned(
                        right: 12,
                        top: 0,
                        bottom: 0,
                        child: Icon(Icons.chevron_right,
                            color: Colors.grey, size: 24),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
