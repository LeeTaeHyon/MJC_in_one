import "dart:ui" show lerpDouble;

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:mio_notice/screens/common_webview_screen.dart";
import "package:mio_notice/services/notice_filter.dart";
import "package:mio_notice/services/notice_manager.dart";
import "package:mio_notice/services/user_data_repository.dart";
import "package:mio_notice/theme/app_theme.dart";
import "package:mio_notice/utils/mpu_program_dday.dart";
import "package:mio_notice/perf_flags.dart";
import "package:mio_notice/widgets/nested_scroll_refresh_indicator.dart";
import "package:mio_notice/widgets/pin_favorite_buttons.dart";
import "package:mio_notice/widgets/global_notice_search_sheet.dart";
import "package:mio_notice/widgets/notice_filter_sheet.dart";
import "package:mio_notice/widgets/scroll_to_top_scope.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";

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

      await showGlobalNoticeSearchSheet(
        context,
        items: items,
        accentColor: const Color(0xFF7986CB),
        openItem: (item) async {
          const url = "https://mpu.mjc.ac.kr/Main/default.aspx";
          if (kIsWeb) {
            await launchUrl(Uri.parse(url), webOnlyWindowName: "_blank");
          } else {
            if (!context.mounted) return;
            await Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const CommonWebViewScreen(
                  url: url,
                  title: "핵심역량 관리 (MPU)",
                ),
              ),
            );
          }
        },
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

  double get _tabBarHeight => tabBar.preferredSize.height;

  @override
  double get maxExtent => topPadding + heroBody + _tabBarHeight;

  @override
  double get minExtent => topPadding + _collapsedBar + _tabBarHeight;

  static const LinearGradient _headerGradient = LinearGradient(
    colors: [Color(0xFF7986CB), Color(0xFF90A4AE)],
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
    // LayoutBuilder removed: ih = heroH - topPadding
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
                            "핵심 역량 이력관리 시스템",
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
                                "마일리지 프로그램들을 확인합니다.",
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
      _readKeys = (prefs.getStringList("read_notices_mpu_programs") ?? []).toSet();
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
  }

  Future<void> _toggleFavorite(String key) async {
    final prefs = await SharedPreferences.getInstance();
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
  }

  Future<void> _handleRefresh() async {
    await _loadNoticeFilter();
    setState(() {
      _mpuFuture = NoticeManager()
          .getNotices(boardId: "mpu_programs", forceRefresh: true);
    });
    await _mpuFuture;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return NestedScrollRefreshIndicator(
      onRefresh: _handleRefresh,
      color: const Color(0xFF7986CB),
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
                child: _buildMpuCard(context, data, itemKey: key),
              );
              final Widget dDayBadge = widget.showCompleted
                  ? Opacity(
                      opacity: 0.55,
                      child: MpuDeadlineHomeStyleBadge(data: data),
                    )
                  : MpuDeadlineHomeStyleBadge(data: data);
              final Widget overlaid = Stack(
                children: [
                  card,
                  Positioned(
                    right: 16,
                    top: 10,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        PinFavoriteButtons(
                          isPinned: isPinned,
                          isFavorite: isFavorite,
                          onTogglePinned: () => _togglePinned(key),
                          onToggleFavorite: () => _toggleFavorite(key),
                        ),
                        const SizedBox(height: 8),
                        dDayBadge,
                      ],
                    ),
                  ),
                ],
              );
              final bool animate = _entrance.shouldAnimateList &&
                  index < _MpuListEntrance.maxAnimatedItems;
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

  Widget _mpuProgramDetailsBlock(
    BuildContext context, {
    required Map<String, dynamic> data,
    required String title,
    required String chipLabel,
    required Color titleColor,
    required Color chipBackground,
    required Color chipForeground,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color secondaryText = scheme.onSurfaceVariant;
    final String reg =
        (data["reg_date"] ?? data["date"] ?? "").toString().trim();
    final String edu = (data["edu_date"] ?? "").toString().trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: chipBackground,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            chipLabel.isEmpty ? "핵심역량" : chipLabel,
            style: TextStyle(
              color: chipForeground,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: titleColor,
            height: 1.3,
          ),
        ),
        if (reg.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: secondaryText,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "신청: $reg",
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (edu.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.school_outlined,
                size: 14,
                color: secondaryText,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "교육: $edu",
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMpuCard(
    BuildContext context,
    Map<String, dynamic> data, {
    required String itemKey,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color readTitlePurple =
        isDark ? const Color(0xFFB39DDB) : const Color(0xFF7E57C2);
    final Color accent = tokens.sourceMpu;
    final Color completedColor = scheme.onSurfaceVariant;
    final Color chipBackground = widget.showCompleted
        ? tokens.surfaceContainer
        : accent.withValues(alpha: isDark ? 0.18 : 0.12);
    final Color chipForeground = widget.showCompleted ? completedColor : accent;
    final bool isRead = !widget.showCompleted && _readKeys.contains(itemKey);
    final Color titleColor = widget.showCompleted
        ? completedColor
        : (isRead ? readTitlePurple : scheme.onSurface);
    final Color stripColor = widget.showCompleted
        ? completedColor
        : (isRead ? scheme.onSurfaceVariant : accent);
    final String title = data["title"] ?? "";
    final String branch = data["branch"] ?? "";
    final List<String> tags = switch (data["tags"]) {
      final List<dynamic> raw => raw.map((e) => e.toString().trim()).toList(),
      _ => const <String>[],
    };
    final String tagsLabel = tags
        .where((t) => t.isNotEmpty)
        .take(3)
        .map((t) => "#$t")
        .join(" ");
    final String chipLabel = tagsLabel.isNotEmpty ? tagsLabel : branch;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color:
            widget.showCompleted ? scheme.surfaceContainerLow : scheme.surface,
        borderRadius: BorderRadius.circular(16),
        elevation: (widget.showCompleted || _lowRaster) ? 0 : 2,
        shadowColor: _lowRaster
            ? Colors.transparent
            : Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
        clipBehavior: _lowRaster ? Clip.hardEdge : Clip.none,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            const url = "https://mpu.mjc.ac.kr/Main/default.aspx";
            await _markAsRead(itemKey);
            if (!context.mounted) return;
            if (kIsWeb) {
              await launchUrl(Uri.parse(url), webOnlyWindowName: "_blank");
            } else {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CommonWebViewScreen(
                          url: url, title: "핵심역량 관리 (MPU)")));
            }
          },
          child: (_lowRaster)
              ? Stack(
                  children: <Widget>[
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 5,
                        decoration: BoxDecoration(
                          color: stripColor,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 88, 18),
                      child: _mpuProgramDetailsBlock(
                        context,
                        data: data,
                        title: title,
                        chipLabel: chipLabel,
                        titleColor: titleColor,
                        chipBackground: chipBackground,
                        chipForeground: chipForeground,
                      ),
                    ),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.hardEdge,
                  child: Stack(
                    children: <Widget>[
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 5,
                          decoration: BoxDecoration(
                            color: stripColor,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 88, 18),
                        child: _mpuProgramDetailsBlock(
                          context,
                          data: data,
                          title: title,
                          chipLabel: chipLabel,
                          titleColor: titleColor,
                          chipBackground: chipBackground,
                          chipForeground: chipForeground,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
