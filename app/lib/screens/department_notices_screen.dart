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
import "package:mjc_in_one/theme/app_colors.dart";
import "package:mjc_in_one/theme/app_theme.dart";
import "package:mjc_in_one/utils/community_notice_bookmarks.dart";
import "package:mjc_in_one/utils/notice_bookmark_key.dart";
import "package:mjc_in_one/widgets/collapsed_hero_title.dart";
import "package:mjc_in_one/widgets/community_notice_list_tile.dart";
import "package:mjc_in_one/widgets/scroll_to_top_scope.dart";
import "package:shared_preferences/shared_preferences.dart";

/// 학과 공지 목록 (실험실).
class DepartmentNoticesScreen extends StatefulWidget {
  const DepartmentNoticesScreen({super.key, this.activeInNoticesTab = true});

  final bool activeInNoticesTab;

  @override
  State<DepartmentNoticesScreen> createState() => _DepartmentNoticesScreenState();
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
      _slugError =
          slug == null ? "이 학과는 아직 학과 공지 게시판이 준비되지 않았습니다." : null;
    });
    if (slug != null && LabPrefs.selectedDepartment.value != name) {
      await LabPrefs.setSelectedDepartment(name);
    }
    await _loadNoticePrefs();
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

  Widget _buildDisclaimerBanner() {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final MjcSurfaceTokens tokens = theme.extension<MjcSurfaceTokens>()!;
    final bool isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border(
          left: BorderSide(color: tokens.sourceMjc, width: 4),
        ),
      ),
      child: Text(
        "학과 공지는 학과 단톡·학과 안내 등을 운영진이 정리해 올린 참고용입니다. "
        "학교 공식 홈페이지 공지와 다를 수 있으니 중요한 일정은 「본교」 탭을 확인하세요.",
        style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
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
                ),
              ),
            ),
          ];
        },
        body: NotificationListener<ScrollNotification>(
          onNotification: _nestedFabReporter.handleInnerScrollNotification,
          child: Builder(
            builder: (BuildContext nestedContext) {
              return CustomScrollView(
            primary: true,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverOverlapInjector(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                  nestedContext,
                ),
              ),
              SliverToBoxAdapter(child: _buildDisclaimerBanner()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: DropdownButtonFormField<String>(
                    key: ValueKey<String>(
                      "${_departments.length}_${_selectedDepartment ?? "none"}",
                    ),
                    initialValue: _dropdownValue,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: "학과",
                      prefixIcon: const Icon(Icons.school_outlined),
                      helperText: _loadingDepartments
                          ? "학과 목록을 불러오는 중입니다."
                          : (_selectedDepartment == null
                              ? "마이페이지에서 학과를 선택하거나 아래에서 고르세요."
                              : null),
                    ),
                    items: [
                      for (final String department in _departments)
                        DropdownMenuItem<String>(
                          value: department,
                          child: Text(department),
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                  ),
                ),
            ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPostsSliver() {
    final String slug = _deptSlug!;
    final String boardId = departmentNoticeBoardId(slug);
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: _communityService.streamPublishedPosts(slug),
      builder: (context, snap) {
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
        if (docs.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "아직 등록된 학과 공지가 없습니다.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> pinnedDocs =
            <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> restDocs =
            <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
          final Map<String, dynamic> data = {...doc.data(), "id": doc.id};
          final String key = departmentNoticeBookmarkKey(boardId, data);
          if (_pinnedKeys.contains(key)) {
            pinnedDocs.add(doc);
          } else {
            restDocs.add(doc);
          }
        }
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> orderedDocs =
            <QueryDocumentSnapshot<Map<String, dynamic>>>[
          ...pinnedDocs,
          ...restDocs,
        ];

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final QueryDocumentSnapshot<Map<String, dynamic>> doc =
                    orderedDocs[index];
                final Map<String, dynamic> data = {...doc.data(), "id": doc.id};
                final String postId = doc.id;
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
  });

  final double topPadding;
  final double heroBody;
  final bool overlapsContent;

  static const double _collapsedBar = 52;

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
    final double u = Curves.easeInOut.transform(t);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double bannerImageOpacity = (1.0 - u).clamp(0.0, 1.0);
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    final Color expandedHeroColor =
        isDark ? const Color(0xFF073A8C) : AppColors.primary;
    final Color collapsedHeroColor = tokens.dashboardGradients[0][0];
    final Color heroColor =
        Color.lerp(expandedHeroColor, collapsedHeroColor, u)!;

    return SizedBox(
      height: extent,
      width: double.infinity,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: heroColor),
            Positioned.fill(
              child: Builder(
                builder: (BuildContext context) {
                  final double dpr = MediaQuery.devicePixelRatioOf(context);
                  final Size size = MediaQuery.sizeOf(context);
                  final int cw = (size.width * dpr).round().clamp(1, 4096);
                  final int ch = ((topPadding + heroBody) * dpr)
                      .round()
                      .clamp(1, 4096);
                  return Opacity(
                    opacity: bannerImageOpacity,
                    child: Image.asset(
                      "assets/images/dep.png",
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
                        left: titleLeft,
                        top: collapsedTitleTop,
                        right: 24,
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
        overlapsContent != old.overlapsContent;
  }
}
