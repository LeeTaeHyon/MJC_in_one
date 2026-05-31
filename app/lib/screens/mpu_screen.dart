import "dart:math" show max;
import "dart:ui" show lerpDouble;

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:mjc_in_one/utils/mpu_portal_scroll.dart";
import "package:mjc_in_one/services/notice_filter.dart";
import "package:mjc_in_one/services/notice_manager.dart";
import "package:mjc_in_one/services/user_data_repository.dart";
import "package:mjc_in_one/theme/app_theme.dart";
import "package:mjc_in_one/utils/bookmark_added_feedback.dart";
import "package:mjc_in_one/utils/notice_list_refresh_guard.dart";
import "package:mjc_in_one/utils/mpu_program_dday.dart";
import "package:mjc_in_one/perf_flags.dart";
import "package:mjc_in_one/widgets/nested_scroll_refresh_indicator.dart";
import "package:mjc_in_one/widgets/pin_favorite_buttons.dart";
import "package:mjc_in_one/widgets/collapsed_hero_title.dart";
import "package:mjc_in_one/widgets/global_notice_search_sheet.dart";
import "package:mjc_in_one/widgets/main_navigation_scope.dart";
import "package:mjc_in_one/widgets/notice_filter_sheet.dart";
import "package:mjc_in_one/widgets/scroll_to_top_scope.dart";
import "package:shared_preferences/shared_preferences.dart";

class _MpuListEntrance {
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

class MpuScreen extends StatefulWidget {
  const MpuScreen({super.key, this.activeInNoticesTab = true});

  final bool activeInNoticesTab;

