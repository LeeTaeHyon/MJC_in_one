import "dart:ui" show lerpDouble;

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:mio_notice/screens/common_webview_screen.dart";
import "package:mio_notice/screens/settings_screen.dart";
import "package:mio_notice/services/notice_filter.dart";
import "package:mio_notice/services/notice_manager.dart";
import "package:mio_notice/services/user_data_repository.dart";
import "package:mio_notice/theme/app_theme.dart";
import "package:mio_notice/perf_flags.dart";
import "package:mio_notice/widgets/nested_scroll_refresh_indicator.dart";
import "package:mio_notice/widgets/notice_filter_bar.dart";
import "package:mio_notice/widgets/pin_favorite_buttons.dart";
import "package:mio_notice/widgets/scroll_to_top_scope.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";

class _CtlListEntrance {
  bool _playedOnce = false;
  bool _scheduleEntranceEnd = false;

  bool get shouldAnimateList => !kPerfLowRasterMode && !_playedOnce;
  static const int maxAnimatedItems = 8;

  void resetForEntry() {
    _playedOnce = false;
    _scheduleEntranceEnd = false;
  }

  void scheduleEndEntranceAnimation() {
    if (_playedOnce || _scheduleEntranceEnd) return;
    _scheduleEntranceEnd = true;
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      _playedOnce = true;
    });
  }
}

class CtlScreen extends StatefulWidget {
  const CtlScreen({super.key, this.activeInNoticesTab = true});

  final bool activeInNoticesTab;

  @override
  State<CtlScreen> createState() => _CtlScreenState();
}

