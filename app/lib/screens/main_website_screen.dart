import "dart:math" show max;
import "dart:ui" show lerpDouble;

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:mjc_in_one/lab_prefs.dart";
import "package:mjc_in_one/main_website_prefs.dart";
import "package:mjc_in_one/screens/notice_detail_screen.dart";
import "package:mjc_in_one/screens/notices_sub_tab_utils.dart";
import "package:mjc_in_one/screens/notices_tab_screen.dart";
import "package:mjc_in_one/services/app_config_service.dart";
import "package:mjc_in_one/services/notice_filter.dart";
import "package:mjc_in_one/services/notice_manager.dart";
import "package:mjc_in_one/services/user_data_repository.dart";
import "package:mjc_in_one/theme/app_theme.dart";
import "package:mjc_in_one/utils/bookmark_added_feedback.dart";
import "package:mjc_in_one/utils/notice_list_refresh_guard.dart";
import "package:mjc_in_one/perf_flags.dart";
import "package:mjc_in_one/widgets/mjc_notice_list_item.dart";
import "package:mjc_in_one/widgets/nested_scroll_refresh_indicator.dart";
import "package:mjc_in_one/widgets/collapsed_hero_title.dart";
import "package:mjc_in_one/widgets/global_notice_search_sheet.dart";
import "package:mjc_in_one/widgets/main_navigation_scope.dart";
import "package:mjc_in_one/widgets/main_notice_ai_tag_chip_bar.dart";
import "package:mjc_in_one/widgets/notice_filter_sheet.dart";
import "package:mjc_in_one/widgets/scroll_to_top_scope.dart";
import "package:shared_preferences/shared_preferences.dart";

