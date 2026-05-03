import "dart:ui" show lerpDouble;

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:mio_notice/screens/common_webview_screen.dart";
import "package:mio_notice/services/notice_filter.dart";
import "package:mio_notice/services/notice_manager.dart";
import "package:mio_notice/services/user_data_repository.dart";
import "package:mio_notice/theme/app_theme.dart";
import "package:mio_notice/perf_flags.dart";
import "package:mio_notice/widgets/nested_scroll_refresh_indicator.dart";
import "package:mio_notice/widgets/pin_favorite_buttons.dart";
import "package:mio_notice/widgets/global_notice_search_sheet.dart";
import "package:mio_notice/widgets/notice_filter_sheet.dart";
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
  bool _openingGlobalSearch = false;
  final ValueNotifier<int> _filterReloadTick = ValueNotifier<int>(0);
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
    if (_outerScrollController.hasClients) {
      for (final position in _outerScrollController.positions) {
        position.animateTo(
          0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  Future<void> _openNoticeFilterSheet() async {
    await showNoticeFilterSheet(context);
    if (mounted) {
      _filterReloadTick.value++;
    }
  }

  Future<void> _openGlobalSearch() async {
    if (_openingGlobalSearch) return;
    _openingGlobalSearch = true;
    try {
      final futures = <Future<List<Map<String, dynamic>>>>[
        NoticeManager().getNotices(boardId: "ctl_programs"),
        NoticeManager().getNotices(boardId: "ctl_notice"),
      ];
      final results = await Future.wait(futures);
      if (!mounted) return;

      final List<Map<String, dynamic>> items = [];
      void addAll(List<Map<String, dynamic>> docs, String type) {
        for (final d in docs) {
          items.add({
            ...d,
            "_searchType": type,
            "_searchSource": "CTL",
          });
        }
      }

      addAll(results[0], "학습 프로그램");
      addAll(results[1], "센터 공지사항");

      await showGlobalNoticeSearchSheet(
        context,
        items: items,
        accentColor: const Color(0xFF2962FF),
        openItem: (item) async {
          final String url =
              (item["link"] ?? item["url"] ?? "").toString().trim();
          final String title = (item["title"] ?? "CTL").toString();
          if (url.isEmpty) return;
          if (kIsWeb) {
            await launchUrl(Uri.parse(url), webOnlyWindowName: "_blank");
          } else {
            if (!context.mounted) return;
            await Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => CommonWebViewScreen(url: url, title: title),
              ),
            );
          }
        },
        chipFor: (item) {
          final String t = (item["_searchType"] ?? "").toString().trim();
          return t.isEmpty ? "CTL" : t;
        },
        dateFor: (item) {
          final String d =
              (item["reg_date"] ?? item["date"] ?? "").toString().trim();
          final String s = (item["status"] ?? "").toString().trim();
          final String op = (item["op_period"] ?? "").toString().trim();
          final List<String> parts = <String>[];
          if (s.isNotEmpty) parts.add(s);
          if (op.isNotEmpty) parts.add("진행: $op");
          if (d.isNotEmpty) parts.add("신청: $d");
          return parts.join(" · ");
        },
        searchTextFor: (item) {
          final String title = (item["title"] ?? "").toString();
          final String type = (item["_searchType"] ?? "").toString();
          final String date =
              (item["reg_date"] ?? item["date"] ?? "").toString();
          final String status = (item["status"] ?? "").toString();
          final String opPeriod = (item["op_period"] ?? "").toString();
          return "$title $type $status $date $opPeriod";
        },
      );
    } finally {
      _openingGlobalSearch = false;
    }
  }

  @override
  void dispose() {
    _filterReloadTick.dispose();
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
    final double viewportH = MediaQuery.sizeOf(context).height;
    // 작은 화면에서 히어로 여백이 과해지지 않도록 조절.
    final double heroBody = (viewportH * 0.275).clamp(150.0, 225.0);
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
                    heroBody: heroBody,
                    onOpenFilter: _openNoticeFilterSheet,
                    onSearch: _openGlobalSearch,
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
                  _CtlListTab(
                    isProgram: true,
                    entryTick: _entryTick,
                    filterRevision: _filterReloadTick,
                  ),
                  _CtlListTab(
                    isProgram: false,
                    entryTick: _entryTick,
                    filterRevision: _filterReloadTick,
                  ),
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
    required this.heroBody,
    required this.tabBar,
    required this.onOpenFilter,
    required this.onSearch,
  });

  final double topPadding;
  final double heroBody;
  final TabBar tabBar;
  final VoidCallback onOpenFilter;
  final VoidCallback onSearch;

  static const double _collapsedBar = 52;

  double get _tabBarHeight => tabBar.preferredSize.height;

  @override
  double get maxExtent => topPadding + heroBody + _tabBarHeight;

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
    final double titleSize = lerpDouble(25, 18, u)!;
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
                          right: 104,
                          child: Text(
                            "교수학습센터",
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
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: "공지 목록 필터",
                                onPressed: onOpenFilter,
                                icon: const Icon(Icons.tune_rounded),
                                color: Colors.white,
                              ),
                              IconButton(
                                tooltip: "검색",
                                onPressed: onSearch,
                                icon: const Icon(Icons.search_rounded),
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                        if (subtitleOpacity > 0.02)
                          Positioned(
                            left: 20,
                            top: titleTop + titleSize * 0.95 + 6,
                            right: 104,
                            child: IgnorePointer(
                              child: Text(
                                "교수학습센터 프로그램을 확인합니다.",
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
    return topPadding != old.topPadding ||
        heroBody != old.heroBody ||
        tabBar != old.tabBar ||
        onOpenFilter != old.onOpenFilter ||
        onSearch != old.onSearch;
  }
}

class _CtlListTab extends StatefulWidget {
  final bool isProgram;
  final int entryTick;
  final ValueListenable<int> filterRevision;

  const _CtlListTab({
    required this.isProgram,
    required this.entryTick,
    required this.filterRevision,
  });
  @override
  State<_CtlListTab> createState() => _CtlListTabState();
}

class _CtlListTabState extends State<_CtlListTab> {
  final _CtlListEntrance _entrance = _CtlListEntrance();
  late Future<List<Map<String, dynamic>>> _ctlFuture;
  Set<String> _pinnedKeys = {};
  Set<String> _favoriteKeys = {};
  Set<String> _readKeys = {};
  NoticeFilterState _noticeFilter = const NoticeFilterState();
  List<String> _noticeSharedKeywords = [];
  bool get _lowRaster =>
      kPerfLowRasterMode || defaultTargetPlatform == TargetPlatform.android;

  bool _allowRefreshNotification(ScrollNotification n) {
    return defaultScrollNotificationPredicate(n);
  }

  void _onFilterRevision() {
    _loadNoticeFilter();
  }

  @override
  void initState() {
    super.initState();
    widget.filterRevision.addListener(_onFilterRevision);
    _loadPinsAndFavorites();
    _loadReadHistory();
    _loadNoticeFilter();
    _ctlFuture = NoticeManager()
        .getNotices(boardId: widget.isProgram ? "ctl_programs" : "ctl_notice");
  }

  @override
  void didUpdateWidget(covariant _CtlListTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filterRevision != widget.filterRevision) {
      oldWidget.filterRevision.removeListener(_onFilterRevision);
      widget.filterRevision.addListener(_onFilterRevision);
    }
    if (widget.entryTick != oldWidget.entryTick) {
      _entrance.resetForEntry();
    }
  }

  @override
  void dispose() {
    widget.filterRevision.removeListener(_onFilterRevision);
    super.dispose();
  }

  Future<void> _loadNoticeFilter() async {
    final NoticeFilterState filter = await NoticeFilterState.load();
    final List<String> keywords = await loadSharedNoticeKeywords();
    if (!mounted) return;
    setState(() {
      _noticeFilter = filter.copyWith(quickQuery: "");
      _noticeSharedKeywords = keywords;
    });
  }

  String _boardId() => widget.isProgram ? "ctl_programs" : "ctl_notice";

  String _itemKey(Map<String, dynamic> data) {
    final String url = (data["link"] ?? data["url"] ?? "").toString().trim();
    final String title = (data["title"] ?? "").toString().trim();
    final String date =
        (data["reg_date"] ?? data["date"] ?? "").toString().trim();
    return "$url|$title|$date";
  }

  Future<void> _loadReadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final String b = _boardId();
    setState(() {
      _readKeys = (prefs.getStringList("read_notices_$b") ?? []).toSet();
    });
  }

  Future<void> _markAsRead(String key) async {
    if (_readKeys.contains(key)) return;
    final prefs = await SharedPreferences.getInstance();
    final String b = _boardId();
    final Set<String> next = {..._readKeys, key};
    if (mounted) setState(() => _readKeys = next);
    await prefs.setStringList("read_notices_$b", next.toList());
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
                else
                  ..._buildCtlSlivers(context, snapshot.data ?? []),
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
    final NoticeFilterState filter = _noticeFilter.copyWith(quickQuery: "");
    final List<Map<String, dynamic>> filteredItems = filter.apply(
      items,
      sharedKeywords: _noticeSharedKeywords,
      fallbackSource: "CTL",
      fallbackType: widget.isProgram ? "CTL 프로그램" : "학습공지",
    );

    if (filteredItems.isEmpty) {
      return [
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
    final Color readTitlePurple =
        isDark ? const Color(0xFFB39DDB) : const Color(0xFF7E57C2);
    final Color accent = tokens.sourceCtl;
    final Color chipBackground = accent.withValues(alpha: isDark ? 0.18 : 0.12);
    final Color secondaryText = scheme.onSurfaceVariant;
    final String title = data["title"] ?? "";
    final String date = data["reg_date"] ?? data["date"] ?? "";
    final String opPeriod = data["op_period"] ?? "";
    final String url = data["link"] ?? "";
    final String status = data["status"] ?? "진행중";
    final String readKey = _itemKey(data);
    final bool isRead = _readKeys.contains(readKey);
    final Color stripColor = isRead ? scheme.onSurfaceVariant : accent;
    final Color titleColor = isRead ? readTitlePurple : scheme.onSurface;

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
            await _markAsRead(readKey);
            if (!context.mounted) return;
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
                          color: stripColor,
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
                              color: titleColor,
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
                            color: stripColor,
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
                                color: titleColor,
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