class _CtlScreenState extends State<CtlScreen> {
  final ScrollController _outerScrollController = ScrollController();
  ScrollToTopCoordinator? _scrollToTopCoordinator;
  ValueNotifier<int>? _activeTabNotifier;
  bool _registeredMainTab = false;
  int _entryTick = 0;
  late final NestedScrollFabScrollReporter _nestedFabReporter =
      NestedScrollFabScrollReporter(
    tabIndex: MainNavTabIndex.notices,
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
      _syncScrollToTopRegistration();
      if (!identical(_activeTabNotifier, c.activeMainTabNotifier)) {
        _activeTabNotifier?.removeListener(_handleMainTabChanged);
        _activeTabNotifier = c.activeMainTabNotifier;
        _activeTabNotifier?.addListener(_handleMainTabChanged);
      }
    }
    if (_outerScrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _nestedFabReporter.reportOuterScroll();
      });
    }
  }

  @override
  void didUpdateWidget(covariant CtlScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeInNoticesTab != widget.activeInNoticesTab) {
      _syncScrollToTopRegistration();
      if (widget.activeInNoticesTab) _handleMainTabChanged();
    }
  }

  void _syncScrollToTopRegistration() {
    final ScrollToTopCoordinator? c = _scrollToTopCoordinator;
    if (c == null) return;
    if (widget.activeInNoticesTab) {
      c.registerMainTab(MainNavTabIndex.notices, _scrollContentToTop);
      _registeredMainTab = true;
    } else if (_registeredMainTab) {
      c.unregisterMainTab(MainNavTabIndex.notices);
      _registeredMainTab = false;
    }
  }

  void _handleMainTabChanged() {
    final ScrollToTopCoordinator? c = _scrollToTopCoordinator;
    if (c == null) return;
    if (!widget.activeInNoticesTab ||
        c.activeMainTabNotifier.value != MainNavTabIndex.notices) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _entryTick++;
    });
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
    if (_registeredMainTab) {
      _scrollToTopCoordinator?.unregisterMainTab(MainNavTabIndex.notices);
    }
    _activeTabNotifier?.removeListener(_handleMainTabChanged);
    _outerScrollController.dispose();
    // 성능상 재진입 때마다 전체 리스트 entrance 애니메이션을 다시 돌리면 jank가 커져서 유지합니다.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double topPad = MediaQuery.paddingOf(context).top;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                      indicatorColor: tokens.sourceCtl,
                      indicatorWeight: 3,
                      labelColor: tokens.sourceCtl,
                      unselectedLabelColor: scheme.onSurfaceVariant,
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
              child: TabBarView(
                children: [
                  _CtlListTab(isProgram: true, entryTick: _entryTick),
                  _CtlListTab(isProgram: false, entryTick: _entryTick),
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
    final double extent =
        (maxExtent - shrinkOffset).clamp(minExtent, maxExtent);
    final double range = maxExtent - minExtent;
    final double t = range > 0 ? (shrinkOffset / range).clamp(0.0, 1.0) : 0.0;
    final double u = Curves.easeInOut.transform(t);
    final double heroH = extent - _tabBarHeight;
    // LayoutBuilder removed: ih = heroH - topPadding (SafeArea subtracts status bar)
    final double ih = heroH - topPadding;
    final double titleSize = lerpDouble(24, 17, u)!;
    const double titleLeft = 20;
    const double bottomBlock = 20 + 13 + 6 + 24;
    final double expandedTitleTop = (ih - bottomBlock).clamp(0.0, ih);
    final double collapsedTitleTop = (ih - titleSize * 1.15) / 2;
    final double titleTop = lerpDouble(expandedTitleTop, collapsedTitleTop, u)!;
    final double subtitleOpacity = (1.0 - u * 1.35).clamp(0.0, 1.0);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

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
              color: scheme.surface,
              elevation: overlapsContent ? 0.5 : 0,
              shadowColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
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
  final int entryTick;
  const _CtlListTab({required this.isProgram, required this.entryTick});
  @override
  State<_CtlListTab> createState() => _CtlListTabState();
}

class _CtlListTabState extends State<_CtlListTab> {
  final _CtlListEntrance _entrance = _CtlListEntrance();
  late Future<List<Map<String, dynamic>>> _ctlFuture;
  Set<String> _pinnedKeys = {};
  Set<String> _favoriteKeys = {};
  NoticeFilterState _noticeFilter = const NoticeFilterState();
  List<String> _noticeSharedKeywords = [];
  String _noticeQuickQuery = "";
  double _filterBarReveal = 0;
  bool _refreshEnabledForDrag = false;
  bool get _lowRaster =>
      kPerfLowRasterMode || defaultTargetPlatform == TargetPlatform.android;

  static const double _filterBarRevealDistance = 96;
  bool get _filterBarFullyVisible => _filterBarReveal >= 1.0;

  bool _allowRefreshNotification(ScrollNotification n) {
    if (!defaultScrollNotificationPredicate(n)) return false;
    return _refreshEnabledForDrag ||
        n is ScrollEndNotification ||
        n is UserScrollNotification;
  }

  bool _handleScrollNotification(ScrollNotification n) {
    if (n is ScrollStartNotification) {
      _refreshEnabledForDrag = _filterBarFullyVisible;
    } else if (n is OverscrollNotification) {
      if (!_refreshEnabledForDrag &&
          n.metrics.pixels <= n.metrics.minScrollExtent &&
          n.overscroll < 0) {
        final double next =
            (_filterBarReveal + (-n.overscroll / _filterBarRevealDistance))
                .clamp(0.0, 1.0);
        if (next != _filterBarReveal) {
          setState(() => _filterBarReveal = next);
        }
      }
    } else if (n is ScrollUpdateNotification) {
      if (n.metrics.pixels > 24 && _filterBarReveal > 0) {
        setState(() => _filterBarReveal = 0);
      }
    } else if (n is ScrollEndNotification) {
      if (_filterBarReveal > 0 && _filterBarReveal < 1) {
        setState(() => _filterBarReveal = _filterBarReveal >= 0.35 ? 1 : 0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshEnabledForDrag = false;
      });
    }
    return false;
  }

  Widget _revealedFilterBar(Widget filterBar) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: _filterBarReveal),
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
      child: filterBar,
      builder: (context, v, child) {
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: v,
            child: child,
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadPinsAndFavorites();
    _loadNoticeFilter();
    _ctlFuture = NoticeManager()
        .getNotices(boardId: widget.isProgram ? "ctl_programs" : "ctl_notice");
  }

  @override
  void didUpdateWidget(covariant _CtlListTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entryTick != oldWidget.entryTick) {
      _entrance.resetForEntry();
    }
  }

  Future<void> _loadNoticeFilter() async {
    final NoticeFilterState filter = await NoticeFilterState.load();
    final List<String> keywords = await loadSharedNoticeKeywords();
    if (!mounted) return;
    setState(() {
      _noticeFilter = filter.copyWith(quickQuery: _noticeQuickQuery);
      _noticeSharedKeywords = keywords;
    });
  }

  Future<void> _openNoticeFilterSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => const SettingsScreen(),
      ),
    );
    if (mounted) await _loadNoticeFilter();
  }

  String _boardId() => widget.isProgram ? "ctl_programs" : "ctl_notice";

  String _itemKey(Map<String, dynamic> data) {
    final String url = (data["link"] ?? data["url"] ?? "").toString().trim();
    final String title = (data["title"] ?? "").toString().trim();
    final String date =
        (data["reg_date"] ?? data["date"] ?? "").toString().trim();
    return "$url|$title|$date";
  }

  Future<void> _loadPinsAndFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final String b = _boardId();
    setState(() {
      _pinnedKeys = (prefs.getStringList("pinned_notices_$b") ?? []).toSet();
      _favoriteKeys =
          (prefs.getStringList("favorite_notices_$b") ?? []).toSet();
    });
  }

  Future<void> _togglePinned(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final String b = _boardId();
    final Set<String> next = {..._pinnedKeys};
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    if (mounted) setState(() => _pinnedKeys = next);
    await prefs.setStringList("pinned_notices_$b", next.toList());
    await UserDataRepository.instance.updateBookmarks(
      b,
      pinned: true,
      values: next.toList(),
    );
  }

  Future<void> _toggleFavorite(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final String b = _boardId();
    final Set<String> next = {..._favoriteKeys};
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    if (mounted) setState(() => _favoriteKeys = next);
    await prefs.setStringList("favorite_notices_$b", next.toList());
    await UserDataRepository.instance.updateBookmarks(
      b,
      pinned: false,
      values: next.toList(),
    );
  }

  Future<void> _handleRefresh() async {
    await _loadNoticeFilter();
    setState(() {
      _ctlFuture = NoticeManager().getNotices(
          boardId: widget.isProgram ? "ctl_programs" : "ctl_notice",
          forceRefresh: true);
    });
    await _ctlFuture;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return NestedScrollRefreshIndicator(
      onRefresh: _handleRefresh,
      color: const Color(0xFF2962FF),
      backgroundColor: scheme.surface,
      notificationPredicate: _allowRefreshNotification,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ctlFuture,
        builder: (context, snapshot) {
          return NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: CustomScrollView(
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
                else
                  ..._buildCtlSlivers(context, snapshot.data ?? []),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildCtlSlivers(
    BuildContext context,
    List<Map<String, dynamic>> items,
  ) {
    final NoticeFilterState filter =
        _noticeFilter.copyWith(quickQuery: _noticeQuickQuery);
    final List<Map<String, dynamic>> filteredItems = filter.apply(
      items,
      sharedKeywords: _noticeSharedKeywords,
      fallbackSource: "CTL",
      fallbackType: widget.isProgram ? "CTL 프로그램" : "학습공지",
    );
    final Widget filterBar = NoticeFilterBar(
      filter: filter,
      keywordCount: _noticeSharedKeywords.length,
      totalCount: items.length,
      filteredCount: filteredItems.length,
      accentColor: const Color(0xFF2962FF),
      onQueryChanged: (String value) {
        setState(() => _noticeQuickQuery = value);
      },
      onOpenSettings: _openNoticeFilterSettings,
    );

    if (filteredItems.isEmpty) {
      return [
        SliverToBoxAdapter(child: _revealedFilterBar(filterBar)),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 48),
              Text(
                items.isEmpty ? "등록된 항목이 없습니다." : "필터에 맞는 항목이 없습니다.",
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ];
    }

    final List<Map<String, dynamic>> ordered = [
      ...filteredItems.where((d) => _pinnedKeys.contains(_itemKey(d))),
      ...filteredItems.where((d) => !_pinnedKeys.contains(_itemKey(d))),
    ];

    return [
      SliverToBoxAdapter(child: _revealedFilterBar(filterBar)),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              if (index == 0 && _entrance.shouldAnimateList) {
                _entrance.scheduleEndEntranceAnimation();
              }
              final data = ordered[index];
              final String key = _itemKey(data);
              final bool isPinned = _pinnedKeys.contains(key);
              final bool isFavorite = _favoriteKeys.contains(key);
              final Widget card = RepaintBoundary(
                child: _buildCtlCard(context, data),
              );
              final Widget overlaid = Stack(
                children: [
                  card,
                  Positioned(
                    right: 12,
                    top: 10,
                    child: PinFavoriteButtons(
                      isPinned: isPinned,
                      isFavorite: isFavorite,
                      onTogglePinned: () => _togglePinned(key),
                      onToggleFavorite: () => _toggleFavorite(key),
                    ),
                  ),
                ],
              );
              final bool animate = _entrance.shouldAnimateList &&
                  index < _CtlListEntrance.maxAnimatedItems;
              if (animate) {
                return overlaid.animate().fadeIn(
                      delay: (index * 24).clamp(0, 240).ms,
                      duration: 240.ms,
                    );
              }
              return overlaid;
            },
            childCount: ordered.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildCtlCard(BuildContext context, Map<String, dynamic> data) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = tokens.sourceCtl;
    final Color chipBackground = accent.withValues(alpha: isDark ? 0.18 : 0.12);
    final Color secondaryText = scheme.onSurfaceVariant;
    final String title = data["title"] ?? "";
    final String date = data["reg_date"] ?? data["date"] ?? "";
    final String opPeriod = data["op_period"] ?? "";
    final String url = data["link"] ?? "";
    final String status = data["status"] ?? "진행중";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        elevation: _lowRaster ? 0 : 2,
        shadowColor: _lowRaster
            ? Colors.transparent
            : Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
        clipBehavior: _lowRaster ? Clip.hardEdge : Clip.none,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            if (url.isEmpty) return;
            if (kIsWeb) {
              await launchUrl(Uri.parse(url), webOnlyWindowName: "_blank");
            } else {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          CommonWebViewScreen(url: url, title: title)));
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
                        decoration: BoxDecoration(
                          color: accent,
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
                          Row(
                            children: [
                              if (widget.isProgram)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: chipBackground,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              Text(
                                "CTL",
                                style: TextStyle(
                                  color: secondaryText,
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
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (widget.isProgram && opPeriod.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.timer_outlined,
                                      size: 14, color: accent),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      "진행: $opPeriod",
                                      style: TextStyle(
                                        color: accent,
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
                              Icon(Icons.calendar_today_outlined,
                                  size: 14, color: secondaryText),
                              const SizedBox(width: 6),
                              Text(
                                "신청: $date",
                                style: TextStyle(
                                    color: secondaryText, fontSize: 13),
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 0,
                      bottom: 0,
                      child: Icon(Icons.chevron_right,
                          color: secondaryText, size: 24),
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
                          decoration: BoxDecoration(
                            color: accent,
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
                            Row(
                              children: [
                                if (widget.isProgram)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: chipBackground,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        color: accent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                Text(
                                  "CTL",
                                  style: TextStyle(
                                    color: secondaryText,
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
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (widget.isProgram && opPeriod.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(Icons.timer_outlined,
                                        size: 14, color: accent),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        "진행: $opPeriod",
                                        style: TextStyle(
                                          color: accent,
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
                                Icon(Icons.calendar_today_outlined,
                                    size: 14, color: secondaryText),
                                const SizedBox(width: 6),
                                Text(
                                  "신청: $date",
                                  style: TextStyle(
                                      color: secondaryText, fontSize: 13),
                                )
                              ],
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 0,
                        bottom: 0,
                        child: Icon(Icons.chevron_right,
                            color: secondaryText, size: 24),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
