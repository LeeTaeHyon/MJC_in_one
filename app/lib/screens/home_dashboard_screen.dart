import "dart:async";
import "dart:math";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:mio_notice/features/timetable/models/timetable_models.dart";
import "package:mio_notice/features/timetable/screens/timetable_main_screen.dart";
import "package:mio_notice/features/timetable/services/timetable_storage_service.dart";
import "package:mio_notice/features/timetable/utils/timetable_next_lecture.dart";
import "package:mio_notice/home_dashboard_prefs.dart";
import "package:mio_notice/screens/academic_schedule_screen.dart";
import "package:mio_notice/screens/campus_map_screen.dart";
import "package:mio_notice/screens/common_webview_screen.dart";
import "package:mio_notice/screens/foodcourt_menu_screen.dart";
import "package:mio_notice/screens/library_screen.dart";
import "package:mio_notice/screens/more_tab_screen.dart";
import "package:mio_notice/screens/notices_tab_screen.dart";
import "package:mio_notice/services/foodcourt_menu.dart";
import "package:mio_notice/services/notice_filter.dart";
import "package:mio_notice/services/auth_service.dart";
import "package:mio_notice/services/notice_manager.dart";
import "package:mio_notice/services/mpu_service.dart";
import "package:mio_notice/theme/app_colors.dart";
import "package:mio_notice/theme/app_theme.dart";
import "package:mio_notice/utils/mpu_program_dday.dart";
import "package:mio_notice/widgets/scroll_to_top_scope.dart";
import "package:mio_notice/widgets/shuttle_status_card.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";

const double _kHomeHeaderBottomRadius = 30;
const double _kHomeBlueOverlapPull = 22;

/// 파란 헤더 위로 올라오는 바로가기 배경의 상단 라운드.
const double _kQuickShortcutsBackgroundTopRadius = 24;

/// 바로가기 카드 위 여백(파란 헤더와 첫 카드 사이, 회색 패널 안).
const double _kQuickShortcutsTopInset = 10;

/// 회색 바로가기 패널 바깥 좌우 여백. 0이면 패널이 스크롤 영역 가로로 꽉 참.
const double _kQuickShortcutsPanelHorizontalMargin = 12;

/// 회색 패널 안에서 카드 그리드만 줄일 때(셔틀 등 `padding: 20` 카드와 열 맞춤).
/// (패널 바깥 여백 + 이 값)이 화면 기준 다른 카드 좌우 inset과 같게 맞추면 됩니다.
const double _kQuickShortcutsGridHorizontalPadding = 8;

/// MJC ONE 행 위·아래 여백(동일).
const double _kPinnedBrandVerticalInset = 5;

/// 아이콘 행(햄버거) 기준 높이.
const double _kPinnedBrandIconRowHeight = 48;

/// [_buildDashboardPinnedBrandRow] 본문 세로 합. SafeArea 상단 inset은 별도.
const double _kPinnedBrandRowContentHeight = _kPinnedBrandVerticalInset +
    _kPinnedBrandIconRowHeight +
    _kPinnedBrandVerticalInset;

class HomeDashboardScreen extends StatefulWidget {
  final void Function(int, {NoticesSubTab? noticesSubTab}) onNavigate;

  const HomeDashboardScreen({
    super.key,
    required this.onNavigate,
  });

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  late Future<List<Map<String, dynamic>>> _combinedNoticeFuture;
  late Future<List<Map<String, dynamic>>> _academicScheduleFuture;
  late Future<List<FoodcourtMenuItem>> _foodcourtMenuFuture;
  Set<String> _readDashboardNoticeKeys = {};
  NoticeFilterState _noticeFilter = const NoticeFilterState();
  List<String> _noticeSharedKeywords = [];
  final String _noticeQuickQuery = "";
  final ScrollController _scrollController = ScrollController();
  final FoodcourtMenuService _foodcourtMenuService = FoodcourtMenuService();
  final MpuService _mpuService = MpuService();
  final Random _foodRandom = Random();
  ScrollToTopCoordinator? _scrollToTopCoordinator;
  Set<String> _enabledDashboardSections =
      defaultHomeDashboardEnabledSections().toSet();
  List<String> _dashboardSectionOrder = defaultHomeDashboardSectionOrder();

  static const String _prefsReadDashboard = "read_notices_combined_dashboard";
  static const String _mpuWebBaseUrl =
      "https://mpu.mjc.ac.kr/Main/default.aspx";

