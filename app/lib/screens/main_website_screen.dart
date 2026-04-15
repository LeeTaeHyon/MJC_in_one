import "dart:ui" show lerpDouble;

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:mio_notice/screens/common_webview_screen.dart";
import "package:mio_notice/screens/main_navigation_screen.dart";
import "package:mio_notice/services/notice_manager.dart";
import "package:mio_notice/perf_flags.dart";
import "package:mio_notice/widgets/nested_scroll_refresh_indicator.dart";
import "package:mio_notice/widgets/scroll_to_top_scope.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";
import "package:mio_notice/agent_debug_log.dart";

/// 스크롤/전환 중 jank를 줄이기 위해 entrance stagger는 앱 실행 동안 1회만 재생.
class _MainWebsiteListEntrance {
  static bool _playedOnce = false;
  static bool _scheduleEntranceEnd = false;

  static bool get shouldAnimateList => !kPerfLowRasterMode && !_playedOnce;
  static const int maxAnimatedItems = 8;

  /// 첫 리스트 stagger 끝난 뒤에만 끔 (도중 리빌드로 애니메이션이 끊기지 않게).
  static void scheduleEndEntranceAnimation() {
    if (_playedOnce || _scheduleEntranceEnd) return;
    _scheduleEntranceEnd = true;
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      _playedOnce = true;
    });
  }
}

/// 명지전문대학 공식 홈페이지의 공지사항을 탭별로 보여주는 화면입니다.
class MainWebsiteScreen extends StatefulWidget {
  const MainWebsiteScreen({super.key});

  @override
  State<MainWebsiteScreen> createState() => _MainWebsiteScreenState();
}

