import "dart:math" show max;
import "dart:ui" show lerpDouble;

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:mio_notice/main_website_prefs.dart";
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
  String? selectedAiTag,
}) {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  final String selected = (selectedAiTag ?? "").trim();
  final bool hasSelected = selected.isNotEmpty && selected != "전체";
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
        (String t) {
          final bool highlight = hasSelected && t.trim() == selected;
          final Color bg = highlight
              ? (isDark
                  ? scheme.primary.withValues(alpha: 0.28)
                  : scheme.primary.withValues(alpha: 0.16))
              : scheme.surfaceContainerHighest.withValues(alpha: 0.55);
          final Color border = highlight ? scheme.primary : scheme.outlineVariant;
          final Color fg =
              highlight ? scheme.primary : scheme.onSurfaceVariant;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: border),
            ),
            child: Text(
              t,
              style: TextStyle(
                color: fg,
                fontSize: 10,
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          );
        },
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
    // 초기값 로드 (설정에서 변경 시 ValueNotifier로 즉시 반영됨)
    MainWebsitePrefs.ensureLoaded();
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
      scopeId: "mjc_main",
      scopeLabel: "본교 공지사항",
    );
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
    // 홈 대시보드와 동일: 헤더 히어로(상태바 제외 본문)가 너비 대비 16:9.
    final double bannerHeight16x9 = viewportW * 9 / 16;
    final double heroBody = max(120.0, bannerHeight16x9 - topPad);
    return ValueListenableBuilder<MainWebsiteNoticeViewMode>(
      valueListenable: MainWebsitePrefs.noticeViewMode,
      builder: (context, mode, _) {
        final bool useTabs = mode == MainWebsiteNoticeViewMode.tabs;
        final ColorScheme scheme = Theme.of(context).colorScheme;
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final Color tabAccent = isDark ? scheme.primary : scheme.primary;

        final PreferredSizeWidget? tabBar = useTabs
            ? TabBar(
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
              )
            : null;

        final Widget body = Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: NestedScrollView(
            key: _nestedScrollKey,
            controller: _outerScrollController,
            headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
              return <Widget>[
                SliverOverlapAbsorber(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                  sliver: SliverPersistentHeader(
                    pinned: true,
                    delegate: _MainWebsiteCollapsingHeaderDelegate(
                      topPadding: topPad,
                      heroBody: heroBody,
                      onOpenFilter: _openNoticeFilterSheet,
                      onSearch: _openGlobalSearch,
                      bottom: tabBar,
                      overlapsContent: innerBoxIsScrolled,
                    ),
                  ),
                ),
              ];
            },
            body: NotificationListener<ScrollNotification>(
              onNotification: _nestedFabReporter.handleInnerScrollNotification,
              child: useTabs
                  ? NestedScrollFabTabBinding(
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
                    )
                  : _UnifiedNoticeList(
                      entryTick: _entryTick,
                      filterRevision: _filterReloadTick,
                    ),
            ),
          ),
        );

        if (!useTabs) return body;
        return DefaultTabController(length: 3, child: body);
      },
    );
  }
}