  @override
  void initState() {
    super.initState();
    _combinedNoticeFuture = _prepareDashboardNotices();
    _academicScheduleFuture =
        NoticeManager().getNotices(boardId: "main_schedule");
    _foodcourtMenuFuture = _foodcourtMenuService.loadFromAsset();
    _loadNoticeFilter();
    _loadEnabledDashboardSections();
    _loadDashboardSectionOrder();
    _scrollController.addListener(_onHomeScrollOffset);
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

  Future<void> _loadEnabledDashboardSections() async {
    final Set<String> enabled = await loadHomeDashboardEnabledSections();
    if (!mounted) return;
    setState(() => _enabledDashboardSections = enabled);
  }

  Future<void> _loadDashboardSectionOrder() async {
    final List<String> order = await loadHomeDashboardSectionOrder();
    if (!mounted) return;
    setState(() => _dashboardSectionOrder = order);
  }

  bool _sectionEnabled(HomeDashboardSection section) {
    return _enabledDashboardSections.contains(section.id);
  }

  List<HomeDashboardSection> _orderedEnabledSections() {
    final Map<String, HomeDashboardSection> byId = {
      for (final s in HomeDashboardSection.values) s.id: s,
    };
    final List<HomeDashboardSection> out = [];
    for (final id in _dashboardSectionOrder) {
      final HomeDashboardSection? s = byId[id];
      if (s == null) continue;
      if (_sectionEnabled(s)) out.add(s);
    }
    // 혹시 순서 목록이 깨져도 enabled는 잃지 않게 보정
    final Set<String> seen = out.map((s) => s.id).toSet();
    for (final s in HomeDashboardSection.values) {
      if (_sectionEnabled(s) && !seen.contains(s.id)) out.add(s);
    }
    return out;
  }

  Widget _buildSection(HomeDashboardSection section, BuildContext context) {
    switch (section) {
      case HomeDashboardSection.lectureReminder:
        return _buildLectureReminderSection(context);
      case HomeDashboardSection.quickButtons:
        return _buildGridButtons(context);
      case HomeDashboardSection.shuttle:
        return _buildShuttleSection(context);
      case HomeDashboardSection.foodcourt:
        return _buildFoodcourtSection(context);
      case HomeDashboardSection.mpuDeadline:
        return _buildDeadlineSection(context);
      case HomeDashboardSection.academicSchedule:
        return _buildAcademicScheduleSection(context);
      case HomeDashboardSection.recentNotices:
        return Column(
          children: [
            _buildNoticeHeader(context),
            _buildNoticeList(),
          ],
        );
    }
  }

  void _onHomeScrollOffset() {
    if (!mounted) return;
    final double viewportHeight =
        ScrollFabMetrics.viewportHeightInScrollListener(_scrollController);
    _scrollToTopCoordinator?.reportMainTabScroll(
      MainNavTabIndex.home,
      _scrollController.offset,
      viewportHeight,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ScrollToTopCoordinator? c = ScrollToTopScope.maybeOf(context);
    if (c != null) {
      _scrollToTopCoordinator = c;
      c.registerMainTab(
        MainNavTabIndex.home,
        _scrollContentToTop,
        owner: this,
      );
    }
    if (_scrollController.hasClients) {
      _scrollToTopCoordinator?.reportMainTabScroll(
        MainNavTabIndex.home,
        _scrollController.offset,
        ScrollFabMetrics.viewportHeightForThreshold(_scrollController, context),
      );
    }
  }

  void _scrollContentToTop() {
    if (!_scrollController.hasClients) return;
    for (final position in _scrollController.positions) {
      position.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onHomeScrollOffset);
    _scrollToTopCoordinator?.unregisterMainTab(
      MainNavTabIndex.home,
      owner: this,
    );
    _scrollController.dispose();
    super.dispose();
  }

  /// 통합 공지를 불러오기 전에 읽음 목록을 로드해, 첫 표시부터 숨길 항목을 반영합니다.
  Future<List<Map<String, dynamic>>> _prepareDashboardNotices() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = (prefs.getStringList(_prefsReadDashboard) ?? []).toSet();
    if (mounted) {
      setState(() => _readDashboardNoticeKeys = keys);
    }
    return NoticeManager().getNotices(boardId: "combined_dashboard");
  }

  String _dashboardNoticeKey(Map<String, dynamic> data) {
    final String id = (data["id"] ?? "").toString();
    final String source = (data["source"] ?? "").toString();
    final String type = (data["type"] ?? "").toString();
    if (id.isNotEmpty) return "$source|$type|$id";
    final String url = (data["url"] ?? data["link"] ?? "").toString().trim();
    final String title = (data["title"] ?? "").toString();
    return "$source|$type|$url|$title";
  }

  Future<void> _markDashboardNoticeRead(String key) async {
    if (_readDashboardNoticeKeys.contains(key)) return;
    final prefs = await SharedPreferences.getInstance();
    final Set<String> next = {..._readDashboardNoticeKeys, key};
    if (mounted) {
      setState(() => _readDashboardNoticeKeys = next);
    }
    await prefs.setStringList(_prefsReadDashboard, next.toList());
  }

  Future<void> _handleRefresh() async {
    await _loadNoticeFilter();
    setState(() {
      _combinedNoticeFuture = NoticeManager().getNotices(
        boardId: "combined_dashboard",
        forceRefresh: true,
      );
      _academicScheduleFuture = NoticeManager().getNotices(
        boardId: "main_schedule",
        forceRefresh: true,
      );
      _foodcourtMenuFuture = _foodcourtMenuService.loadFromAsset();
    });
    await Future.wait([
      _combinedNoticeFuture,
      _academicScheduleFuture,
      _foodcourtMenuFuture,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // Home tab must always be visually opaque during transitions, otherwise
    // AnimatedSwitcher fade can reveal the previous tab underneath.
    final double pinnedBrandExtent =
        MediaQuery.paddingOf(context).top + _kPinnedBrandRowContentHeight;
    final bool homeLight = Theme.of(context).brightness == Brightness.light;
    return ColoredBox(
      color: homeLight
          ? AppColors.scaffoldMuted
          : Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: pinnedBrandExtent),
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                color: AppColors.primary,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  clipBehavior: Clip.none,
                  slivers: <Widget>[
                    SliverToBoxAdapter(
                      child: _buildDashboardScrollableHomeBody(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: pinnedBrandExtent,
            child: Material(
              type: MaterialType.transparency,
              child: _buildDashboardPinnedBrandRow(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMore() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const MoreTabScreen(),
      ),
    );
    if (!mounted) return;
    _loadEnabledDashboardSections();
    _loadDashboardSectionOrder();
    _loadNoticeFilter();
  }

  /// 스크롤해도 고정되는 최상단 브랜드 행(MJC ONE + 더보기).
  Widget _buildDashboardPinnedBrandRow(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color blue = isDark ? const Color(0xFF073A8C) : AppColors.primary;
    return ColoredBox(
      color: blue,
      child: SafeArea(
        bottom: false,
        minimum: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            24,
            _kPinnedBrandVerticalInset,
            4,
            _kPinnedBrandVerticalInset,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: "MJC",
                        style: MjcAppTypography.homeHeroCollapsedTitleMjc(
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(
                        text: " ",
                        style: MjcAppTypography.homeHeroCollapsedTitleMid(
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(
                        text: "ONE",
                        style: MjcAppTypography.homeHeroCollapsedTitleOne(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: "더보기",
                onPressed: _openMore,
                icon: const Icon(
                  Icons.menu_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 인삿말·대시보드 섹션만 스크롤. 파란 배경은 [Stack] 뒤 레이어, 카드는 앞 레이어.
  Widget _buildDashboardScrollableHomeBody(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges(),
      initialData: AuthService.instance.currentUser,
      builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
        final User? user = snapshot.data;
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final Color blue = isDark ? const Color(0xFF073A8C) : AppColors.primary;
        final String name = _homeGreetingDisplayName(user);
        final List<HomeDashboardSection> sections = _orderedEnabledSections();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: blue,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(_kHomeHeaderBottomRadius),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 4, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: 12),
                      Text(
                        "$name님,\n오늘도 좋은 하루 되세요.",
                        style: MjcAppTypography.homeDashboardGreeting(
                          color: Colors.white.withValues(alpha: 0.94),
                        ),
                      ),
                      SizedBox(height: _kHomeBlueOverlapPull + 8),
                    ],
                  ),
                ),
              ],
            ),
            Transform.translate(
              offset: const Offset(0, -_kHomeBlueOverlapPull),
              child: Column(
                children: <Widget>[
                  if (sections.isNotEmpty &&
                      sections.first != HomeDashboardSection.lectureReminder &&
                      sections.first != HomeDashboardSection.quickButtons &&
                      sections.first != HomeDashboardSection.recentNotices)
                    const SizedBox(height: 16),
                  for (final HomeDashboardSection s in sections)
                    _buildSection(s, context),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _homeGreetingDisplayName(User? user) {
    if (user == null) return "사용자";
    final String display = (user.displayName ?? "").trim();
    if (display.isNotEmpty) return display;
    final String email = (user.email ?? "").trim();
    if (email.contains("@")) {
      return email.split("@").first.trim();
    }
    if (email.isNotEmpty) return email;
    return "사용자";
  }

  Widget _buildShuttleSection(BuildContext context) {
    final DateTime now = DateTime.now();
    final bool isWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    if (!isWeekend) return const ShuttleStatusCard();

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Opacity(
        opacity: 0.72,
        child: Material(
          color: scheme.surface,
          elevation: 1.5,
          shadowColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: tokens.surfaceContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.directions_bus_filled_outlined,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "셔틀버스",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "주말입니다",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "주말에는 셔틀버스 정보가 비활성화됩니다.",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLectureReminderSection(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    return FutureBuilder<List<ParsedCourseOffering>>(
      future: TimetableStorageService.loadEnrolled(),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<ParsedCourseOffering>> snapshot,
      ) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final List<ParsedCourseOffering> enrolled =
            snapshot.data ?? const <ParsedCourseOffering>[];
        final TimetableSlot? slot =
            TimetableNextLecture.nextUpcomingSlotToday(enrolled);
        if (slot == null) return const SizedBox.shrink();
        final DateTime now = DateTime.now();
        final int nowMin = now.hour * 60 + now.minute;
        final int untilMin = slot.startMinute - nowMin;
        final String label = TimetableNextLecture.formatCountdownKo(untilMin);
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Material(
            color: scheme.surface,
            elevation: 1,
            shadowColor: scheme.shadow.withValues(alpha: isDark ? 0.45 : 0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: (isDark ? tokens.cardBorder : scheme.outline)
                    .withValues(alpha: isDark ? 0.85 : 0.55),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const TimetableMainScreen(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.schedule_rounded, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "$label 뒤 ${slot.courseName} 수업이 있습니다.",
                        style: TextStyle(
                          fontFamily: kPretendardFontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                          height: 1.25,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridButtons(BuildContext context) {
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color homeMutedBg =
        isDark ? AppColors.scaffoldMutedDark : AppColors.scaffoldMuted;
    final Widget cardRows = Column(
      children: [
        Row(
          children: [
            _expandedButton(
              "본교 공지",
              "최신 소식",
              Icons.school,
              tokens.dashboardGradients[0],
              MainNavTabIndex.notices,
              noticesSubTab: NoticesSubTab.main,
            ),
            const SizedBox(width: 8),
            _expandedButton(
              "교수학습",
              "학습 지원",
              Icons.menu_book,
              tokens.dashboardGradients[1],
              MainNavTabIndex.notices,
              noticesSubTab: NoticesSubTab.ctl,
            ),
            const SizedBox(width: 8),
            _expandedButton(
              "역량관리",
              "프로그램",
              Icons.emoji_events,
              tokens.dashboardGradients[2],
              MainNavTabIndex.notices,
              noticesSubTab: NoticesSubTab.mpu,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _expandedButton(
              "도서관",
              "자료 검색",
              Icons.local_library,
              tokens.dashboardGradients[3],
              MainNavTabIndex.home,
            ),
            const SizedBox(width: 8),
            _expandedButton(
              "학사일정",
              "일정 확인",
              Icons.event_note,
              tokens.dashboardGradients[4],
              MainNavTabIndex.home,
            ),
            const SizedBox(width: 8),
            _expandedButton(
              "캠퍼스 약도",
              "위치 안내",
              Icons.map,
              tokens.dashboardGradients[5],
              MainNavTabIndex.home,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            _expandedButton(
              "시간표",
              "내 강의",
              Icons.calendar_month_rounded,
              <Color>[
                tokens.dashboardGradients[2].first,
                tokens.dashboardGradients[2].first,
              ],
              MainNavTabIndex.home,
            ),
          ],
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _kQuickShortcutsPanelHorizontalMargin,
        0,
        _kQuickShortcutsPanelHorizontalMargin,
        20,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: homeMutedBg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(_kQuickShortcutsBackgroundTopRadius),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: _kQuickShortcutsTopInset),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _kQuickShortcutsGridHorizontalPadding,
              ),
              child: cardRows,
            ),
          ],
        ),
      ),
    );
  }

  Widget _expandedButton(
    String title,
    String sub,
    IconData icon,
    List<Color> colors,
    int tabIndex, {
    NoticesSubTab? noticesSubTab,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = colors[0];
    final Color lightTitle = AppColors.quickCardText;
    final Color lightSub = AppColors.quickCardText.withValues(alpha: 0.72);
    final Color lightCardBg = scheme.surface;
    return Expanded(
      child: _HoverFeedback(
        onTap: () {
          if (title == "도서관") {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const LibraryScreen(),
              ),
            );
            return;
          }
          if (title == "학사일정") {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const AcademicScheduleScreen(),
              ),
            );
            return;
          }
          if (title == "캠퍼스 약도") {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const CampusMapScreen(),
              ),
            );
            return;
          }
          if (title == "시간표") {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const TimetableMainScreen(),
              ),
            );
            return;
          }
          widget.onNavigate(tabIndex, noticesSubTab: noticesSubTab);
        },
        child: SizedBox(
          height: 96,
          child: Material(
            color: isDark ? scheme.surface : lightCardBg,
            elevation: 1.5,
            shadowColor: Colors.black.withValues(
              alpha: isDark ? 0.45 : 0.12,
            ),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: (isDark ? tokens.cardBorder : scheme.outline)
                    .withValues(alpha: isDark ? 0.85 : 0.55),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: 0,
                  right: 0,
                  child: ClipPath(
                    clipper: const _TopRightDiagonalClipper(),
                    child: Container(
                      width: 42,
                      height: 42,
                      color: accent,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        icon,
                        color: accent,
                        size: isDark ? 20 : 24,
                      ),
                      const Spacer(),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? scheme.onSurface : lightTitle,
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? scheme.onSurfaceVariant : lightSub,
                          fontSize: 9.5,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFoodcourtSection(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: FutureBuilder<List<FoodcourtMenuItem>>(
        future: _foodcourtMenuFuture,
        builder: (context, snapshot) {
          final bool loading =
              snapshot.connectionState == ConnectionState.waiting;
          final List<FoodcourtMenuItem> items = snapshot.data ?? const [];
          return Material(
            color: scheme.surface,
            elevation: 1.5,
            shadowColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF7043)
                              .withValues(alpha: isDark ? 0.22 : 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.ramen_dining_rounded,
                          color: tokens.foodAccent,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "오늘의 학식",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              loading
                                  ? "메뉴를 불러오는 중입니다."
                                  : "${items.length}개 메뉴 중 고민되시나요?",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                                color: scheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: loading
                              ? null
                              : () => _recommendFoodcourtMenu(items),
                          icon: const Icon(Icons.casino_rounded),
                          label: const Text("오늘 뭐 먹지?"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openFoodcourtMenuScreen,
                          style: isDark
                              ? OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.switchActiveDark,
                                  side: BorderSide(
                                    color: AppColors.switchActiveDark
                                        .withValues(alpha: 0.55),
                                  ),
                                )
                              : null,
                          icon: const Icon(Icons.restaurant_menu_rounded),
                          label: const Text("전체 메뉴"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _recommendFoodcourtMenu(List<FoodcourtMenuItem> items) {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("추천할 학식 메뉴가 없습니다.")),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) {
        return _FoodcourtSlotMachineDialog(
          items: items,
          random: _foodRandom,
        );
      },
    );
  }

  void _openFoodcourtMenuScreen() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => const FoodcourtMenuScreen(),
      ),
    );
  }

  Widget _buildDeadlineSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Text(
                "핵심역량 프로그램 신청 마감 일정",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _mpuService.streamPrograms(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();

            final List<Map<String, dynamic>> items =
                snapshot.data!.where(mpuIncludeInHomeDeadlineList).toList()
                  ..sort((a, b) {
                    final int ad = mpuEffectiveDaysUntilDeadline(a) ?? 999999;
                    final int bd = mpuEffectiveDaysUntilDeadline(b) ?? 999999;
                    return ad.compareTo(bd);
                  });

            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text("진행 중인 일정이 없습니다."),
              );
            }

            final List<Map<String, dynamic>> top = items.take(3).toList();
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              itemCount: top.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _buildDeadlineCard(top[index]),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDeadlineCard(Map<String, dynamic> data) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String title = (data["title"] ?? "").toString();
    final String regLine = (data["reg_date"] ??
            data["end_date"] ??
            data["date"] ??
            data["deadline"] ??
            "")
        .toString()
        .trim();
    final String eduLine = (data["edu_date"] ?? "").toString().trim();

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          if (kIsWeb) {
            await launchUrl(
              Uri.parse(_mpuWebBaseUrl),
              webOnlyWindowName: "_blank",
            );
          } else {
            if (!context.mounted) return;
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const CommonWebViewScreen(
                  url: _mpuWebBaseUrl,
                  title: "핵심역량 관리 (MPU)",
                ),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        height: 1.15,
                      ),
                    ),
                    if (regLine.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        "신청: $regLine",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.1,
                        ),
                      ),
                    ],
                    if (eduLine.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        "교육: $eduLine",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              MpuDeadlineHomeStyleBadge(data: data),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAcademicScheduleSection(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _academicScheduleFuture,
      builder: (context, snapshot) {
        final List<Map<String, dynamic>> upcoming =
            _upcomingAcademicSchedules(snapshot.data ?? const []);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "다가오는 학사일정",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: _openAcademicScheduleScreen,
                    child: const Text("더보기"),
                  ),
                ],
              ),
            ),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: LinearProgressIndicator(minHeight: 2),
              )
            else if (upcoming.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text("예정된 학사일정이 없습니다."),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                itemCount: upcoming.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) =>
                    _buildAcademicScheduleCard(upcoming[index]),
              ),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> _upcomingAcademicSchedules(
    List<Map<String, dynamic>> items,
  ) {
    final DateTime today = DateTime.now();
    final DateTime startOfToday = DateTime(today.year, today.month, today.day);
    final DateTime limit = startOfToday.add(const Duration(days: 30));
    final List<Map<String, dynamic>> upcoming = items.where((item) {
      final DateTime? start =
          _parseIsoDate((item["start_date"] ?? item["date"] ?? "").toString());
      if (start == null) return false;
      return !start.isBefore(startOfToday) && !start.isAfter(limit);
    }).toList()
      ..sort((a, b) {
        final DateTime dateA =
            _parseIsoDate((a["start_date"] ?? a["date"] ?? "").toString()) ??
                DateTime(2099);
        final DateTime dateB =
            _parseIsoDate((b["start_date"] ?? b["date"] ?? "").toString()) ??
                DateTime(2099);
        return dateA.compareTo(dateB);
      });
    return upcoming.take(3).toList();
  }

  DateTime? _parseIsoDate(String value) {
    final RegExpMatch? match =
        RegExp(r"^(\d{4})[-.](\d{1,2})[-.](\d{1,2})").firstMatch(value);
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  Widget _buildAcademicScheduleCard(Map<String, dynamic> data) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String title = (data["title"] ?? "").toString();
    final String start = (data["start_date"] ?? data["date"] ?? "").toString();
    final String end = (data["end_date"] ?? start).toString();
    final DateTime? startDate = _parseIsoDate(start);
    final DateTime today = DateTime.now();
    final int dDay = startDate == null
        ? 0
        : startDate
            .difference(DateTime(today.year, today.month, today.day))
            .inDays;
    final String range = start.replaceAll("-", ".") == end.replaceAll("-", ".")
        ? start.replaceAll("-", ".")
        : "${start.replaceAll("-", ".")}~${end.replaceAll("-", ".")}";

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _openAcademicScheduleScreen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color:
                      AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    dDay <= 0 ? "D-DAY" : "D-$dDay",
                    style: TextStyle(
                      color: isDark ? Colors.white : scheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      range,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAcademicScheduleScreen() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => const AcademicScheduleScreen(),
      ),
    );
  }

  Widget _buildNoticeHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "최근 공지사항",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          TextButton(
            onPressed: () => widget.onNavigate(
              MainNavTabIndex.notices,
              noticesSubTab: NoticesSubTab.main,
            ),
            child: const Text("더보기"),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _combinedNoticeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<Map<String, dynamic>> all = snapshot.data ?? [];
        final unreadNotices = all
            .where(
              (Map<String, dynamic> n) =>
                  !_readDashboardNoticeKeys.contains(_dashboardNoticeKey(n)),
            )
            .toList();
        final NoticeFilterState filter =
            _noticeFilter.copyWith(quickQuery: _noticeQuickQuery);
        final notices = filter
            .apply(
          unreadNotices,
          sharedKeywords: _noticeSharedKeywords,
        )
            .where((n) {
          final String type = (n["type"] ?? n["category"] ?? "").toString();
          // 홈 "최근 공지사항"에서는 학사일정 항목을 숨깁니다.
          return !type.contains("학사일정");
        }).toList();
        if (notices.isEmpty) {
          return const Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: Text("새로운 소식이 없습니다.")),
              ),
            ],
          );
        }
        return Column(
          children: [
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: notices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final Widget card = _buildNoticeCard(notices[index]);
                return card;
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoticeCard(Map<String, dynamic> data) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    final String source = data["source"] ?? "본교";
    final Color accent = source == "MJC"
        ? tokens.sourceMjc
        : (source == "MPU" ? tokens.sourceMpu : tokens.sourceCtl);

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      shadowColor: Colors.black.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.45 : 0.12,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          String openUrl =
              (data["url"] ?? data["link"] ?? "").toString().trim();
          if (openUrl.isEmpty && source == "MPU") {
            openUrl = _mpuWebBaseUrl;
          }
          final title = data["title"] ?? "공지사항";
          if (openUrl.isEmpty) return;

          await _markDashboardNoticeRead(_dashboardNoticeKey(data));

          if (kIsWeb) {
            await launchUrl(Uri.parse(openUrl), webOnlyWindowName: "_blank");
          } else {
            if (!mounted) return;
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => CommonWebViewScreen(url: openUrl, title: title),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      "$source • ${data["type"] ?? "공지"}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    (data["reg_date"] ?? data["date"] ?? "")
                        .toString()
                        .split("~")
                        .first
                        .trim(),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                data["title"] ?? "",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoodcourtSlotMachineDialog extends StatefulWidget {
  const _FoodcourtSlotMachineDialog({
    required this.items,
    required this.random,
  });

  final List<FoodcourtMenuItem> items;
  final Random random;

  @override
  State<_FoodcourtSlotMachineDialog> createState() =>
      _FoodcourtSlotMachineDialogState();
}

class _FoodcourtSlotMachineDialogState
    extends State<_FoodcourtSlotMachineDialog> {
  Timer? _timer;
  late FoodcourtMenuItem _currentItem;
  bool _spinning = false;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _currentItem = _pickRandom();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startSpin();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  FoodcourtMenuItem _pickRandom() {
    return widget.items[widget.random.nextInt(widget.items.length)];
  }

  void _startSpin() {
    if (_spinning) return;
    _timer?.cancel();
    setState(() {
      _spinning = true;
      _tick = 0;
    });

    _timer = Timer.periodic(const Duration(milliseconds: 55), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final int nextTick = _tick + 1;
      final bool done = nextTick >= 12;
      setState(() {
        _tick = nextTick;
        _currentItem = _pickRandom();
        _spinning = !done;
      });

      if (done) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      title: const Text("오늘 뭐 먹지?"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: tokens.cardBorder,
              ),
            ),
            child: Column(
              children: [
                Text(
                  _spinning ? "두구두구..." : "오늘은 이거 어때요?",
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 90),
                  transitionBuilder: (child, animation) {
                    final Animation<Offset> offset = Tween<Offset>(
                      begin: const Offset(0, 0.45),
                      end: Offset.zero,
                    ).animate(animation);
                    return ClipRect(
                      child: SlideTransition(
                        position: offset,
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                    );
                  },
                  child: Text(
                    _currentItem.menu,
                    key: ValueKey("${_currentItem.shop}-${_currentItem.menu}"),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedOpacity(
                  opacity: _spinning ? 0.35 : 1,
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    "${_currentItem.shop} • ${_currentItem.formattedPrice}",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("닫기"),
        ),
        FilledButton.icon(
          onPressed: _spinning ? null : _startSpin,
          icon: const Icon(Icons.casino_rounded),
          label: Text(_spinning ? "고르는 중" : "또 뭐먹지"),
        ),
      ],
    );
  }
}

class _HoverFeedback extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _HoverFeedback({required this.child, required this.onTap});

  @override
  State<_HoverFeedback> createState() => _HoverFeedbackState();
}

class _HoverFeedbackState extends State<_HoverFeedback> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class _TopRightDiagonalClipper extends CustomClipper<Path> {
  const _TopRightDiagonalClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
