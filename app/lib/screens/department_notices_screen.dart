import "dart:math" show max;
import "dart:ui" show lerpDouble;

import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:mjc_in_one/lab_prefs.dart";
import "package:mjc_in_one/mpu_profile_prefs.dart";
import "package:mjc_in_one/screens/department_notice_detail_screen.dart";
import "package:mjc_in_one/models/community_notice_media.dart";
import "package:mjc_in_one/services/community_notice_service.dart";
import "package:mjc_in_one/services/department_slug_registry.dart";
import "package:mjc_in_one/services/departments_list_service.dart";
import "package:mjc_in_one/theme/app_theme.dart";
import "package:mjc_in_one/utils/community_notice_bookmarks.dart";
import "package:mjc_in_one/utils/notice_bookmark_key.dart";
import "package:mjc_in_one/utils/notice_list_refresh_guard.dart";
import "package:mjc_in_one/widgets/collapsed_hero_title.dart";
import "package:mjc_in_one/widgets/community_notice_list_tile.dart";
import "package:mjc_in_one/widgets/global_notice_search_sheet.dart";
import "package:mjc_in_one/widgets/main_navigation_scope.dart";
import "package:mjc_in_one/widgets/nested_scroll_refresh_indicator.dart";
import "package:mjc_in_one/widgets/notice_filter_sheet.dart";
import "package:mjc_in_one/services/notice_filter.dart";
import "package:mjc_in_one/widgets/scroll_to_top_scope.dart";
import "package:shared_preferences/shared_preferences.dart";

/// 학과 공지 UI 브랜드 색 (헤더 그라데이션·목록 액센트).
const Color _kDeptNoticeBrandLight = Color(0xFF536189);
const Color _kDeptNoticeBrandDark = Color(0xFF536189);

Color _deptNoticeBrandColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? _kDeptNoticeBrandDark
      : _kDeptNoticeBrandLight;
}

Color _deptNoticeOverlayBottom(Color brand) {
  return const Color(0xFF55658D);
}

/// 학과 공지 목록 (실험실).
class DepartmentNoticesScreen extends StatefulWidget {
  const DepartmentNoticesScreen({super.key, this.activeInNoticesTab = true});

  final bool activeInNoticesTab;

  @override
  State<DepartmentNoticesScreen> createState() =>
      _DepartmentNoticesScreenState();
}

class _DepartmentNoticesScreenState extends State<DepartmentNoticesScreen> {
  final ScrollController _outerScrollController = ScrollController();
  final DepartmentsListService _departmentsService = DepartmentsListService();
  final DepartmentSlugRegistry _slugRegistry = DepartmentSlugRegistry();
  final CommunityNoticeService _communityService = CommunityNoticeService();

  List<String> _departments = const [];
  bool _loadingDepartments = true;
  String? _selectedDepartment;
  String? _deptSlug;
  String? _slugError;
  Set<String> _readIds = <String>{};
  Set<String> _pinnedKeys = <String>{};
  Set<String> _favoriteKeys = <String>{};

  ScrollToTopCoordinator? _scrollToTopCoordinator;
  bool _registeredMainTab = false;
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? _postsFuture;

  late final NestedScrollFabScrollReporter _nestedFabReporter =
      NestedScrollFabScrollReporter(
    tabIndex: MainNavTabIndex.notices,
    outerController: _outerScrollController,
  );

  @override
  void initState() {
    super.initState();
    _outerScrollController.addListener(_nestedFabReporter.reportOuterScroll);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await LabPrefs.ensureLoaded();
    final List<String> departments =
        await _departmentsService.loadSortedDepartments();
    if (!mounted) return;

    String? selected = LabPrefs.selectedDepartment.value.trim();
    if (selected.isEmpty) {
      final MpuProfile profile = await loadMpuProfile();
      selected = profile.department.trim();
    }
    if (selected.isEmpty || !departments.contains(selected)) {
      selected = null;
    }

    setState(() {
      _departments = departments;
      _selectedDepartment = selected;
      _loadingDepartments = false;
    });
    await _resolveSlugForSelection();
  }

  Future<void> _resolveSlugForSelection() async {
    final String name = _selectedDepartment?.trim() ?? "";
    if (name.isEmpty) {
      setState(() {
        _deptSlug = null;
        _slugError = null;
      });
      await _loadNoticePrefs();
      return;
    }
    final String? slug = await _slugRegistry.slugForDisplayName(name);
    if (!mounted) return;
    setState(() {
      _deptSlug = slug;
      _slugError = slug == null ? "이 학과는 아직 학과 공지 게시판이 준비되지 않았습니다." : null;
      if (slug != null) {
        _postsFuture = _communityService.fetchPublishedPosts(slug);
      } else {
        _postsFuture = null;
      }
    });
    if (slug != null && LabPrefs.selectedDepartment.value != name) {
      await LabPrefs.setSelectedDepartment(name);
    }
    await _loadNoticePrefs();
    await _loadNoticeFilter();
  }

