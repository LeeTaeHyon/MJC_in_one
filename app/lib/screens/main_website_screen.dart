import "dart:ui" show lerpDouble;

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:mio_notice/screens/common_webview_screen.dart";
import "package:mio_notice/screens/notice_detail_screen.dart";
import "package:mio_notice/services/notice_filter.dart";
import "package:mio_notice/services/notice_manager.dart";
import "package:mio_notice/services/user_data_repository.dart";
import "package:mio_notice/theme/app_colors.dart";
import "package:mio_notice/theme/app_theme.dart";
import "package:mio_notice/perf_flags.dart";
import "package:mio_notice/widgets/nested_scroll_refresh_indicator.dart";
import "package:mio_notice/widgets/pin_favorite_buttons.dart";
import "package:mio_notice/widgets/global_notice_search_sheet.dart";
import "package:mio_notice/widgets/notice_filter_sheet.dart";
import "package:mio_notice/widgets/scroll_to_top_scope.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";

List<String> _parseAiTagsForList(Map<String, dynamic> data) {
  final Object? v = data["ai_tags"];
  if (v is! List) return const <String>[];
  return v
      .map((e) => e.toString())
      .where((s) => s.trim().isNotEmpty)
      .take(2)
      .toList();
}

/// `test/notice_ai_tags.py`의 ALLOWED_TAGS와 동일 순서(「전체」는 UI 전용).
const List<String> kMainNoticeAiTagFilterChips = <String>[
  "전체",
  "학사/수업",
  "장학/등록금",
  "모집/신청",
  "행사/대회/특강",
  "취업/진로/창업",
  "정책/지원사업/대외홍보",
  "기타",
];

