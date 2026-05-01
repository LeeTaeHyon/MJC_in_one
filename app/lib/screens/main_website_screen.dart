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
    return DefaultTabController(
      length: 3,
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
                  delegate: _MainWebsiteCollapsingHeaderDelegate(
                    topPadding: topPad,
                    tabBar: TabBar(
                      controller: DefaultTabController.of(context),
                      indicatorColor: scheme.primary,
                      indicatorWeight: 3,
                      labelColor: scheme.primary,
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
                  _NoticeListTab(boardId: "main_notice", entryTick: _entryTick),
                  _NoticeListTab(
                      boardId: "main_academic", entryTick: _entryTick),
                  _NoticeListTab(
                      boardId: "main_scholarship", entryTick: _entryTick),
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
    final double extent =
        (maxExtent - shrinkOffset).clamp(minExtent, maxExtent);
    final double range = maxExtent - minExtent;
    final double t = range > 0 ? (shrinkOffset / range).clamp(0.0, 1.0) : 0.0;
    final double u = Curves.easeInOut.transform(t);
    final double heroH = extent - _tabBarHeight;
    // LayoutBuilder removed: c.maxHeight == heroH - topPadding (SafeArea subtracts status bar)
    final double ih = heroH - topPadding;
    final double titleSize = lerpDouble(28, 19, u)!;
    const double titleLeft = 20;
    const double bottomBlock = 20 + 14 + 6 + 28;
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
  bool shouldRebuild(covariant _MainWebsiteCollapsingHeaderDelegate old) {
    return topPadding != old.topPadding || tabBar != old.tabBar;
  }
}

class _NoticeListTab extends StatefulWidget {
  final String boardId;
  final int entryTick;
  const _NoticeListTab({required this.boardId, required this.entryTick});

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
  String _noticeQuickQuery = "";
  late Future<List<Map<String, dynamic>>> _noticeFuture;
  double _filterBarReveal = 0;
  bool _refreshEnabledForDrag = false;

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
    _loadReadHistory();
    _loadPinsAndFavorites();
    _loadNoticeFilter();
    _noticeFuture = NoticeManager().getNotices(boardId: widget.boardId);
  }

  @override
  void didUpdateWidget(covariant _NoticeListTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entryTick != oldWidget.entryTick) {
      _entrance.resetForEntry();
    }
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
          final Widget scrollable = NotificationListener<ScrollNotification>(
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
                  ..._buildNoticeSlivers(context, snapshot.data ?? []),
              ],
            ),
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
    final NoticeFilterState filter =
        _noticeFilter.copyWith(quickQuery: _noticeQuickQuery);
    final List<Map<String, dynamic>> filteredDocs = filter.apply(
      docs,
      sharedKeywords: _noticeSharedKeywords,
      fallbackSource: "MJC",
      fallbackType: _fallbackType(),
    );
    final Widget filterBar = NoticeFilterBar(
      filter: filter,
      keywordCount: _noticeSharedKeywords.length,
      totalCount: docs.length,
      filteredCount: filteredDocs.length,
      onQueryChanged: (String value) {
        setState(() => _noticeQuickQuery = value);
      },
      onOpenSettings: _openNoticeFilterSettings,
    );

    if (filteredDocs.isEmpty) {
      return [
        SliverToBoxAdapter(child: _revealedFilterBar(filterBar)),
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
              final String id = data["id"] ?? "";
              final bool isRead = _readNoticeIds.contains(id);
              final String url = data["url"] ?? "";
              final String key = _noticeKey(data);
              final bool isPinned = _pinnedKeys.contains(key);
              final bool isFavorite = _favoriteKeys.contains(key);

              final Widget tile = _ScaleFeedbackButton(
                onTap: () async {
                  await _markAsRead(id);
                  if (url.isEmpty) return;
                  if (kIsWeb) {
                    await launchUrl(Uri.parse(url),
                        webOnlyWindowName: "_blank");
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
                  isPinned: isPinned,
                  isFavorite: isFavorite,
                  onTogglePinned: () => _togglePinned(key),
                  onToggleFavorite: () => _toggleFavorite(key),
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String title = data["title"] ?? "";
    final String dateStr = data["date"] ?? "";
    final String type = data["category"] ?? "공지";
    final Color mainColor = isRead ? scheme.onSurfaceVariant : tokens.sourceMjc;
    final Color chipBackground = isRead
        ? tokens.surfaceContainer
        : tokens.sourceMjc.withValues(alpha: isDark ? 0.18 : 0.12);
    final Color chipForeground =
        isRead ? scheme.onSurfaceVariant : tokens.sourceMjc;
    final Color titleColor =
        isRead ? scheme.onSurfaceVariant : scheme.onSurface;
    final Color dateColor = scheme.onSurfaceVariant;
    const bool lowRaster = kPerfLowRasterMode;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isRead ? scheme.surfaceContainerLow : scheme.surface,
        borderRadius: BorderRadius.circular(12),
        elevation: (isRead || lowRaster) ? 0 : 2,
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
                              fontWeight:
                                  isRead ? FontWeight.normal : FontWeight.bold,
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
                                fontWeight: isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
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