class _MainWebsiteScreenState extends State<MainWebsiteScreen> {
  final ScrollController _outerScrollController = ScrollController();
  ScrollToTopCoordinator? _scrollToTopCoordinator;
  late final NestedScrollFabScrollReporter _nestedFabReporter =
      NestedScrollFabScrollReporter(
    tabIndex: MainNavTabIndex.mainSite,
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
      c.registerMainTab(MainNavTabIndex.mainSite, _scrollContentToTop);
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
    _scrollToTopCoordinator?.unregisterMainTab(MainNavTabIndex.mainSite);
    _outerScrollController.dispose();
    // 성능상 재진입 때마다 전체 리스트 entrance 애니메이션을 다시 돌리면 jank가 커져서 유지합니다.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double topPad = MediaQuery.paddingOf(context).top;
    return DefaultTabController(
      length: 3,
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
                  delegate: _MainWebsiteCollapsingHeaderDelegate(
                    topPadding: topPad,
                    tabBar: TabBar(
                      controller: DefaultTabController.of(context),
                      indicatorColor: const Color(0xFF003FB4),
                      indicatorWeight: 3,
                      labelColor: const Color(0xFF003FB4),
                      unselectedLabelColor: Colors.grey,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      tabs: const [
                        Tab(text: "공지사항"),
                        Tab(text: "학사공지"),
                        Tab(text: "장학공지"),
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
              child: TabBarView(
                children: <Widget>[
                  _NoticeListTab(boardId: "main_notice"),
                  _NoticeListTab(boardId: "main_academic"),
                  _NoticeListTab(boardId: "main_scholarship"),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 홈 히어로와 같이 스크롤에 따라 상단 영역이 접히고, 탭 바는 아래에 고정됩니다.
class _MainWebsiteCollapsingHeaderDelegate
    extends SliverPersistentHeaderDelegate {
  _MainWebsiteCollapsingHeaderDelegate({
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
    colors: [Color(0xFF003FB4), Color(0xFF0056D2)],
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
        location: "main_website_screen.dart:_MainWebsiteCollapsingHeaderDelegate:build",
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
    // LayoutBuilder removed: c.maxHeight == heroH - topPadding (SafeArea subtracts status bar)
    final double ih = heroH - topPadding;
    final double titleSize = lerpDouble(28, 19, u)!;
    final double titleLeft = lerpDouble(20, 50, u)!;
    const double bottomBlock = 20 + 14 + 6 + 28;
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
                  const DecoratedBox(decoration: BoxDecoration(gradient: _headerGradient)),
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
                            "메인 홈페이지",
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
                                "최신 공지사항을 확인하세요",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white
                                      .withValues(alpha: 0.7 * subtitleOpacity),
                                  fontSize: 14,
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
  bool shouldRebuild(covariant _MainWebsiteCollapsingHeaderDelegate old) {
    return topPadding != old.topPadding || tabBar != old.tabBar;
  }
}

class _NoticeListTab extends StatefulWidget {
  final String boardId;
  const _NoticeListTab({required this.boardId});

  @override
  State<_NoticeListTab> createState() => _NoticeListTabState();
}

class _NoticeListTabState extends State<_NoticeListTab> {
  Set<String> _readNoticeIds = {};
  late Future<List<Map<String, dynamic>>> _noticeFuture;
  int _h6WindowStartMs = DateTime.now().millisecondsSinceEpoch;
  int _h6BuildCalls = 0;
  int _h6BuildUsSum = 0;
  int _h6BuildUsMax = 0;
  // #region agent log (H7B)
  int _h7bCount = 0;
  int _h7bWinStart = 0;
  // #endregion

  @override
  void initState() {
    super.initState();
    _loadReadHistory();
    _noticeFuture = NoticeManager().getNotices(boardId: widget.boardId);
  }

  Future<void> _loadReadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _readNoticeIds = (prefs.getStringList("read_notices_${widget.boardId}") ?? []).toSet();
    });
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _noticeFuture = NoticeManager().getNotices(
        boardId: widget.boardId, 
        forceRefresh: true
      );
    });
    await _noticeFuture;
  }

  Future<void> _markAsRead(String id) async {
    if (_readNoticeIds.contains(id)) return;
    
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _readNoticeIds.add(id);
    });
    await prefs.setStringList("read_notices_${widget.boardId}", _readNoticeIds.toList());
  }

  @override
  Widget build(BuildContext context) {
    // #region agent log (H7B)
    final int _h7bNow = DateTime.now().millisecondsSinceEpoch;
    if (_h7bWinStart == 0) _h7bWinStart = _h7bNow;
    _h7bCount++;
    if (_h7bNow - _h7bWinStart >= 2000) {
      agentDebugNdjson(
        hypothesisId: "H7B",
        location: "main_website_screen.dart:_NoticeListTabState:build",
        message: "noticeListTab rebuild frequency",
        data: <String, dynamic>{"boardId": widget.boardId, "rebuildsIn2sec": _h7bCount, "windowMs": _h7bNow - _h7bWinStart},
      );
      _h7bCount = 0;
      _h7bWinStart = _h7bNow;
    }
    // #endregion
    return NestedScrollRefreshIndicator(
      onRefresh: _handleRefresh,
      color: const Color(0xFF003FB4),
      backgroundColor: Colors.white,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _noticeFuture,
        builder: (context, snapshot) {
          final Widget scrollable = CustomScrollView(
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
              else ..._buildNoticeSlivers(context, snapshot.data ?? []),
            ],
          );

          return scrollable;
        },
      ),
    );
  }

  List<Widget> _buildNoticeSlivers(
    BuildContext context,
    List<Map<String, dynamic>> docs,
  ) {
    if (docs.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 48),
              Text(
                "표시할 공지가 없습니다.",
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
              // #region agent log
              final Stopwatch sw = Stopwatch()..start();
              // #endregion
              if (index == 0 && _MainWebsiteListEntrance.shouldAnimateList) {
                _MainWebsiteListEntrance.scheduleEndEntranceAnimation();
              }
              final data = docs[index];
              final String id = data["id"] ?? "";
              final bool isRead = _readNoticeIds.contains(id);
              final String url = data["url"] ?? "";

              final Widget tile = _ScaleFeedbackButton(
                onTap: () async {
                  await _markAsRead(id);
                  if (url.isEmpty) return;
                  if (kIsWeb) {
                    await launchUrl(Uri.parse(url), webOnlyWindowName: "_blank");
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => CommonWebViewScreen(
                          url: url,
                          title: data["title"] ?? "공지사항",
                        ),
                      ),
                    );
                  }
                },
                child: _buildNoticeListItem(
                  context,
                  data,
                  id,
                  isRead,
                  () async {
                    await _markAsRead(id);
                    if (url.isEmpty) return;
                    if (kIsWeb) {
                      await launchUrl(
                        Uri.parse(url),
                        webOnlyWindowName: "_blank",
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => CommonWebViewScreen(
                            url: url,
                            title: data["title"] ?? "공지사항",
                          ),
                        ),
                      );
                    }
                  },
                ),
              );
              final Widget paintIsolated = RepaintBoundary(child: tile);
              final bool animate = _MainWebsiteListEntrance.shouldAnimateList &&
                  index < _MainWebsiteListEntrance.maxAnimatedItems;
              final Widget out = animate
                  ? paintIsolated.animate().fadeIn(
                        delay: (index * 24).clamp(0, 240).ms,
                        duration: 240.ms,
                      )
                  : paintIsolated;