List<String> _parseAiTagsForList(Map<String, dynamic> data) {
  final Object? v = data["ai_tags"];
  if (v is! List) return const <String>[];
  return v
      .map((e) => e.toString())
      .where((s) => s.trim().isNotEmpty)
      .take(2)
      .toList();
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
  const MainWebsiteScreen({
    super.key,
    this.activeInNoticesTab = true,
    this.noticeSubTabNotifier,
  });

  final bool activeInNoticesTab;
  final ValueNotifier<NoticesSubTab>? noticeSubTabNotifier;

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
      onFilterChanged: _reloadNoticeFilter,
    );
    _reloadNoticeFilter();
  }

  void _reloadNoticeFilter() {
    if (mounted) {
      _filterReloadTick.value++;
    }
  }

  String _globalSearchBoardIdOf(Map<String, dynamic> item) {
    final String v = (item["_boardId"] ?? "").toString().trim();
    if (v.isNotEmpty) return v;
    switch ((item["_searchType"] ?? "").toString()) {
      case "학사공지":
        return "main_academic";
      case "장학공지":
        return "main_scholarship";
      default:
        return "main_notice";
    }
  }

  String _globalSearchNoticeKey(String boardId, Map<String, dynamic> data) {
    final String id = (data["id"] ?? "").toString().trim();
    if (id.isNotEmpty) return "$boardId|$id";
    final String url = (data["url"] ?? data["link"] ?? "").toString().trim();
    final String title = (data["title"] ?? "").toString().trim();
    final String date =
        (data["date"] ?? data["reg_date"] ?? "").toString().trim();
    return "$boardId|$url|$title|$date";
  }

  Future<void> _toggleGlobalSearchPinned(String boardId, String key) async {
    final prefs = await SharedPreferences.getInstance();
    final Set<String> cur =
        (prefs.getStringList("pinned_notices_$boardId") ?? []).toSet();
    final bool adding = !cur.contains(key);
    final Set<String> next = {...cur};
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    await prefs.setStringList("pinned_notices_$boardId", next.toList());
    await UserDataRepository.instance.updateBookmarks(
      boardId,
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

  Future<void> _toggleGlobalSearchFavorite(String boardId, String key) async {
    final prefs = await SharedPreferences.getInstance();
    final Set<String> cur =
        (prefs.getStringList("favorite_notices_$boardId") ?? []).toSet();
    final bool adding = !cur.contains(key);
    final Set<String> next = {...cur};
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    await prefs.setStringList("favorite_notices_$boardId", next.toList());
    await UserDataRepository.instance.updateBookmarks(
      boardId,
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

  Future<void> _openNoticeFromGlobalSearch(Map<String, dynamic> item) async {
    final String boardId = _globalSearchBoardIdOf(item);
    final String id = (item["id"] ?? "").toString().trim();
    final String key = _globalSearchNoticeKey(boardId, item);

    final prefs = await SharedPreferences.getInstance();
    if (id.isNotEmpty) {
      final Set<String> read =
          (prefs.getStringList("read_notices_$boardId") ?? []).toSet();
      if (!read.contains(id)) {
        await prefs.setStringList(
          "read_notices_$boardId",
          [...read, id].toList(),
        );
      }
    }

    if (!mounted) return;

    final Set<String> pinned =
        (prefs.getStringList("pinned_notices_$boardId") ?? []).toSet();
    final Set<String> favorites =
        (prefs.getStringList("favorite_notices_$boardId") ?? []).toSet();

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => NoticeDetailScreen(
          notice: item,
          boardId: boardId,
          isPinned: pinned.contains(key),
          isFavorite: favorites.contains(key),
          onTogglePinned: () => _toggleGlobalSearchPinned(boardId, key),
          onToggleFavorite: () => _toggleGlobalSearchFavorite(boardId, key),
        ),
      ),
    );
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

      final MjcSurfaceTokens tokens =
          Theme.of(context).extension<MjcSurfaceTokens>()!;
      final List<Map<String, dynamic>> items = [];
      void addAll(
        List<Map<String, dynamic>> docs,
        String boardId,
        String type,
      ) {
        for (final d in docs) {
          items.add({
            ...d,
            "_boardId": boardId,
            "_searchType": type,
            "_searchSource": "메인 공지사항",
          });
        }
      }

      addAll(results[0], "main_notice", "공지사항");
      addAll(results[1], "main_academic", "학사공지");
      addAll(results[2], "main_scholarship", "장학공지");

      await showGlobalNoticeSearchSheet(
        context,
        items: items,
        accentColor: tokens.sourceMjc,
        scopeLabel: "본교 공지사항",
        openItem: _openNoticeFromGlobalSearch,
        boardIdFor: _globalSearchBoardIdOf,
        noticeKeyFor: (item) =>
            _globalSearchNoticeKey(_globalSearchBoardIdOf(item), item),
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
        final MjcSurfaceTokens tokens =
            Theme.of(context).extension<MjcSurfaceTokens>()!;
        final Color tabAccent = tokens.sourceMjc;

        final PreferredSizeWidget? tabBar = useTabs
            ? TabBar(
                indicator: UnderlineTabIndicator(
                  borderSide: BorderSide(color: tabAccent, width: 3),
                ),
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: tabAccent,
                unselectedLabelColor: scheme.onSurfaceVariant,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                tabs: const [
                  Tab(height: kTextTabBarHeight, text: "공지사항"),
                  Tab(height: kTextTabBarHeight, text: "학사공지"),
                  Tab(height: kTextTabBarHeight, text: "장학공지"),
                ],
              )
            : null;

        final Widget body = Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: NestedScrollView(
            key: _nestedScrollKey,
            controller: _outerScrollController,
            headerSliverBuilder:
                (BuildContext context, bool innerBoxIsScrolled) {
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
                      noticeSubTabNotifier: widget.noticeSubTabNotifier,
                      bottom: tabBar,
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
                        children: [
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
    required this.noticeSubTabNotifier,
    this.bottom,
  });

  final double topPadding;
  final double heroBody;
  final VoidCallback onOpenFilter;
  final VoidCallback onSearch;
  final ValueNotifier<NoticesSubTab>? noticeSubTabNotifier;
  final PreferredSizeWidget? bottom;

  static const double _collapsedBar = 52;
  static const Color _overlayTop = Color(0xFF0043A1);
  static const Color _overlayBottom = Color(0xFF005AB5);

  /// Collapsed 시 배너 패턴이 은은하게 비치도록 overlay 불투명도 (~8–10%).
  static const double _collapsedOverlayOpacity = 0.90;

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
    // Overlay는 easeOutCubic — 스크롤 초반부터 자연스럽게 응축되는 느낌.
    final double overlayT = Curves.easeOutCubic.transform(t);
    final double u = Curves.easeInOut.transform(t);
    final double heroH = extent - _bottomHeight;
    final double overlayOpacity =
        lerpDouble(0.0, _collapsedOverlayOpacity, overlayT)!;
    final Alignment imageAlignment = Alignment.lerp(
      Alignment.center,
      const Alignment(0, -0.35),
      overlayT,
    )!;
    final double bannerScale = lerpDouble(1.04, 1.02, overlayT)!;
    // 글씨 아래 얇은 띠만 막고, 상단은 패턴이 은은히 보이도록 하단만 살짝 더 덮음.
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
                  const ColoredBox(color: _overlayTop),
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
                            "assets/images/mjc.png",
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
                        const double toolbarSlot = 88;
                        final double collapsedTitleTop =
                            (ih - titleSize * 1.15) / 2;
                        final double titleReveal =
                            ((t - 0.92) / 0.08).clamp(0.0, 1.0);
                        final double titleOpacity =
                            Curves.easeOutCubic.transform(titleReveal);
                        final TextStyle collapsedTitleStyle = Theme.of(context)
                            .extension<MjcTextTokens>()!
                            .appBarTitle;
                        return Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            Positioned(
                              left: 12,
                              top: menuTopInset,
                              right: 4,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  const Spacer(),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 40,
                                      minHeight: 40,
                                    ),
                                    tooltip: "공지 목록 필터",
                                    onPressed: onOpenFilter,
                                    icon: const Icon(Icons.tune_rounded),
                                    color: Colors.white,
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 40,
                                      minHeight: 40,
                                    ),
                                    tooltip: "검색",
                                    onPressed: onSearch,
                                    icon: const Icon(Icons.search_rounded),
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              left: titleLeft,
                              top: collapsedTitleTop,
                              right: toolbarSlot,
                              child: IgnorePointer(
                                ignoring: titleOpacity < 0.02,
                                child: Opacity(
                                  opacity: titleOpacity,
                                  child: noticeSubTabNotifier == null
                                      ? CollapsedHeroTitle(
                                          icon: Icons.school_rounded,
                                          text: "본교 공지사항",
                                          baseStyle: collapsedTitleStyle,
                                        )
                                      : ValueListenableBuilder<bool>(
                                          valueListenable:
                                              LabPrefs.departmentNoticesEnabled,
                                          builder: (context, labEnabled, _) {
                                            return ValueListenableBuilder<
                                                NoticesSubTab>(
                                              valueListenable:
                                                  noticeSubTabNotifier!,
                                              builder: (context, current, _) {
                                                final List<NoticesSubTab> tabs =
                                                    visibleNoticeSubTabs(
                                                        labEnabled);
                                                final NoticesSubTab selected =
                                                    tabs.contains(current)
                                                        ? current
                                                        : NoticesSubTab.main;
                                                return CollapsedHeroTitle(
                                                  icon: selected.icon,
                                                  text: selected ==
                                                          NoticesSubTab.main
                                                      ? "본교 공지사항"
                                                      : selected.label,
                                                  baseStyle:
                                                      collapsedTitleStyle,
                                                );
                                              },
                                            );
                                          },
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
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.45
                      : 0.12,
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
        noticeSubTabNotifier != old.noticeSubTabNotifier ||
        bottom != old.bottom;
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

class _NestedScrollOverlapSpacer extends StatefulWidget {
  const _NestedScrollOverlapSpacer();

  @override
  State<_NestedScrollOverlapSpacer> createState() =>
      _NestedScrollOverlapSpacerState();
}

class _NestedScrollOverlapSpacerState
    extends State<_NestedScrollOverlapSpacer> {
  SliverOverlapAbsorberHandle? _handle;
  double _extent = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final SliverOverlapAbsorberHandle handle =
        NestedScrollView.sliverOverlapAbsorberHandleFor(context);
    if (!identical(handle, _handle)) {
      _handle?.removeListener(_onHandleChanged);
      _handle = handle;
      _handle!.addListener(_onHandleChanged);
      // Read initial value — safe here because we are not inside a build call.
      _extent = handle.layoutExtent ?? 0;
    }
  }

  void _onHandleChanged() {
    // The handle fires during layout, which may overlap with an active build
    // pass for sibling widgets. Defer the setState to the next frame to avoid
    // the "setState() called during build" assertion.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _extent = _handle?.layoutExtent ?? 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _handle?.removeListener(_onHandleChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: _extent);
  }
}

class _UnifiedNoticeListState extends State<_UnifiedNoticeList>
    with SingleTickerProviderStateMixin {
  static const List<_BoardSpec> _boardsFallback = <_BoardSpec>[
    _BoardSpec(boardId: "main_notice", label: "공지사항"),
    _BoardSpec(boardId: "main_academic", label: "학사공지"),
    _BoardSpec(boardId: "main_scholarship", label: "장학공지"),
  ];
  List<_BoardSpec> _boards = List<_BoardSpec>.from(_boardsFallback);
  List<String> _aiTagChips = List<String>.from(kMainNoticeAiTagFilterChips);

  final _MainWebsiteListEntrance _entrance = _MainWebsiteListEntrance();

  final Map<String, Set<String>> _readIdsByBoard = {};
  final Map<String, Set<String>> _pinnedKeysByBoard = {};
  final Map<String, Set<String>> _favoriteKeysByBoard = {};

  NoticeFilterState _noticeFilter = const NoticeFilterState();
  List<String> _noticeSharedKeywords = [];

  String _aiTagChipSelection = "전체";

  TabController? _aiTagTabController;

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
    _loadNoticesUiConfig();
    _loadReadHistory();
    _loadPinsAndFavorites();
    _noticeFuture = _loadAllNotices();
    _syncAiTagTabController();
  }

  Future<void> _loadNoticesUiConfig() async {
    try {
      final NoticesUiConfig? cfg = await AppConfigService.loadNoticesUi();
      if (!mounted || cfg == null) return;

      final List<_BoardSpec> boards = cfg.boards
          .map((m) => _BoardSpec(
                boardId: (m["boardId"] ?? "").toString().trim(),
                label: (m["label"] ?? "").toString().trim(),
              ))
          .where((b) => b.boardId.isNotEmpty && b.label.isNotEmpty)
          .toList();

      final List<String> chips = cfg.aiTagChips.isEmpty
          ? _aiTagChips
          : (cfg.aiTagChips.contains("전체")
              ? cfg.aiTagChips
              : <String>["전체", ...cfg.aiTagChips]);

      setState(() {
        if (boards.isNotEmpty) _boards = boards;
        if (chips.isNotEmpty) {
          _aiTagChips = chips;
          if (!_aiTagChips.contains(_aiTagChipSelection)) {
            _aiTagChipSelection = "전체";
          }
          _syncAiTagTabController();
        }
      });
    } catch (_) {
      // Keep fallback.
    }
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
    _aiTagTabController?.removeListener(_onAiTagTabIndexChanged);
    _aiTagTabController?.dispose();
    super.dispose();
  }

  void _syncAiTagTabController() {
    if (_aiTagChips.isEmpty) return;
    final int length = _aiTagChips.length;
    if (_aiTagTabController != null && _aiTagTabController!.length == length) {
      return;
    }
    _aiTagTabController?.removeListener(_onAiTagTabIndexChanged);
    _aiTagTabController?.dispose();
    final int initialIndex = _aiTagChips.indexOf(_aiTagChipSelection);
    final int safeIndex = initialIndex < 0
        ? 0
        : initialIndex.clamp(0, length - 1);
    _aiTagChipSelection = _aiTagChips[safeIndex];
    _aiTagTabController = TabController(
      length: length,
      vsync: this,
      initialIndex: safeIndex,
    )..addListener(_onAiTagTabIndexChanged);
  }

  void _onAiTagTabIndexChanged() {
    final TabController? c = _aiTagTabController;
    if (c == null || c.indexIsChanging) return;
    final String label = _aiTagChips[c.index];
    if (_aiTagChipSelection == label) return;
    setState(() => _aiTagChipSelection = label);
  }

  Future<List<Map<String, dynamic>>> _loadAllNotices(
      {bool forceRefresh = false}) async {
    final futures = <Future<List<Map<String, dynamic>>>>[
      for (final b in _boards)
        NoticeManager()
            .getNotices(boardId: b.boardId, forceRefresh: forceRefresh),
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
    final List<String> includes =
        await loadScopedNoticeFilterIncludes("mjc_main");
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
            (prefs.getStringList("favorite_notices_${b.boardId}") ?? [])
                .toSet();
      }
    });
  }

  Future<void> _togglePinned(String boardId, String key) async {
    final prefs = await SharedPreferences.getInstance();
    final Set<String> cur = _pinnedKeysByBoard[boardId] ?? <String>{};
    final bool adding = !cur.contains(key);
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
    if (!mounted) return;
    if (adding) {
      showBookmarkAddedSnackBar(context, openPinnedTab: true);
    } else {
      showBookmarkRemovedSnackBar(context, wasPinned: true);
    }
  }

  Future<void> _toggleFavorite(String boardId, String key) async {
    final prefs = await SharedPreferences.getInstance();
    final Set<String> cur = _favoriteKeysByBoard[boardId] ?? <String>{};
    final bool adding = !cur.contains(key);
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
    if (!mounted) return;
    if (adding) {
      showBookmarkAddedSnackBar(context, openPinnedTab: false);
    } else {
      showBookmarkRemovedSnackBar(context, wasPinned: false);
    }
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
    final bool forceRefresh =
        NoticeListRefreshGuard.allowForceRefresh("main_website_unified");
    setState(() {
      _noticeFuture = _loadAllNotices(forceRefresh: forceRefresh);
    });
    await _noticeFuture;
    if (!forceRefresh && mounted) {
      NoticeListRefreshGuard.showThrottledMessage(
        context,
        key: "main_website_unified_refresh_throttled",
      );
    }
  }

  List<Map<String, dynamic>> _applyAiTagChipFilter(
    List<Map<String, dynamic>> rows,
    String chipSelection,
  ) {
    if (chipSelection == "전체") return rows;
    return rows.where((Map<String, dynamic> d) {
      final Object? raw = d["ai_tags"];
      if (raw is! List) {
        return chipSelection == "기타";
      }
      final List<String> tags = raw
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
      return tags.contains(chipSelection);
    }).toList();
  }

  Widget _buildAiTagChipBar(BuildContext context) {
    final TabController? controller = _aiTagTabController;
    if (controller == null) {
      return MainNoticeAiTagChipBar(
        chips: _aiTagChips,
        selection: _aiTagChipSelection,
      );
    }

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    return Material(
      color: scheme.surface,
      child: SizedBox(
        height: kMainNoticeAiTagFilterBarHeight,
        child: TabBar(
          controller: controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(
              color: tokens.sourceMjc,
              width: kMainNoticeAiTagFilterIndicatorHeight,
            ),
          ),
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
          labelColor: tokens.sourceMjc,
          unselectedLabelColor: scheme.onSurfaceVariant,
          labelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          tabs: [
            for (final String chip in _aiTagChips)
              Tab(
                height: kMainNoticeAiTagFilterBarHeight,
                text: chip,
              ),
          ],
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

  Widget _buildRefreshableScroll(
    BuildContext context, {
    required ColorScheme scheme,
    required MjcSurfaceTokens tokens,
    required List<Widget> slivers,
    bool includeNestedHeaderOffset = true,
  }) {
    return NestedScrollRefreshIndicator(
      onRefresh: _handleRefresh,
      color: tokens.sourceMjc,
      backgroundColor: scheme.surface,
      tabBarHeight: 0,
      includeNestedHeaderOffset: includeNestedHeaderOffset,
      notificationPredicate: _allowRefreshNotification,
      child: CustomScrollView(
        primary: true,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: slivers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _noticeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildRefreshableScroll(
            context,
            scheme: scheme,
            tokens: tokens,
            slivers: [
              SliverOverlapInjector(
                handle:
                    NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              ),
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        }

        final List<Map<String, dynamic>> docs =
            snapshot.data ?? const <Map<String, dynamic>>[];
        final TabController? chipController = _aiTagTabController;
        if (chipController == null || _aiTagChips.isEmpty) {
          return _buildRefreshableScroll(
            context,
            scheme: scheme,
            tokens: tokens,
            slivers: [
              SliverOverlapInjector(
                handle:
                    NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              ),
              ..._buildNoticeSlivers(context, docs, _aiTagChipSelection),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _NestedScrollOverlapSpacer(),
            _buildAiTagChipBar(context),
            Expanded(
              child: TabBarView(
                controller: chipController,
                children: [
                  for (final String chip in _aiTagChips)
                    _buildRefreshableScroll(
                      context,
                      scheme: scheme,
                      tokens: tokens,
                      includeNestedHeaderOffset: false,
                      slivers: _buildNoticeSlivers(context, docs, chip),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildNoticeSlivers(
    BuildContext context,
    List<Map<String, dynamic>> docs,
    String chipSelection,
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

    final List<Map<String, dynamic>> aiFiltered =
        _applyAiTagChipFilter(filteredDocs, chipSelection);

    if (filteredDocs.isEmpty) {
      return [
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

    if (aiFiltered.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 48),
              Text(
                "선택한 필터에 맞는 공지가 없습니다.",
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
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
      final bool pinned =
          (_pinnedKeysByBoard[boardId] ?? const <String>{}).contains(key);
      (pinned ? pinnedFirst : rest).add(d);
    }
    final List<Map<String, dynamic>> finalOrdered = [...pinnedFirst, ...rest];

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
              final data = finalOrdered[index];
              final String boardId = _boardIdOf(data);
              final String id = (data["id"] ?? "").toString();
              final bool isRead =
                  (_readIdsByBoard[boardId] ?? const <String>{}).contains(id);
              final String key = _noticeKey(boardId, data);
              final bool isPinned =
                  (_pinnedKeysByBoard[boardId] ?? const <String>{})
                      .contains(key);
              final bool isFavorite =
                  (_favoriteKeysByBoard[boardId] ?? const <String>{})
                      .contains(key);

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
                  boardLabel:
                      (data["_boardLabel"] ?? _fallbackTypeForBoard(boardId))
                          .toString(),
                  showAiTagChips: true,
                  selectedTag: chipSelection,
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
    required String selectedTag,
    required bool isPinned,
    required bool isFavorite,
    required VoidCallback onTogglePinned,
    required VoidCallback onToggleFavorite,
  }) {
    final String title = (data["title"] ?? "").toString();
    final String dateStr = (data["date"] ?? data["reg_date"] ?? "").toString();
    final List<String> aiTags =
        showAiTagChips ? _parseAiTagsForList(data) : const <String>[];

    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;

    return MjcNoticeListItem(
      title: title,
      dateLabel: dateStr,
      primaryLabel: boardLabel,
      secondaryLabels: aiTags,
      selectedTag: selectedTag,
      brandColor: tokens.sourceMjc,
      isRead: isRead,
      isPinned: isPinned,
      isFavorite: isFavorite,
      onTap: onTap,
      onTogglePinned: onTogglePinned,
      onToggleFavorite: onToggleFavorite,
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
    final List<String> includes =
        await loadScopedNoticeFilterIncludes("mjc_main");
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
    final bool adding = !_pinnedKeys.contains(key);
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
    await prefs.setStringList(
        "favorite_notices_${widget.boardId}", next.toList());
    await UserDataRepository.instance.updateBookmarks(
      widget.boardId,
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
    final bool forceRefresh = NoticeListRefreshGuard.allowForceRefresh(
      "main_website_tab_${widget.boardId}",
    );
    setState(() {
      _noticeFuture = NoticeManager().getNotices(
        boardId: widget.boardId,
        forceRefresh: forceRefresh,
      );
    });
    await _noticeFuture;
    if (!forceRefresh && mounted) {
      NoticeListRefreshGuard.showThrottledMessage(
        context,
        key: "main_website_tab_${widget.boardId}_refresh_throttled",
      );
    }
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



  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    return NestedScrollRefreshIndicator(
      onRefresh: _handleRefresh,
      color: tokens.sourceMjc,
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



    if (filteredDocs.isEmpty) {
      return [
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

    final List<Map<String, dynamic>> ordered = [
      ...filteredDocs.where((d) => _pinnedKeys.contains(_noticeKey(d))),
      ...filteredDocs.where((d) => !_pinnedKeys.contains(_noticeKey(d))),
    ];

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
    required bool isPinned,
    required bool isFavorite,
    required VoidCallback onTogglePinned,
    required VoidCallback onToggleFavorite,
  }) {
    final String title = (data["title"] ?? "").toString();
    final String dateStr =
        (data["date"] ?? data["reg_date"] ?? "").toString();
    final String category = (data["category"] ?? "").toString().trim();
    final String primaryLabel =
        category.isNotEmpty ? category : _fallbackType();

    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;

    return MjcNoticeListItem(
      title: title,
      dateLabel: dateStr,
      primaryLabel: primaryLabel,
      brandColor: tokens.sourceMjc,
      isRead: isRead,
      isPinned: isPinned,
      isFavorite: isFavorite,
      onTap: onTap,
      onTogglePinned: onTogglePinned,
      onToggleFavorite: onToggleFavorite,
    );
  }
}

class _ScaleFeedbackButton extends StatefulWidget {
  final Widget child;

  /// Kept for API compatibility but no longer used — tap is handled by the
  /// child widget's own [InkWell].
  final VoidCallback onTap;
  const _ScaleFeedbackButton({required this.child, required this.onTap});
  @override
  State<_ScaleFeedbackButton> createState() => _ScaleFeedbackButtonState();
}

class _ScaleFeedbackButtonState extends State<_ScaleFeedbackButton> {
  bool _pressed = false;
  Offset? _downPosition;

  // Same touch-slop the framework uses for distinguishing tap from scroll.
  static const double _cancelSlop = 18.0;

  @override
  Widget build(BuildContext context) {
    // ── Why Listener instead of GestureDetector ──
    // GestureDetector creates a TapGestureRecognizer that enters the gesture
    // arena. Inside a NestedScrollView whose inner list items already contain
    // InkWell (which also registers a TapGestureRecognizer), having a *second*
    // recognizer on the wrapping widget creates a three-way arena competition
    // (two taps + one scroll). At the NestedScrollView inner↔outer transition
    // the scroll coordinator can momentarily stall, letting a tap recognizer
    // win and freezing the scroll entirely.
    //
    // Listener receives raw pointer events *without* entering the arena, so it
    // never interferes with scrolling. We use pointer-move distance to cancel
    // the pressed visual when the user is clearly scrolling.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (PointerDownEvent e) {
        _downPosition = e.position;
        if (mounted) setState(() => _pressed = true);
      },
      onPointerMove: (PointerMoveEvent e) {
        if (_pressed && _downPosition != null) {
          if ((e.position - _downPosition!).distance > _cancelSlop) {
            if (mounted) setState(() => _pressed = false);
            _downPosition = null;
          }
        }
      },
      onPointerUp: (PointerUpEvent _) {
        _downPosition = null;
        if (_pressed && mounted) setState(() => _pressed = false);
      },
      onPointerCancel: (PointerCancelEvent _) {
        _downPosition = null;
        if (_pressed && mounted) setState(() => _pressed = false);
      },
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}