  bool _openingGlobalSearch = false;
  NoticeFilterState _noticeFilter = const NoticeFilterState();
  List<String> _noticeSharedKeywords = [];

  Future<void> _loadNoticeFilter() async {
    final NoticeFilterState filter = await NoticeFilterState.load();
    final List<String> keywords = await loadSharedNoticeKeywords();
    final String scopeId = "department_notice_${_deptSlug ?? ''}";
    final bool enabled = await loadScopedNoticeFilterEnabled(scopeId);
    final List<String> includes = await loadScopedNoticeFilterIncludes(scopeId);
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

  void _reloadNoticeFilter() {
    _loadNoticeFilter();
  }

  Future<void> _openNoticeFilterSheet() async {
    if (_deptSlug == null) return;
    final String scopeId = "department_notice_$_deptSlug";
    await showNoticeFilterSheet(
      context,
      scopeId: scopeId,
      scopeLabel: "${_selectedDepartment ?? '학과'} 공지",
      onFilterChanged: _reloadNoticeFilter,
    );
    _reloadNoticeFilter();
  }

  Future<void> _openGlobalSearch() async {
    if (_openingGlobalSearch || _deptSlug == null) return;
    _openingGlobalSearch = true;
    try {
      final docs = await _communityService.fetchPublishedPosts(_deptSlug!, limit: 200);
      if (!mounted) return;

      final List<Map<String, dynamic>> items = docs.map((doc) {
        return {
          ...doc.data(),
          "id": doc.id,
          "_boardId": departmentNoticeBoardId(_deptSlug!),
        };
      }).toList();

      await showGlobalNoticeSearchSheet(
        context,
        items: items,
        accentColor: _deptNoticeBrandColor(context),
        scopeLabel: "${_selectedDepartment ?? '학과'} 공지",
        openItem: (item) async { _openDetail(item); },
        boardIdFor: (item) => departmentNoticeBoardId(_deptSlug!),
        noticeKeyFor: (item) => departmentNoticeBookmarkKey(departmentNoticeBoardId(_deptSlug!), item),
        chipFor: (item) => (item["category"] ?? "공지").toString(),
        dateFor: (item) => (item["date"] ?? item["reg_date"] ?? "").toString().trim(),
        searchTextFor: (item) {
          final String title = (item["title"] ?? "").toString();
          final String cat = (item["category"] ?? "").toString();
          final String date = (item["date"] ?? item["reg_date"] ?? "").toString();
          return "$title $cat $date";
        },
      );
    } finally {
      _openingGlobalSearch = false;
    }
  }

  String? get _boardId {
    final String? slug = _deptSlug;
    if (slug == null || slug.isEmpty) return null;
    return departmentNoticeBoardId(slug);
  }

  Future<void> _loadNoticePrefs() async {
    final String? boardId = _boardId;
    if (boardId == null) {
      if (!mounted) return;
      setState(() {
        _readIds = <String>{};
        _pinnedKeys = <String>{};
        _favoriteKeys = <String>{};
      });
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _readIds = (prefs.getStringList("read_notices_$boardId") ?? []).toSet();
      _pinnedKeys =
          (prefs.getStringList("pinned_notices_$boardId") ?? []).toSet();
      _favoriteKeys =
          (prefs.getStringList("favorite_notices_$boardId") ?? []).toSet();
    });
  }

  Future<void> _markAsRead(String postId) async {
    final String? boardId = _boardId;
    if (boardId == null || postId.isEmpty || _readIds.contains(postId)) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final Set<String> next = {..._readIds, postId};
    if (mounted) setState(() => _readIds = next);
    await prefs.setStringList("read_notices_$boardId", next.toList());
  }

  Future<void> _togglePinned(String key) async {
    final String? boardId = _boardId;
    if (boardId == null) return;
    final Set<String> next =
        await toggleCommunityNoticePinned(context, boardId, key);
    if (mounted) setState(() => _pinnedKeys = next);
  }

  Future<void> _toggleFavorite(String key) async {
    final String? boardId = _boardId;
    if (boardId == null) return;
    final Set<String> next =
        await toggleCommunityNoticeFavorite(context, boardId, key);
    if (mounted) setState(() => _favoriteKeys = next);
  }