  @override
  State<MpuScreen> createState() => _MpuScreenState();
}

class _MpuScreenState extends State<MpuScreen> {
  final GlobalKey<NestedScrollViewState> _nestedScrollKey =
      GlobalKey<NestedScrollViewState>();
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
  void didUpdateWidget(covariant MpuScreen oldWidget) {
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
      c.registerMainTab(
        MainNavTabIndex.notices,
        _scrollContentToTop,
        owner: this,
      );
      _registeredMainTab = true;
    } else if (_registeredMainTab) {
      c.unregisterMainTab(MainNavTabIndex.notices, owner: this);
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
    final NestedScrollViewState? nested = _nestedScrollKey.currentState;
    final ScrollController? inner = nested?.innerController;
    if (inner != null && inner.hasClients) {
      for (final position in inner.positions) {
        position.animateTo(
          0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    }
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
    await showNoticeFilterSheet(
      context,
      scopeId: "mpu",
      scopeLabel: "MPU(핵심역량) 공지/프로그램",
    );
    if (mounted) {
      _filterReloadTick.value++;
    }
  }

  Future<void> _openGlobalSearch() async {
    if (_openingGlobalSearch) return;
    _openingGlobalSearch = true;
    try {
      final List<Map<String, dynamic>> docs =
          await NoticeManager().getNotices(boardId: "mpu_programs");
      if (!mounted) return;

      final List<Map<String, dynamic>> items = [
        for (final d in docs)
          {
            ...d,
            "_searchType": "MPU 프로그램",
            "_searchSource": "MPU",
          }
      ];

      final MjcSurfaceTokens tokens =
          Theme.of(context).extension<MjcSurfaceTokens>()!;
      await showGlobalNoticeSearchSheet(
        context,
        items: items,
        accentColor: tokens.sourceMpu,
        openItem: (item) async {
          if (!mounted) return;
          await openMpuPortalForProgram(context, item);
        },
        boardIdFor: (_) => "mpu_programs",
        noticeKeyFor: (item) {
          final String title = (item["title"] ?? "").toString().trim();
          final String branch = (item["branch"] ?? "").toString().trim();
          final String dDay = (item["d_day"] ?? "").toString().trim();
          final String date =
              (item["reg_date"] ?? item["date"] ?? "").toString().trim();
          return "$title|$branch|$dDay|$date";
        },
        trailingFor: (item) => MpuDeadlineHomeStyleBadge(
          data: item,
          compactSecondLineFontSize: 14,
        ),
        chipFor: (item) {
          final String b = (item["branch"] ?? "").toString().trim();
          return b.isEmpty ? "핵심역량" : b;
        },
        dateFor: (item) {
          final String reg =
              (item["reg_date"] ?? item["date"] ?? "").toString().trim();
          final String edu = (item["edu_date"] ?? "").toString().trim();
          final List<String> parts = <String>[];
          if (reg.isNotEmpty) {
            parts.add("신청: $reg");
          }
          if (edu.isNotEmpty) {
            parts.add("교육: $edu");
          }
          return parts.join(" · ");
        },
        searchTextFor: (item) {
          final String title = (item["title"] ?? "").toString();
          final String branch = (item["branch"] ?? "").toString();
          final String badge = mpuDeadlineBadgeSecondLine(item);
          final String reg =
              (item["reg_date"] ?? item["date"] ?? "").toString();
          final String edu = (item["edu_date"] ?? "").toString();
          return "$title $branch D-$badge $reg $edu";
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
      _scrollToTopCoordinator?.unregisterMainTab(
        MainNavTabIndex.notices,
        owner: this,
      );
    }
    _activeTabNotifier?.removeListener(_handleMainTabChanged);
    _outerScrollController.dispose();
    // 성능상 재진입 때마다 전체 리스트 entrance 애니메이션을 다시 돌리면 jank가 커져서 유지합니다.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double topPad = MediaQuery.paddingOf(context).top;
    final double viewportW = MediaQuery.sizeOf(context).width;
    final double bannerHeight16x9 = viewportW * 9 / 16;
    final double heroBody = max(120.0, bannerHeight16x9 - topPad);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: NestedScrollView(
          key: _nestedScrollKey,
          controller: _outerScrollController,
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverOverlapAbsorber(
                handle:
                    NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                sliver: SliverPersistentHeader(
                  pinned: true,
                  delegate: _MpuCollapsingHeaderDelegate(
                    topPadding: topPad,
                    heroBody: heroBody,
                    onOpenFilter: _openNoticeFilterSheet,
                    onSearch: _openGlobalSearch,
                    tabBar: TabBar(
                      controller: DefaultTabController.of(context),
                      indicatorColor: tokens.sourceMpu,
                      indicatorWeight: 3,
                      labelColor: tokens.sourceMpu,
                      unselectedLabelColor: scheme.onSurfaceVariant,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      tabs: const [
                        Tab(text: "진행 중"),
                        Tab(text: "마감 / 완료"),
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
                  _MpuListTab(
                    showCompleted: false,
                    entryTick: _entryTick,
                    filterRevision: _filterReloadTick,
                  ),
                  _MpuListTab(
                    showCompleted: true,
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

class _MpuCollapsingHeaderDelegate extends SliverPersistentHeaderDelegate {
  _MpuCollapsingHeaderDelegate({
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
  static const Color _overlayTop = Color(0xFF89461C);
  static const Color _overlayBottom = Color(0xFFAB612A);
  static const double _collapsedOverlayOpacity = 0.90;

  double get _tabBarHeight => tabBar.preferredSize.height;

  @override
  double get maxExtent => topPadding + heroBody + _tabBarHeight;

  @override
  double get minExtent => topPadding + _collapsedBar + _tabBarHeight;

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
    final double overlayT = Curves.easeOutCubic.transform(t);
    final double u = Curves.easeInOut.transform(t);
    final double heroH = extent - _tabBarHeight;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double overlayOpacity =
        lerpDouble(0.0, _collapsedOverlayOpacity, overlayT)!;
    final Color overlayBase = _overlayTop;
    final Alignment imageAlignment = Alignment.lerp(
      Alignment.center,
      const Alignment(0, -0.35),
      overlayT,
    )!;
    final double bannerScale = lerpDouble(1.04, 1.02, overlayT)!;
    final double bottomOverlayOpacity = lerpDouble(
      overlayOpacity,
      (overlayOpacity + 0.08).clamp(0.0, 0.98),
      Curves.easeIn.transform(((t - 0.90) / 0.10).clamp(0.0, 1.0)),
    )!;

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
                  ColoredBox(color: overlayBase),
                  Positioned.fill(
                    child: Builder(
                      builder: (BuildContext context) {
                        final double dpr =
                            MediaQuery.devicePixelRatioOf(context);
                        final Size size = MediaQuery.sizeOf(context);
                        final int cw =
                            (size.width * dpr).round().clamp(1, 4096);
                        final int ch = ((topPadding + heroBody) * dpr)
                            .round()
                            .clamp(1, 4096);
                        return Transform.scale(
                          scale: bannerScale,
                          alignment: imageAlignment,
                          child: Image.asset(
                            "assets/images/mpu.png",
                            fit: BoxFit.cover,
                            alignment: imageAlignment,
                            width: double.infinity,
                            height: double.infinity,
                            cacheWidth: cw,
                            cacheHeight: ch,
                            filterQuality: FilterQuality.medium,
                            gaplessPlayback: true,
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            _overlayTop.withValues(alpha: overlayOpacity),
                            _overlayBottom.withValues(
                              alpha: bottomOverlayOpacity,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    bottom: false,
                    minimum: EdgeInsets.zero,
                    child: LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                        final double ih = constraints.maxHeight;
                        final double menuTopInset =
                            ih >= 54 ? 6.0 : max(0.0, (ih - 48) / 2);
                        final double titleSize = lerpDouble(34, 20, u)!;
                        const double titleLeft = 24;
                        const double toolbarSlot = 104;
                        final double collapsedTitleTop =
                            (ih - titleSize * 1.15) / 2;
                        final double titleReveal =
                            ((t - 0.92) / 0.08).clamp(0.0, 1.0);
                        final double titleOpacity =
                            Curves.easeOutCubic.transform(titleReveal);
                        return Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            Positioned(
                              left: titleLeft,
                              top: collapsedTitleTop,
                              right: toolbarSlot,
                              child: IgnorePointer(
                                ignoring: titleOpacity < 0.02,
                                child: Opacity(
                                  opacity: titleOpacity,
                                  child: CollapsedHeroTitle(
                                    icon: Icons.emoji_events_rounded,
                                    text: "핵심역량이력관리",
                                    baseStyle: Theme.of(context)
                                        .extension<MjcTextTokens>()!
                                        .appBarTitle,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 4,
                              bottom: 0,
                              width: toolbarSlot,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: EdgeInsets.only(top: menuTopInset),
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
                              ),
                            ),
                          ],
                        );
                      },
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
  bool shouldRebuild(covariant _MpuCollapsingHeaderDelegate old) {
    return topPadding != old.topPadding ||
        heroBody != old.heroBody ||
        tabBar != old.tabBar ||
        onOpenFilter != old.onOpenFilter ||
        onSearch != old.onSearch;
  }
}

class _MpuListTab extends StatefulWidget {
  final bool showCompleted;
  final int entryTick;
  final ValueListenable<int> filterRevision;

  const _MpuListTab({
    required this.showCompleted,
    required this.entryTick,
    required this.filterRevision,
  });
  @override
  State<_MpuListTab> createState() => _MpuListTabState();
}

class _MpuListTabState extends State<_MpuListTab> {
  final _MpuListEntrance _entrance = _MpuListEntrance();
  late Future<List<Map<String, dynamic>>> _mpuFuture;
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
    _mpuFuture = NoticeManager().getNotices(boardId: "mpu_programs");
  }

  @override
  void didUpdateWidget(covariant _MpuListTab oldWidget) {
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
    final bool enabled = await loadScopedNoticeFilterEnabled("mpu");
    final List<String> includes = await loadScopedNoticeFilterIncludes("mpu");
    if (!mounted) return;
    setState(() {
      _noticeFilter = filter.copyWith(
        enabled: enabled,
        quickQuery: "",
        sources: const ["MPU"],
        types: kNoticeFilterTypeOptions,
        excludes: const [],
        requireKeywordHit: false,
        includes: includes,
      );
      _noticeSharedKeywords = keywords;
    });
  }

  String _itemKey(Map<String, dynamic> data) {
    final String title = (data["title"] ?? "").toString().trim();
    final String branch = (data["branch"] ?? "").toString().trim();
    final String dDay = (data["d_day"] ?? "").toString().trim();
    final String date =
        (data["reg_date"] ?? data["date"] ?? "").toString().trim();
    return "$title|$branch|$dDay|$date";
  }

  Future<void> _loadReadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _readKeys =
          (prefs.getStringList("read_notices_mpu_programs") ?? []).toSet();
    });
  }

  Future<void> _markAsRead(String key) async {
    if (_readKeys.contains(key)) return;
    final prefs = await SharedPreferences.getInstance();
    final Set<String> next = {..._readKeys, key};
    if (mounted) setState(() => _readKeys = next);
    await prefs.setStringList("read_notices_mpu_programs", next.toList());
  }

  Future<void> _loadPinsAndFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _pinnedKeys =
          (prefs.getStringList("pinned_notices_mpu_programs") ?? []).toSet();
      _favoriteKeys =
          (prefs.getStringList("favorite_notices_mpu_programs") ?? []).toSet();
    });
  }

  Future<void> _togglePinned(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final bool adding = !_pinnedKeys.contains(key);
    final Set<String> next = {..._pinnedKeys};
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    if (mounted) setState(() => _pinnedKeys = next);
    await prefs.setStringList("pinned_notices_mpu_programs", next.toList());
    await UserDataRepository.instance.updateBookmarks(
      "mpu_programs",
      pinned: true,
      values: next.toList(),
    );
    if (!mounted) return;
    if (adding) {
      showBookmarkAddedSnackBar(context, openPinnedTab: true);
    } else {
      showBookmarkRemovedSnackBar(context, wasPinned: true);
    }
  }

  Future<void> _toggleFavorite(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final bool adding = !_favoriteKeys.contains(key);
    final Set<String> next = {..._favoriteKeys};
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    if (mounted) setState(() => _favoriteKeys = next);
    await prefs.setStringList("favorite_notices_mpu_programs", next.toList());
    await UserDataRepository.instance.updateBookmarks(
      "mpu_programs",
      pinned: false,
      values: next.toList(),
    );
    if (!mounted) return;
    if (adding) {
      showBookmarkAddedSnackBar(context, openPinnedTab: false);
    } else {
      showBookmarkRemovedSnackBar(context, wasPinned: false);
    }
  }

  Future<void> _handleRefresh() async {
    await _loadNoticeFilter();
    final bool forceRefresh =
        NoticeListRefreshGuard.allowForceRefresh("mpu_programs");
    setState(() {
      _mpuFuture = NoticeManager().getNotices(
        boardId: "mpu_programs",
        forceRefresh: forceRefresh,
      );
    });
    await _mpuFuture;
    if (!forceRefresh && mounted) {
      NoticeListRefreshGuard.showThrottledMessage(
        context,
        key: "mpu_programs_refresh_throttled",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    return NestedScrollRefreshIndicator(
      onRefresh: _handleRefresh,
      color: tokens.sourceMpu,
      backgroundColor: scheme.surface,
      notificationPredicate: _allowRefreshNotification,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _mpuFuture,
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
                ..._buildMpuSlivers(context, snapshot.data ?? []),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildMpuSlivers(
    BuildContext context,
    List<Map<String, dynamic>> allItems,
  ) {
    final NoticeFilterState filter = _noticeFilter.copyWith(quickQuery: "");
    final List<Map<String, dynamic>> noticeFilteredItems = filter.apply(
      allItems,
      sharedKeywords: _noticeSharedKeywords,
      fallbackSource: "MPU",
      fallbackType: "역량관리",
    );
    final List<Map<String, dynamic>> filteredItems =
        noticeFilteredItems.where((item) {
      final bool isCompleted = mpuListingIsCompleted(item);
      return widget.showCompleted ? isCompleted : !isCompleted;
    }).toList();

    filteredItems.sort((a, b) {
      final int valA = mpuSortDValue(a);
      final int valB = mpuSortDValue(b);
      if (widget.showCompleted) {
        return valA.compareTo(valB);
      }
      return valB.compareTo(valA);
    });

    final List<Map<String, dynamic>> ordered = [
      ...filteredItems.where((d) => _pinnedKeys.contains(_itemKey(d))),
      ...filteredItems.where((d) => !_pinnedKeys.contains(_itemKey(d))),
    ];

    if (filteredItems.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 48),
              Text(
                allItems.isEmpty
                    ? "등록된 프로그램이 없습니다."
                    : (widget.showCompleted
                        ? "완료된 프로그램이 없거나 필터에 맞는 항목이 없습니다."
                        : "진행 중인 프로그램이 없거나 필터에 맞는 항목이 없습니다."),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24 + MainNavLayout.scrollBottomExtra(context),
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              if (index == 0 && _entrance.shouldAnimateList) {
                _entrance.scheduleEndEntranceAnimation();
              }
              final Map<String, dynamic> data = ordered[index];
              final String key = _itemKey(data);
              final bool isPinned = _pinnedKeys.contains(key);
              final bool isFavorite = _favoriteKeys.contains(key);
              final Widget card = RepaintBoundary(
                child: _buildMpuCard(
                  context,
                  data,
                  itemKey: key,
                  isPinned: isPinned,
                  isFavorite: isFavorite,
                  onTogglePinned: () => _togglePinned(key),
                  onToggleFavorite: () => _toggleFavorite(key),
                ),
              );
              final bool animate = _entrance.shouldAnimateList &&
                  index < _MpuListEntrance.maxAnimatedItems;
              if (animate) {
                return card.animate().fadeIn(
                      delay: (index * 24).clamp(0, 240).ms,
                      duration: 240.ms,
                    );
              }
              return card;
            },
            childCount: ordered.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildMpuCard(
    BuildContext context,
    Map<String, dynamic> data, {
    required String itemKey,
    required bool isPinned,
    required bool isFavorite,
    required VoidCallback onTogglePinned,
    required VoidCallback onToggleFavorite,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color readTitleColor = tokens.noticeReadTitle;
    final Color accent = tokens.sourceMpu;
    final Color completedColor = scheme.onSurfaceVariant;
    final Color chipBackground = widget.showCompleted
        ? tokens.surfaceContainer
        : accent.withValues(alpha: isDark ? 0.18 : 0.12);
    final Color chipForeground = widget.showCompleted ? completedColor : accent;
    final bool isRead = !widget.showCompleted && _readKeys.contains(itemKey);
    final Color titleColor = widget.showCompleted
        ? completedColor
        : (isRead ? readTitleColor : scheme.onSurface);
    final Color stripColor = widget.showCompleted
        ? completedColor
        : (isRead ? scheme.onSurfaceVariant : accent);
    final Color dateColor = scheme.onSurfaceVariant;
    final String title = data["title"] ?? "";
    final String branch = data["branch"] ?? "";
    final String reg =
        (data["reg_date"] ?? data["date"] ?? "").toString().trim();
    final String edu = (data["edu_date"] ?? "").toString().trim();
    final List<String> tags = switch (data["tags"]) {
      final List<dynamic> raw => raw.map((e) => e.toString().trim()).toList(),
      _ => const <String>[],
    };
    final List<String> tagLabels =
        tags.where((t) => t.isNotEmpty).take(3).map((t) {
      final String trimmed = t.trim();
      return trimmed.startsWith("#") ? trimmed : "#$trimmed";
    }).toList();
    final String typeLabel = branch.trim().isEmpty ? "핵심역량" : branch.trim();

    final Widget dDayBadge = widget.showCompleted
        ? Opacity(
            opacity: 0.55,
            child: MpuDeadlineHomeStyleBadge(
              data: data,
              elapsed: true,
              compactSecondLineFontSize: 14,
            ),
          )
        : MpuDeadlineHomeStyleBadge(
            data: data,
            compactSecondLineFontSize: 14,
          );

    Widget buildStack(List<Widget> children) {
      children.addAll([
        Positioned(
          right: 12,
          top: 10,
          child: PinFavoriteButtons(
            isPinned: isPinned,
            isFavorite: isFavorite,
            onTogglePinned: onTogglePinned,
            onToggleFavorite: onToggleFavorite,
          ),
        ),
        Positioned(
          right: 12,
          bottom: 16,
          child: dDayBadge,
        ),
      ]);
      return Stack(children: children);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color:
            widget.showCompleted ? scheme.surfaceContainerLow : scheme.surface,
        borderRadius: BorderRadius.circular(12),
        elevation: (widget.showCompleted || _lowRaster) ? 0 : 2,
        shadowColor: _lowRaster
            ? Colors.transparent
            : Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
        clipBehavior: _lowRaster ? Clip.hardEdge : Clip.none,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            await _markAsRead(itemKey);
            if (!context.mounted) return;
            await openMpuPortalForProgram(context, data);
          },
          child: _lowRaster
              ? buildStack([
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
                    padding: const EdgeInsets.fromLTRB(20, 16, 80, 80),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: chipBackground,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                typeLabel,
                                style: TextStyle(
                                  color: chipForeground,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ...tagLabels.map(
                              (label) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: chipBackground,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: chipForeground,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
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
                        if (reg.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 14,
                                color: dateColor,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "신청: $reg",
                                  style: TextStyle(
                                    color: dateColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (edu.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.school_outlined,
                                size: 14,
                                color: dateColor,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "교육: $edu",
                                  style: TextStyle(
                                    color: dateColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ])
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.hardEdge,
                  child: buildStack([
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
                      padding: const EdgeInsets.fromLTRB(20, 16, 80, 80),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: chipBackground,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  typeLabel,
                                  style: TextStyle(
                                    color: chipForeground,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              ...tagLabels.map(
                                (label) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: chipBackground,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: chipForeground,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
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
                          if (reg.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 14,
                                  color: dateColor,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    "신청: $reg",
                                    style: TextStyle(
                                      color: dateColor,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (edu.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.school_outlined,
                                  size: 14,
                                  color: dateColor,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    "교육: $edu",
                                    style: TextStyle(
                                      color: dateColor,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ]),
                ),
        ),
      ),
    );
  }
}