Widget _noticeCategoryAndAiTagsRow({
  required BuildContext context,
  required String categoryLabel,
  required List<String> aiTags,
  required Color primaryChipBackground,
  required Color primaryChipForeground,
}) {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  return Wrap(
    spacing: 6,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: <Widget>[
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: primaryChipBackground,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          categoryLabel,
          style: TextStyle(
            color: primaryChipForeground,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      ...aiTags.map(
        (String t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Text(
            t,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ],
  );
}

/// 스크롤/전환 중 jank를 줄이기 위해 entrance stagger는 앱 실행 동안 1회만 재생.
class _MainWebsiteListEntrance {
  bool _playedOnce = false;
  bool _scheduleEntranceEnd = false;

  bool get shouldAnimateList => !kPerfLowRasterMode && !_playedOnce;
  static const int maxAnimatedItems = 8;

  void resetForEntry() {
    _playedOnce = false;
    _scheduleEntranceEnd = false;
  }

  /// 첫 리스트 stagger 끝난 뒤에만 끔 (도중 리빌드로 애니메이션이 끊기지 않게).
  void scheduleEndEntranceAnimation() {
    if (_playedOnce || _scheduleEntranceEnd) return;
    _scheduleEntranceEnd = true;
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      _playedOnce = true;
    });
  }
}

/// 명지전문대학 공식 홈페이지의 공지사항을 탭별로 보여주는 화면입니다.
class MainWebsiteScreen extends StatefulWidget {
  const MainWebsiteScreen({super.key, this.activeInNoticesTab = true});

  final bool activeInNoticesTab;

  @override
  State<MainWebsiteScreen> createState() => _MainWebsiteScreenState();
}

class _MainWebsiteScreenState extends State<MainWebsiteScreen> {
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
  void didUpdateWidget(covariant MainWebsiteScreen oldWidget) {
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
        NoticeManager().getNotices(boardId: "main_notice"),
        NoticeManager().getNotices(boardId: "main_academic"),
        NoticeManager().getNotices(boardId: "main_scholarship"),
      ];
      final results = await Future.wait(futures);
      if (!mounted) return;

      final List<Map<String, dynamic>> items = [];
      void addAll(List<Map<String, dynamic>> docs, String type) {
        for (final d in docs) {
          items.add({
            ...d,
            "_searchType": type,
            "_searchSource": "메인 공지사항",
          });
        }
      }

      addAll(results[0], "공지사항");
      addAll(results[1], "학사공지");
      addAll(results[2], "장학공지");

      await showGlobalNoticeSearchSheet(
        context,
        items: items,
        accentColor: const Color(0xFF003FB4),
        openItem: (item) async {
          final String url =
              (item["url"] ?? item["link"] ?? "").toString().trim();
          final String title = (item["title"] ?? "공지사항").toString();
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
          final String cat = (item["category"] ?? "").toString().trim();
          if (cat.isNotEmpty) return cat;
          return (item["_searchType"] ?? "공지").toString();
        },
        dateFor: (item) =>
            (item["date"] ?? item["reg_date"] ?? "").toString().trim(),
        searchTextFor: (item) {
          final String title = (item["title"] ?? "").toString();
          final String type = (item["_searchType"] ?? "").toString();
          final String cat = (item["category"] ?? "").toString();
          final String date =
              (item["date"] ?? item["reg_date"] ?? "").toString();
          return "$title $type $cat $date";
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
    // 공지 리스트 화면에서 상단 여백(접히는 히어로)을 화면 크기에 맞춰 조절.
    final double heroBody = (viewportH * 0.275).clamp(150.0, 225.0);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color tabAccent =
        isDark ? AppColors.switchActiveDark : scheme.primary;
    return DefaultTabController(
      length: 3,
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
                  delegate: _MainWebsiteCollapsingHeaderDelegate(
                    topPadding: topPad,
                    heroBody: heroBody,
                    onOpenFilter: _openNoticeFilterSheet,
                    onSearch: _openGlobalSearch,
                    tabBar: TabBar(
                      controller: DefaultTabController.of(context),
                      indicatorColor: tabAccent,
                      indicatorWeight: 3,
                      labelColor: tabAccent,
                      unselectedLabelColor: scheme.onSurfaceVariant,
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
                  _NoticeListTab(
                    boardId: "main_notice",
                    entryTick: _entryTick,
                    filterRevision: _filterReloadTick,
                  ),
                  _NoticeListTab(
                    boardId: "main_academic",
                    entryTick: _entryTick,
                    filterRevision: _filterReloadTick,
                  ),
                  _NoticeListTab(
                    boardId: "main_scholarship",
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

/// 홈 히어로와 같이 스크롤에 따라 상단 영역이 접히고, 탭 바는 아래에 고정됩니다.
class _MainWebsiteCollapsingHeaderDelegate
    extends SliverPersistentHeaderDelegate {
  _MainWebsiteCollapsingHeaderDelegate({
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
    final double extent =
        (maxExtent - shrinkOffset).clamp(minExtent, maxExtent);
    final double range = maxExtent - minExtent;
    final double t = range > 0 ? (shrinkOffset / range).clamp(0.0, 1.0) : 0.0;
    final double u = Curves.easeInOut.transform(t);
    final double heroH = extent - _tabBarHeight;
    // LayoutBuilder removed: c.maxHeight == heroH - topPadding (SafeArea subtracts status bar)
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
                      decoration: BoxDecoration(gradient: _headerGradient)),
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
                            "MJC 공지사항",
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
                                "본교 공지사항을 확인합니다.",
                                maxLines: 1,
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
              color: isDark ? scheme.surfaceContainer : scheme.surface,
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
  bool shouldRebuild(covariant _MainWebsiteCollapsingHeaderDelegate old) {
    return topPadding != old.topPadding ||
        heroBody != old.heroBody ||
        tabBar != old.tabBar ||
        onOpenFilter != old.onOpenFilter ||
        onSearch != old.onSearch;
  }
}


class _NoticeListTab extends StatefulWidget {
  final String boardId;
  final int entryTick;
  final ValueListenable<int> filterRevision;

  const _NoticeListTab({
    required this.boardId,
    required this.entryTick,
    required this.filterRevision,
  });

  @override
  State<_NoticeListTab> createState() => _NoticeListTabState();
}

class _NoticeListTabState extends State<_NoticeListTab> {
  final _MainWebsiteListEntrance _entrance = _MainWebsiteListEntrance();
  Set<String> _readNoticeIds = {};
  Set<String> _pinnedKeys = {};
  Set<String> _favoriteKeys = {};
  NoticeFilterState _noticeFilter = const NoticeFilterState();
  List<String> _noticeSharedKeywords = [];
  /// `main_notice` 탭만: 유튜브 스타일 주제 칩 필터.
  String _mainNoticeAiTagChipSelection = "전체";
  late Future<List<Map<String, dynamic>>> _noticeFuture;

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
    _loadReadHistory();
    _loadPinsAndFavorites();
    _loadNoticeFilter();
    _noticeFuture = NoticeManager().getNotices(boardId: widget.boardId);
  }

  @override
  void didUpdateWidget(covariant _NoticeListTab oldWidget) {
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

  String _fallbackType() {
    switch (widget.boardId) {
      case "main_academic":
        return "학사공지";
      case "main_scholarship":
        return "장학공지";
      default:
        return "공지사항";
    }
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

  Future<void> _loadReadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _readNoticeIds =
          (prefs.getStringList("read_notices_${widget.boardId}") ?? []).toSet();
    });
  }

  String _noticeKey(Map<String, dynamic> data) {
    final String id = (data["id"] ?? "").toString().trim();
    if (id.isNotEmpty) return id;
    final String url = (data["url"] ?? data["link"] ?? "").toString().trim();
    final String title = (data["title"] ?? "").toString().trim();
    final String date =
        (data["date"] ?? data["reg_date"] ?? "").toString().trim();
    return "$url|$title|$date";
  }

  Future<void> _loadPinsAndFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _pinnedKeys =
          (prefs.getStringList("pinned_notices_${widget.boardId}") ?? [])
              .toSet();
      _favoriteKeys =
          (prefs.getStringList("favorite_notices_${widget.boardId}") ?? [])
              .toSet();
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
    await prefs.setStringList(
        "pinned_notices_${widget.boardId}", next.toList());
    await UserDataRepository.instance.updateBookmarks(
      widget.boardId,
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
    await prefs.setStringList(
        "favorite_notices_${widget.boardId}", next.toList());
    await UserDataRepository.instance.updateBookmarks(
      widget.boardId,
      pinned: false,
      values: next.toList(),
    );
  }

  Future<void> _handleRefresh() async {
    await _loadNoticeFilter();
    setState(() {
      _noticeFuture = NoticeManager()
          .getNotices(boardId: widget.boardId, forceRefresh: true);
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
    await prefs.setStringList(
        "read_notices_${widget.boardId}", _readNoticeIds.toList());
  }

  List<Map<String, dynamic>> _applyMainNoticeAiTagChips(
    List<Map<String, dynamic>> rows,
  ) {
    if (widget.boardId != "main_notice") return rows;
    if (_mainNoticeAiTagChipSelection == "전체") return rows;
    return rows.where((Map<String, dynamic> d) {
      final Object? raw = d["ai_tags"];
      if (raw is! List) {
        return _mainNoticeAiTagChipSelection == "기타";
      }
      final List<String> tags = raw
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
      return tags.contains(_mainNoticeAiTagChipSelection);
    }).toList();
  }

  Widget _buildMainNoticeAiTagChipBar(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: scheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
        ),
        child: SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: kMainNoticeAiTagFilterChips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (BuildContext context, int index) {
              final String label = kMainNoticeAiTagFilterChips[index];
              final bool selected =
                  _mainNoticeAiTagChipSelection == label;
              final Color bg = selected
                  ? (isDark ? scheme.primary : const Color(0xFF0F0F0F))
                  : (isDark
                      ? scheme.surfaceContainerHighest
                      : const Color(0xFFF2F2F2));
              final Color fg = selected
                  ? (isDark ? scheme.onPrimary : Colors.white)
                  : (isDark
                      ? scheme.onSurface
                      : const Color(0xFF0F0F0F));
              return Material(
                color: bg,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  onTap: () {
                    if (_mainNoticeAiTagChipSelection == label) return;
                    setState(() => _mainNoticeAiTagChipSelection = label);
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: fg,
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return NestedScrollRefreshIndicator(
      onRefresh: _handleRefresh,
      color: const Color(0xFF003FB4),
      backgroundColor: scheme.surface,
      notificationPredicate: _allowRefreshNotification,
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
                else
                  ..._buildNoticeSlivers(context, snapshot.data ?? []),
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
    final NoticeFilterState filter = _noticeFilter.copyWith(quickQuery: "");
    final List<Map<String, dynamic>> filteredDocs = filter.apply(
      docs,
      sharedKeywords: _noticeSharedKeywords,
      fallbackSource: "MJC",
      fallbackType: _fallbackType(),
    );
    final List<Map<String, dynamic>> tagFilteredDocs =
        _applyMainNoticeAiTagChips(filteredDocs);

    final List<Widget> chipSliver = widget.boardId == "main_notice"
        ? <Widget>[
            SliverToBoxAdapter(
              child: _buildMainNoticeAiTagChipBar(context),
            ),
          ]
        : const <Widget>[];

    if (filteredDocs.isEmpty) {
      return [
        ...chipSliver,
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 48),
              Text(
                docs.isEmpty ? "표시할 공지가 없습니다." : "필터에 맞는 공지가 없습니다.",
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ];
    }

    if (tagFilteredDocs.isEmpty) {
      return [
        ...chipSliver,
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 48),
              Text(
                "선택한 주제에 맞는 공지가 없습니다.",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ];
    }

    final List<Map<String, dynamic>> ordered = [
      ...tagFilteredDocs.where((d) => _pinnedKeys.contains(_noticeKey(d))),
      ...tagFilteredDocs.where((d) => !_pinnedKeys.contains(_noticeKey(d))),
    ];

    return [
      ...chipSliver,
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              if (index == 0 && _entrance.shouldAnimateList) {
                _entrance.scheduleEndEntranceAnimation();
              }
              final data = ordered[index];
              final String id = data["id"] ?? "";
              final bool isRead = _readNoticeIds.contains(id);
              final String key = _noticeKey(data);
              final bool isPinned = _pinnedKeys.contains(key);
              final bool isFavorite = _favoriteKeys.contains(key);

              Future<void> openDetail() async {
                await _markAsRead(id);
                if (!context.mounted) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => NoticeDetailScreen(
                      notice: data,
                      boardId: widget.boardId,
                      isPinned: isPinned,
                      isFavorite: isFavorite,
                      onTogglePinned: () => _togglePinned(key),
                      onToggleFavorite: () => _toggleFavorite(key),
                    ),
                  ),
                );
              }

              final Widget tile = _ScaleFeedbackButton(
                onTap: openDetail,
                child: _buildNoticeListItem(
                  context,
                  data,
                  id,
                  isRead,
                  showAiTagChips: widget.boardId == "main_notice",
                  isPinned: isPinned,
                  isFavorite: isFavorite,
                  onTogglePinned: () => _togglePinned(key),
                  onToggleFavorite: () => _toggleFavorite(key),
                  openDetail,
                ),
              );
              final Widget paintIsolated = RepaintBoundary(child: tile);
              final bool animate = _entrance.shouldAnimateList &&
                  index < _MainWebsiteListEntrance.maxAnimatedItems;
              final Widget out = animate
                  ? paintIsolated.animate().fadeIn(
                        delay: (index * 24).clamp(0, 240).ms,
                        duration: 240.ms,
                      )
                  : paintIsolated;

              return out;
            },
            childCount: ordered.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildNoticeListItem(
    BuildContext context,
    Map<String, dynamic> data,
    String id,
    bool isRead,
    VoidCallback onTap, {
    /// 메인 홈페이지 공지 중 **「공지사항」탭(main_notice)** 에서만 주제 태그 칩을 노출합니다.
    required bool showAiTagChips,
    required bool isPinned,
    required bool isFavorite,
    required VoidCallback onTogglePinned,
    required VoidCallback onToggleFavorite,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color readTitlePurple =
        isDark ? const Color(0xFFB39DDB) : const Color(0xFF7E57C2);
    final String title = data["title"] ?? "";
    final String dateStr = data["date"] ?? "";
    final String type = data["category"] ?? "공지";
    final List<String> aiTags =
        showAiTagChips ? _parseAiTagsForList(data) : const <String>[];
    final bool showAiTagRow = showAiTagChips && aiTags.isNotEmpty;
    // 읽음 표현은 과하지 않게: 좌측 스트립만 회색으로 낮추고, 제목 글씨만 앱의 메인 블루로 바꿈.
    final Color mainColor = isRead ? scheme.onSurfaceVariant : tokens.sourceMjc;
    final Color chipBackground =
        tokens.sourceMjc.withValues(alpha: isDark ? 0.18 : 0.12);
    final Color chipForeground = tokens.sourceMjc;
    final Color titleColor = isRead ? readTitlePurple : scheme.onSurface;
    final Color dateColor = scheme.onSurfaceVariant;
    const bool lowRaster = kPerfLowRasterMode;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        elevation: lowRaster ? 0 : 2,
        shadowColor: lowRaster
            ? Colors.transparent
            : Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
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
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showAiTagRow)
                            _noticeCategoryAndAiTagsRow(
                              context: context,
                              categoryLabel: type,
                              aiTags: aiTags,
                              primaryChipBackground: chipBackground,
                              primaryChipForeground: chipForeground,
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: chipBackground,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                type,
                                style: TextStyle(
                                  color: chipForeground,
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
                              fontWeight: FontWeight.bold,
                              color: titleColor,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 14,
                                color: dateColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                dateStr,
                                style:
                                    TextStyle(color: dateColor, fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showAiTagRow)
                              _noticeCategoryAndAiTagsRow(
                                context: context,
                                categoryLabel: type,
                                aiTags: aiTags,
                                primaryChipBackground: chipBackground,
                                primaryChipForeground: chipForeground,
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: chipBackground,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  type,
                                  style: TextStyle(
                                    color: chipForeground,
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
                                fontWeight: FontWeight.bold,
                                color: titleColor,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 14,
                                  color: dateColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  dateStr,
                                  style:
                                      TextStyle(color: dateColor, fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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
      child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: widget.child),
    );
  }
}