/// 홈 히어로와 같이 스크롤에 따라 상단 영역이 접히고, 탭 바는 아래에 고정됩니다.
class _MainWebsiteCollapsingHeaderDelegate
    extends SliverPersistentHeaderDelegate {
  _MainWebsiteCollapsingHeaderDelegate({
    required this.topPadding,
    required this.heroBody,
    required this.onOpenFilter,
    required this.onSearch,
    this.bottom,
    required this.overlapsContent,
  });

  final double topPadding;
  final double heroBody;
  final VoidCallback onOpenFilter;
  final VoidCallback onSearch;
  final PreferredSizeWidget? bottom;
  final bool overlapsContent;

  static const double _collapsedBar = 52;
  double get _bottomHeight => bottom?.preferredSize.height ?? 0;

  @override
  double get maxExtent => topPadding + heroBody + _bottomHeight;

  @override
  double get minExtent => topPadding + _collapsedBar + _bottomHeight;

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
    final double heroH = extent - _bottomHeight;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double bannerImageOpacity = (1.0 - u).clamp(0.0, 1.0);

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
                  ColoredBox(
                    color: isDark ? const Color(0xFF073A8C) : AppColors.primary,
                  ),
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
                        return Opacity(
                          opacity: bannerImageOpacity,
                          child: Image.asset(
                            "assets/images/mjc.png",
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
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
                  SafeArea(
                    bottom: false,
                    minimum: EdgeInsets.zero,
                    child: LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                        final double ih = constraints.maxHeight;
                        final double menuTopInset = ih >= 54
                            ? 6.0
                            : max(0.0, (ih - 48) / 2);
                        final double titleSize =
                            lerpDouble(34, 20, u)!;
                        const double titleLeft = 24;
                        const double toolbarSlot = 104;
                        final double collapsedTitleTop =
                            (ih - titleSize * 1.15) / 2;
                        final double titleReveal =
                            ((u - 0.70) / 0.30).clamp(0.0, 1.0);
                        final double titleOpacity = Curves.easeOutCubic
                            .transform(titleReveal);
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
                                  child: const Text(
                                    "본교 공지",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      height: 1.1,
                                      shadows: <Shadow>[
                                        Shadow(
                                          blurRadius: 6,
                                          color: Color(0x66000000),
                                        ),
                                      ],
                                    ),
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
                                  padding:
                                      EdgeInsets.only(top: menuTopInset),
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
                                        icon:
                                            const Icon(Icons.search_rounded),
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
            if (bottom != null)
              Material(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.surfaceContainer
                    : Theme.of(context).colorScheme.surface,
                elevation: overlapsContent ? 0.5 : 0,
                shadowColor: Colors.black.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark ? 0.45 : 0.12,
                ),
                child: SizedBox(
                  height: _bottomHeight,
                  child: bottom,
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
        onOpenFilter != old.onOpenFilter ||
        onSearch != old.onSearch ||
        bottom != old.bottom ||
        overlapsContent != old.overlapsContent;
  }
}

class _UnifiedNoticeList extends StatefulWidget {
  const _UnifiedNoticeList({
    required this.entryTick,
    required this.filterRevision,
  });

  final int entryTick;
  final ValueListenable<int> filterRevision;

  @override
  State<_UnifiedNoticeList> createState() => _UnifiedNoticeListState();
}

class _UnifiedNoticeListState extends State<_UnifiedNoticeList> {
  static const List<_BoardSpec> _boards = <_BoardSpec>[
    _BoardSpec(boardId: "main_notice", label: "공지사항"),
    _BoardSpec(boardId: "main_academic", label: "학사공지"),
    _BoardSpec(boardId: "main_scholarship", label: "장학공지"),
  ];

  final _MainWebsiteListEntrance _entrance = _MainWebsiteListEntrance();

  final Map<String, Set<String>> _readIdsByBoard = {};
  final Map<String, Set<String>> _pinnedKeysByBoard = {};
  final Map<String, Set<String>> _favoriteKeysByBoard = {};

  NoticeFilterState _noticeFilter = const NoticeFilterState();
  List<String> _noticeSharedKeywords = [];

  String _aiTagChipSelection = "전체";

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
    _loadNoticeFilter();
    _loadReadHistory();
    _loadPinsAndFavorites();
    _noticeFuture = _loadAllNotices();
  }

  @override
  void didUpdateWidget(covariant _UnifiedNoticeList oldWidget) {
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

  Future<List<Map<String, dynamic>>> _loadAllNotices({bool forceRefresh = false}) async {
    final futures = <Future<List<Map<String, dynamic>>>>[
      for (final b in _boards)
        NoticeManager().getNotices(boardId: b.boardId, forceRefresh: forceRefresh),
    ];
    final results = await Future.wait(futures);

    final List<Map<String, dynamic>> merged = [];
    for (int i = 0; i < results.length; i++) {
      final b = _boards[i];
      for (final d in results[i]) {
        merged.add({
          ...d,
          "_boardId": b.boardId,
          "_boardLabel": b.label,
          // 기존 필터/검색 UI가 category/type/date 같은 키를 참고하는 경우가 있어
          // 보조 필드를 채워두되, 원본 키는 그대로 둡니다.
          "_typeLabel": (d["category"] ?? b.label).toString(),
          "_source": "메인 공지사항",
        });
      }
    }
    return merged;
  }

  String _boardIdOf(Map<String, dynamic> data) {
    final String v = (data["_boardId"] ?? "").toString().trim();
    return v.isNotEmpty ? v : "main_notice";
  }

  String _fallbackTypeForBoard(String boardId) {
    switch (boardId) {
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
    final bool enabled = await loadScopedNoticeFilterEnabled("mjc_main");
    final List<String> includes = await loadScopedNoticeFilterIncludes("mjc_main");
    if (!mounted) return;
    setState(() {
      _noticeFilter = filter.copyWith(
        enabled: enabled,
        quickQuery: "",
        // 이 화면에서는 "본교 공지"만 대상으로 동작하도록 강제합니다.
        sources: const ["MJC"],
        types: kNoticeFilterTypeOptions,
        excludes: const [],
        requireKeywordHit: false,
        includes: includes,
      );
      _noticeSharedKeywords = keywords;
    });
  }

  Future<void> _loadReadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (final b in _boards) {
        _readIdsByBoard[b.boardId] =
            (prefs.getStringList("read_notices_${b.boardId}") ?? []).toSet();
      }
    });
  }

  String _noticeKey(String boardId, Map<String, dynamic> data) {
    final String id = (data["id"] ?? "").toString().trim();
    if (id.isNotEmpty) return "$boardId|$id";
    final String url = (data["url"] ?? data["link"] ?? "").toString().trim();
    final String title = (data["title"] ?? "").toString().trim();
    final String date =
        (data["date"] ?? data["reg_date"] ?? "").toString().trim();
    return "$boardId|$url|$title|$date";
  }

  Future<void> _loadPinsAndFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (final b in _boards) {
        _pinnedKeysByBoard[b.boardId] =
            (prefs.getStringList("pinned_notices_${b.boardId}") ?? []).toSet();
        _favoriteKeysByBoard[b.boardId] =
            (prefs.getStringList("favorite_notices_${b.boardId}") ?? []).toSet();
      }
    });
  }

  Future<void> _togglePinned(String boardId, String key) async {
    final prefs = await SharedPreferences.getInstance();
    final Set<String> cur = _pinnedKeysByBoard[boardId] ?? <String>{};
    final Set<String> next = {...cur};
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    if (mounted) {
      setState(() => _pinnedKeysByBoard[boardId] = next);
    }
    await prefs.setStringList("pinned_notices_$boardId", next.toList());
    await UserDataRepository.instance.updateBookmarks(
      boardId,
      pinned: true,
      values: next.toList(),
    );
  }

  Future<void> _toggleFavorite(String boardId, String key) async {
    final prefs = await SharedPreferences.getInstance();
    final Set<String> cur = _favoriteKeysByBoard[boardId] ?? <String>{};
    final Set<String> next = {...cur};
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    if (mounted) {
      setState(() => _favoriteKeysByBoard[boardId] = next);
    }
    await prefs.setStringList("favorite_notices_$boardId", next.toList());
    await UserDataRepository.instance.updateBookmarks(
      boardId,
      pinned: false,
      values: next.toList(),
    );
  }

  Future<void> _markAsRead(String boardId, String id) async {
    if (id.trim().isEmpty) return;
    final Set<String> cur = _readIdsByBoard[boardId] ?? <String>{};
    if (cur.contains(id)) return;
    final prefs = await SharedPreferences.getInstance();
    final Set<String> next = {...cur, id};
    if (!mounted) return;
    setState(() => _readIdsByBoard[boardId] = next);
    await prefs.setStringList("read_notices_$boardId", next.toList());
  }

  Future<void> _handleRefresh() async {
    await _loadNoticeFilter();
    setState(() {
      _noticeFuture = _loadAllNotices(forceRefresh: true);
    });
    await _noticeFuture;
  }

  List<Map<String, dynamic>> _applyAiTagChipFilter(List<Map<String, dynamic>> rows) {
    if (_aiTagChipSelection == "전체") return rows;
    return rows.where((Map<String, dynamic> d) {
      final Object? raw = d["ai_tags"];
      if (raw is! List) {
        return _aiTagChipSelection == "기타";
      }
      final List<String> tags = raw
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
      return tags.contains(_aiTagChipSelection);
    }).toList();
  }

  Widget _buildAiTagChipBar(BuildContext context) {
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
              final bool selected = _aiTagChipSelection == label;
              final Color bg = selected
                  ? (isDark ? scheme.primary : const Color(0xFF0F0F0F))
                  : (isDark
                      ? scheme.surfaceContainerHighest
                      : const Color(0xFFF2F2F2));
              final Color fg = selected
                  ? (isDark ? scheme.onPrimary : Colors.white)
                  : (isDark ? scheme.onSurface : const Color(0xFF0F0F0F));
              return Material(
                color: bg,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  onTap: () {
                    if (_aiTagChipSelection == label) return;
                    setState(() => _aiTagChipSelection = label);
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: fg,
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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

  DateTime _parseDateLoose(String raw) {
    final String s = raw.trim();
    if (s.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    try {
      return DateTime.parse(s);
    } catch (_) {
      final String digits = s.replaceAll(RegExp(r"[^0-9]"), "");
      if (digits.length >= 8) {
        final int y = int.tryParse(digits.substring(0, 4)) ?? 0;
        final int m = int.tryParse(digits.substring(4, 6)) ?? 1;
        final int d = int.tryParse(digits.substring(6, 8)) ?? 1;
        if (y > 0) return DateTime(y, m, d);
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
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
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                ..._buildNoticeSlivers(context, snapshot.data ?? const []),
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
    // 기존 NoticeFilter는 1개 boardId 기준 fallbackType을 받기 때문에,
    // 통합 리스트에서는 fallback을 "공지사항"으로 고정하고, 글마다 board tag로 구분합니다.
    final NoticeFilterState filter = _noticeFilter.copyWith(quickQuery: "");
    final List<Map<String, dynamic>> filteredDocs = filter.apply(
      docs,
      sharedKeywords: _noticeSharedKeywords,
      fallbackSource: "MJC",
      fallbackType: "공지사항",
    );

    final List<Map<String, dynamic>> aiFiltered = _applyAiTagChipFilter(filteredDocs);

    if (filteredDocs.isEmpty) {
      return [
        SliverToBoxAdapter(child: _buildAiTagChipBar(context)),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 48),
              Text(
                docs.isEmpty ? "표시할 공지가 없습니다." : "필터에 맞는 공지가 없습니다.",
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ];
    }

    if (aiFiltered.isEmpty) {
      return [
        SliverToBoxAdapter(child: _buildAiTagChipBar(context)),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 48),
              Text(
                "선택한 필터에 맞는 공지가 없습니다.",
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ];
    }

    final List<Map<String, dynamic>> ordered = [...aiFiltered];
    ordered.sort((a, b) {
      final String da = (a["date"] ?? a["reg_date"] ?? "").toString();
      final String db = (b["date"] ?? b["reg_date"] ?? "").toString();
      return _parseDateLoose(db).compareTo(_parseDateLoose(da));
    });

    // 핀 우선 정렬(게시판별로 유지)
    final List<Map<String, dynamic>> pinnedFirst = [];
    final List<Map<String, dynamic>> rest = [];
    for (final d in ordered) {
      final String boardId = _boardIdOf(d);
      final String key = _noticeKey(boardId, d);
      final bool pinned = (_pinnedKeysByBoard[boardId] ?? const <String>{}).contains(key);
      (pinned ? pinnedFirst : rest).add(d);
    }
    final List<Map<String, dynamic>> finalOrdered = [...pinnedFirst, ...rest];

    return [
      SliverToBoxAdapter(child: _buildAiTagChipBar(context)),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              if (index == 0 && _entrance.shouldAnimateList) {
                _entrance.scheduleEndEntranceAnimation();
              }
              final data = finalOrdered[index];
              final String boardId = _boardIdOf(data);
              final String id = (data["id"] ?? "").toString();
              final bool isRead = (_readIdsByBoard[boardId] ?? const <String>{}).contains(id);
              final String key = _noticeKey(boardId, data);
              final bool isPinned = (_pinnedKeysByBoard[boardId] ?? const <String>{}).contains(key);
              final bool isFavorite =
                  (_favoriteKeysByBoard[boardId] ?? const <String>{}).contains(key);

              Future<void> openDetail() async {
                await _markAsRead(boardId, id);
                if (!context.mounted) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => NoticeDetailScreen(
                      notice: data,
                      boardId: boardId,
                      isPinned: isPinned,
                      isFavorite: isFavorite,
                      onTogglePinned: () => _togglePinned(boardId, key),
                      onToggleFavorite: () => _toggleFavorite(boardId, key),
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
                  openDetail,
                  boardLabel: (data["_boardLabel"] ?? _fallbackTypeForBoard(boardId)).toString(),
                  showAiTagChips: true,
                  isPinned: isPinned,
                  isFavorite: isFavorite,
                  onTogglePinned: () => _togglePinned(boardId, key),
                  onToggleFavorite: () => _toggleFavorite(boardId, key),
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
            childCount: finalOrdered.length,
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
    required String boardLabel,
    required bool showAiTagChips,
    required bool isPinned,
    required bool isFavorite,
    required VoidCallback onTogglePinned,
    required VoidCallback onToggleFavorite,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens = Theme.of(context).extension<MjcSurfaceTokens>()!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color readTitlePurple =
        isDark ? const Color(0xFFB39DDB) : const Color(0xFF7E57C2);
    final String title = (data["title"] ?? "").toString();
    final String dateStr = (data["date"] ?? data["reg_date"] ?? "").toString();
    final String category = (data["category"] ?? "").toString().trim();

    // 상단 칩: 원래 category가 있으면 그것을 우선 노출, 없으면 게시판 라벨.
    final String typeLabel = category.isNotEmpty ? category : boardLabel;

    final List<String> aiTags =
        showAiTagChips ? _parseAiTagsForList(data) : const <String>[];
    final bool showAiTagRow = showAiTagChips && aiTags.isNotEmpty;

    final Color mainColor = isRead ? scheme.onSurfaceVariant : tokens.sourceMjc;
    final Color chipBackground = tokens.sourceMjc.withValues(alpha: isDark ? 0.18 : 0.12);
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
                              categoryLabel: typeLabel,
                              aiTags: aiTags,
                              primaryChipBackground: chipBackground,
                              primaryChipForeground: chipForeground,
                              selectedAiTag: _aiTagChipSelection,
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                style: TextStyle(color: dateColor, fontSize: 13),
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
                                categoryLabel: typeLabel,
                                aiTags: aiTags,
                                primaryChipBackground: chipBackground,
                                primaryChipForeground: chipForeground,
                                selectedAiTag: _aiTagChipSelection,
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                  style: TextStyle(color: dateColor, fontSize: 13),
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

class _BoardSpec {
  final String boardId;
  final String label;
  const _BoardSpec({required this.boardId, required this.label});
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
    final bool enabled = await loadScopedNoticeFilterEnabled("mjc_main");
    final List<String> includes = await loadScopedNoticeFilterIncludes("mjc_main");
    if (!mounted) return;
    setState(() {
      _noticeFilter = filter.copyWith(
        enabled: enabled,
        quickQuery: "",
        sources: const ["MJC"],
        types: kNoticeFilterTypeOptions,
        excludes: const [],
        requireKeywordHit: false,
        includes: includes,
      );
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
                              selectedAiTag: _mainNoticeAiTagChipSelection,
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
                                selectedAiTag: _mainNoticeAiTagChipSelection,
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