  bool _allowRefreshNotification(ScrollNotification n) {
    return defaultScrollNotificationPredicate(n);
  }

  Future<void> _handleRefresh() async {
    final String? slug = _deptSlug;
    if (slug == null) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return;
    }
    
    final bool forceRefresh =
        NoticeListRefreshGuard.allowForceRefresh("department_notice_$slug");
        
    if (forceRefresh) {
      setState(() {
        _postsFuture = _communityService.fetchPublishedPosts(slug);
      });
      final start = DateTime.now();
      await _postsFuture;
      final diff = DateTime.now().difference(start);
      if (diff.inMilliseconds < 600) {
        await Future<void>.delayed(Duration(milliseconds: 600 - diff.inMilliseconds));
      }
    } else {
      if (mounted) {
        NoticeListRefreshGuard.showThrottledMessage(
          context,
          key: "department_notice_refresh_throttled",
        );
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ScrollToTopCoordinator? c = ScrollToTopScope.maybeOf(context);
    if (c != null) {
      _scrollToTopCoordinator = c;
      _nestedFabReporter.attachCoordinator(c);
      _syncScrollToTopRegistration();
    }
    if (_outerScrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _nestedFabReporter.reportOuterScroll();
      });
    }
  }

  @override
  void didUpdateWidget(covariant DepartmentNoticesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeInNoticesTab != widget.activeInNoticesTab) {
      _syncScrollToTopRegistration();
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

  @override
  void dispose() {
    _outerScrollController.removeListener(_nestedFabReporter.reportOuterScroll);
    if (_registeredMainTab) {
      _scrollToTopCoordinator?.unregisterMainTab(
        MainNavTabIndex.notices,
        owner: this,
      );
    }
    _outerScrollController.dispose();
    super.dispose();
  }

  String? get _dropdownValue {
    final String? selected = _selectedDepartment;
    if (selected == null || selected.isEmpty) return null;
    if (!_departments.contains(selected)) return null;
    return selected;
  }

  void _openDetail(Map<String, dynamic> data) {
    final String? boardId = _boardId;
    if (boardId == null) return;
    final String postId = (data["id"] as String?) ?? "";
    final String key = departmentNoticeBookmarkKey(boardId, data);
    final bool isPinned = _pinnedKeys.contains(key);
    final bool isFavorite = _favoriteKeys.contains(key);
    final List<CommunityNoticeMediaItem> images =
        CommunityNoticePostMedia.imagesFromPost(data);
    final List<CommunityNoticeMediaItem> attachments =
        CommunityNoticePostMedia.attachmentsFromPost(data);

    Future<void> open() async {
      await _markAsRead(postId);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => DepartmentNoticeDetailScreen(
            title: (data["title"] as String?) ?? "",
            author: (data["author"] as String?) ?? "",
            date: (data["date"] as String?) ?? "",
            body: (data["body"] as String?) ?? "",
            images: images,
            attachments: attachments,
            sourceNote: data["source_note"] as String?,
            isPinned: isPinned,
            isFavorite: isFavorite,
            onTogglePinned: () => _togglePinned(key),
            onToggleFavorite: () => _toggleFavorite(key),
          ),
        ),
      );
    }

    open();
  }

  BoxDecoration _guideCardDecoration(ColorScheme scheme, {required bool isDark}) {
    return BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.05),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  Widget _buildGuideSectionTitle(
    ThemeData theme,
    ColorScheme scheme, {
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimerBanner() {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    const List<String> bullets = <String>[
      "학과 공지는 학과 단톡·학과 안내 등을 운영진이 정리해 올린 참고용입니다.",
      "학교 공식 홈페이지 공지와 다를 수 있으니 중요한 일정은 「본교」 탭을 확인하세요.",
    ];
    final TextStyle bulletStyle = theme.textTheme.bodySmall!.copyWith(
      color: scheme.onSurfaceVariant,
      height: 1.45,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: _guideCardDecoration(scheme, isDark: isDark).copyWith(
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGuideSectionTitle(
            theme,
            scheme,
            icon: Icons.info_outline_rounded,
            title: "학과 공지 안내",
          ),
          const SizedBox(height: 10),
          ...bullets.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      "•",
                      style: bulletStyle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(text, style: bulletStyle)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double topPad = MediaQuery.paddingOf(context).top;
    final double viewportW = MediaQuery.sizeOf(context).width;
    final double bannerHeight16x9 = viewportW * 9 / 16;
    final double heroBody = max(120.0, bannerHeight16x9 - topPad);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        controller: _outerScrollController,
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverPersistentHeader(
                pinned: true,
                delegate: _DepartmentCollapsingHeaderDelegate(
                  topPadding: topPad,
                  heroBody: heroBody,
                  overlapsContent: innerBoxIsScrolled,
                  onOpenFilter: _openNoticeFilterSheet,
                  onSearch: _openGlobalSearch,
                ),
              ),
            ),
          ];
        },
        body: NotificationListener<ScrollNotification>(
          onNotification: _nestedFabReporter.handleInnerScrollNotification,
          child: Builder(
            builder: (BuildContext nestedContext) {
              return NestedScrollRefreshIndicator(
                onRefresh: _handleRefresh,
                color: _deptNoticeBrandColor(context),
                backgroundColor: Theme.of(context).colorScheme.surface,
                notificationPredicate: _allowRefreshNotification,
                tabBarHeight: 0,
                child: CustomScrollView(
                  primary: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                  SliverOverlapInjector(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                      nestedContext,
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildDisclaimerBanner()),
                  SliverToBoxAdapter(child: _buildDepartmentDropdown()),
                  if (_slugError != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _slugError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  if (_deptSlug != null && _slugError == null)
                    _buildPostsSliver()
                  else if (!_loadingDepartments && _selectedDepartment != null)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text("게시판을 불러올 수 없습니다.")),
                    )
                  else if (!_loadingDepartments)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            "학과를 선택하면 공지 목록이 표시됩니다.",
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentDropdown() {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _guideCardDecoration(scheme, isDark: isDark),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGuideSectionTitle(
              theme,
              scheme,
              icon: Icons.school_outlined,
              title: "학과",
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _dropdownValue,
                  hint: Text(
                    "학과 선택",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  isExpanded: true,
                  icon: Icon(
                    Icons.expand_more_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  items: [
                    for (final String department in _departments)
                      DropdownMenuItem<String>(
                        value: department,
                        child: Row(
                          children: [
                            const Icon(Icons.school_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(department)),
                          ],
                        ),
                      ),
                  ],
                  selectedItemBuilder: (context) => [
                    for (final String department in _departments)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Icon(
                              Icons.school_outlined,
                              size: 18,
                              color: scheme.onSurface,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                department,
                                style: theme.textTheme.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  onChanged: _loadingDepartments
                      ? null
                      : (String? value) async {
                          setState(() => _selectedDepartment = value);
                          await LabPrefs.setSelectedDepartment(value ?? "");
                          await _resolveSlugForSelection();
                        },
                ),
              ),
            ),
            if (_loadingDepartments || _selectedDepartment == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _loadingDepartments
                      ? "학과 목록을 불러오는 중입니다."
                      : "마이페이지에서 학과를 선택하거나 아래에서 고르세요.",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsSliver() {
    final String slug = _deptSlug!;
    final String boardId = departmentNoticeBoardId(slug);
    return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      future: _postsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "공지를 불러오지 못했습니다.\n${snap.error}",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snap.data!;
        final List<Map<String, dynamic>> rawDocs =
            docs.map((d) => {...d.data(), "id": d.id}).toList();

        final NoticeFilterState filter = _noticeFilter.copyWith(quickQuery: "");
        final List<Map<String, dynamic>> filteredDocs = filter.apply(
          rawDocs,
          sharedKeywords: _noticeSharedKeywords,
          fallbackSource: "MJC",
          fallbackType: "공지",
        );

        if (filteredDocs.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  docs.isEmpty ? "아직 등록된 학과 공지가 없습니다." : "필터에 맞는 공지가 없습니다.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          );
        }

        final List<Map<String, dynamic>> pinnedDocs = [];
        final List<Map<String, dynamic>> restDocs = [];
        for (final Map<String, dynamic> data in filteredDocs) {
          final String key = departmentNoticeBookmarkKey(boardId, data);
          if (_pinnedKeys.contains(key)) {
            pinnedDocs.add(data);
          } else {
            restDocs.add(data);
          }
        }
        final List<Map<String, dynamic>> orderedDocs = [...pinnedDocs, ...restDocs];

        return SliverPadding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            24 + MainNavLayout.scrollBottomExtra(context),
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final Map<String, dynamic> data = orderedDocs[index];
                final String postId = (data["id"] as String?) ?? "";
                final String key = departmentNoticeBookmarkKey(boardId, data);
                final List<CommunityNoticeMediaItem> images =
                    CommunityNoticePostMedia.imagesFromPost(data);
                final CommunityNoticeMediaItem? thumb =
                    images.isNotEmpty ? images.first : null;
                return CommunityNoticeListTile(
                  title: (data["title"] as String?) ?? "",
                  author: (data["author"] as String?) ?? "",
                  date: (data["date"] as String?) ?? "",
                  imageUrl: thumb?.url,
                  imageStoragePath: thumb?.storagePath,
                  brandColor: _deptNoticeBrandColor(context),
                  isRead: _readIds.contains(postId),
                  isPinned: _pinnedKeys.contains(key),
                  isFavorite: _favoriteKeys.contains(key),
                  onTogglePinned: () => _togglePinned(key),
                  onToggleFavorite: () => _toggleFavorite(key),
                  onTap: () => _openDetail(data),
                );
              },
              childCount: orderedDocs.length,
            ),
          ),
        );
      },
    );
  }
}

/// [MainWebsiteScreen] 히어로와 동일한 접힘 헤더 (학과 공지 전용 배너).
class _DepartmentCollapsingHeaderDelegate
    extends SliverPersistentHeaderDelegate {
  _DepartmentCollapsingHeaderDelegate({
    required this.topPadding,
    required this.heroBody,
    required this.overlapsContent,
    required this.onOpenFilter,
    required this.onSearch,
  });

  final double topPadding;
  final double heroBody;
  final bool overlapsContent;
  final VoidCallback onOpenFilter;
  final VoidCallback onSearch;

  static const double _collapsedBar = 52;

  /// Collapsed 시 배너 패턴이 비치지 않게 완전히 덮음
  static const double _collapsedOverlayOpacity = 1.0;

  @override
  double get maxExtent => topPadding + heroBody;

  @override
  double get minExtent => topPadding + _collapsedBar;

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
    final double overlayT = Curves.easeIn.transform(t);
    final double u = Curves.easeInOut.transform(t);
    final double overlayOpacity =
        lerpDouble(0.0, _collapsedOverlayOpacity, overlayT)!;
    final Alignment imageAlignment = Alignment.lerp(
      Alignment.center,
      const Alignment(0, -0.35),
      overlayT,
    )!;
    final double bannerScale = lerpDouble(1.04, 1.02, overlayT)!;
    // 완전히 접혔을 때 전체 배경이 불투명해지도록 상단/하단 동일한 opacity 사용
    final double bottomOverlayOpacity = overlayOpacity;
    final Color overlayTop = _deptNoticeBrandColor(context);
    final Color overlayBottom = _deptNoticeOverlayBottom(overlayTop);

    return SizedBox(
      height: extent,
      width: double.infinity,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: overlayTop),
            Positioned.fill(
              child: Builder(
                builder: (BuildContext context) {
                  final double dpr = MediaQuery.devicePixelRatioOf(context);
                  final Size size = MediaQuery.sizeOf(context);
                  final int cw = (size.width * dpr).round().clamp(1, 4096);
                  final int ch =
                      ((topPadding + heroBody) * dpr).round().clamp(1, 4096);
                  return Transform.scale(
                    scale: bannerScale,
                    alignment: imageAlignment,
                    child: Image.asset(
                      "assets/images/dep.png",
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
                      overlayTop.withValues(alpha: overlayOpacity),
                      overlayBottom.withValues(
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
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double ih = constraints.maxHeight;
                  final double titleSize = lerpDouble(34, 20, u)!;
                  const double titleLeft = 24;
                  final double collapsedTitleTop = (ih - titleSize * 1.15) / 2;
                  final double titleReveal =
                      ((t - 0.92) / 0.08).clamp(0.0, 1.0);
                  final double titleOpacity =
                      Curves.easeOutCubic.transform(titleReveal);
                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned(
                        left: 12,
                        top: ih >= 54 ? 6.0 : max(0.0, (ih - 48) / 2),
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
                        right: 88,
                        child: IgnorePointer(
                          ignoring: titleOpacity < 0.02,
                          child: Opacity(
                            opacity: titleOpacity,
                            child: CollapsedHeroTitle(
                              icon: Icons.groups_outlined,
                              text: "학과 공지사항",
                              baseStyle: Theme.of(context)
                                  .extension<MjcTextTokens>()!
                                  .appBarTitle,
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
    );
  }

  @override
  bool shouldRebuild(covariant _DepartmentCollapsingHeaderDelegate old) {
    return topPadding != old.topPadding ||
        heroBody != old.heroBody ||
        overlapsContent != old.overlapsContent ||
        onOpenFilter != old.onOpenFilter ||
        onSearch != old.onSearch;
  }
}