              // #region agent log
              sw.stop();
              final int us = sw.elapsedMicroseconds;
              _h6BuildCalls += 1;
              _h6BuildUsSum += us;
              if (us > _h6BuildUsMax) _h6BuildUsMax = us;
              final int nowMs = DateTime.now().millisecondsSinceEpoch;
              final int windowMs = nowMs - _h6WindowStartMs;
              if (index == 0 || windowMs >= 2000) {
                agentDebugNdjson(
                  hypothesisId: "H6",
                  location: "main_website_screen.dart:_NoticeListTab:SliverChildBuilderDelegate",
                  message: "notice list item build cost summary",
                  data: <String, dynamic>{
                    "boardId": widget.boardId,
                    "windowMs": windowMs,
                    "buildCalls": _h6BuildCalls,
                    "avgUs": _h6BuildCalls == 0 ? 0 : (_h6BuildUsSum / _h6BuildCalls).round(),
                    "maxUs": _h6BuildUsMax,
                    "docsLen": docs.length,
                    "kPerfLowRasterMode": kPerfLowRasterMode,
                  },
                );
                _h6WindowStartMs = nowMs;
                _h6BuildCalls = 0;
                _h6BuildUsSum = 0;
                _h6BuildUsMax = 0;
              }
              // #endregion

              return out;
            },
            childCount: docs.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildNoticeListItem(BuildContext context, Map<String, dynamic> data, String id, bool isRead, VoidCallback onTap) {
    final String title = data["title"] ?? "";
    final String dateStr = data["date"] ?? "";
    final String type = data["category"] ?? "공지";
    final Color mainColor = isRead ? Colors.grey : const Color(0xFF003FB4);
    final bool lowRaster = kPerfLowRasterMode;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isRead ? const Color(0xFFF1F3F4) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: (isRead || lowRaster) ? 0 : 2,
        shadowColor: lowRaster ? Colors.transparent : Colors.black12,
        clipBehavior: lowRaster ? Clip.hardEdge : Clip.none,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: (lowRaster)
              ? Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: mainColor,
                          borderRadius: const BorderRadius.only(
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isRead
                                  ? Colors.grey.shade200
                                  : const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              type,
                              style: TextStyle(
                                color: isRead
                                    ? Colors.grey
                                    : const Color(0xFF1976D2),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  isRead ? FontWeight.normal : FontWeight.bold,
                              color: isRead
                                  ? Colors.grey.shade600
                                  : const Color(0xFF222222),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined,
                                  size: 14, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                dateStr,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 13),
                              ),
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
                  // 리스트 아이템마다 Clip.antiAlias는 120Hz에서 raster 스파이크를 만들기 쉬워
                  // hardEdge로 낮춰 비용을 줄입니다 (그림자 유지).
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
                          decoration: BoxDecoration(
                            color: mainColor,
                            borderRadius: const BorderRadius.only(
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isRead
                                    ? Colors.grey.shade200
                                    : const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                type,
                                style: TextStyle(
                                  color: isRead
                                      ? Colors.grey
                                      : const Color(0xFF1976D2),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                                color: isRead
                                    ? Colors.grey.shade600
                                    : const Color(0xFF222222),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 13),
                                ),
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

class _ScaleFeedbackButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _ScaleFeedbackButton({required this.child, required this.onTap});
  @override
  State<_ScaleFeedbackButton> createState() => _ScaleFeedbackButtonState();
}

class _ScaleFeedbackButtonState extends State<_ScaleFeedbackButton> {
  bool _isPressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(scale: _isPressed ? 0.98 : 1.0, duration: const Duration(milliseconds: 100), child: widget.child),
    );
  }
}
