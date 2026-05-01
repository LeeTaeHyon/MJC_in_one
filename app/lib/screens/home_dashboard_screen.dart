import "dart:async";
import "dart:math";
import "dart:ui" show lerpDouble;

import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:mio_notice/screens/academic_schedule_screen.dart";
import "package:mio_notice/screens/common_webview_screen.dart";
import "package:mio_notice/screens/foodcourt_menu_screen.dart";
import "package:mio_notice/screens/notices_tab_screen.dart";
import "package:mio_notice/services/foodcourt_menu.dart";
import "package:mio_notice/services/notice_filter.dart";
import "package:mio_notice/services/notice_manager.dart";
import "package:mio_notice/theme/app_colors.dart";
import "package:mio_notice/theme/app_theme.dart";
import "package:mio_notice/widgets/scroll_to_top_scope.dart";
import "package:mio_notice/widgets/shuttle_status_card.dart";
import "package:mio_notice/debug/agent_logger.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";

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
  final Random _foodRandom = Random();
  ScrollToTopCoordinator? _scrollToTopCoordinator;

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
    _scrollController.addListener(_onHomeScrollOffset);
    // 첫 진입 시 히어로 이미지 디코드/업로드 비용이 스크롤/전환 jank로 튀는 걸 줄이기 위해 프리캐시.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      precacheImage(
          const NetworkImage(_HomeHeroHeaderDelegate._heroImageUrl), context);
    });
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
      c.registerMainTab(MainNavTabIndex.home, _scrollContentToTop);
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
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onHomeScrollOffset);
    _scrollToTopCoordinator?.unregisterMainTab(MainNavTabIndex.home);
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
    // #region agent log
    AgentLogger.log(
      hypothesisId: "B",
      location: "home_dashboard_screen.dart:build",
      message: "HomeDashboardScreen build",
      data: <String, Object?>{
        "hasScrollClients": _scrollController.hasClients,
      },
    );
    // #endregion
    final double topPad = MediaQuery.paddingOf(context).top;
    // Home tab must always be visually opaque during transitions, otherwise
    // AnimatedSwitcher fade can reveal the previous tab underneath.
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppColors.primary,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _HomeHeroHeaderDelegate(topPadding: topPad),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildGridButtons(context),
                  const ShuttleStatusCard(),
                  _buildFoodcourtSection(context),
                  _buildDeadlineSection(context),
                  _buildAcademicScheduleSection(context),
                  _buildNoticeHeader(context),
                  _buildNoticeList(),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridButtons(BuildContext context) {
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
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
              const SizedBox(width: 12),
              _expandedButton(
                "교수학습",
                "학습 지원",
                Icons.menu_book,
                tokens.dashboardGradients[1],
                MainNavTabIndex.notices,
                noticesSubTab: NoticesSubTab.ctl,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _expandedButton(
                "역량관리",
                "프로그램 신청",
                Icons.emoji_events,
                tokens.dashboardGradients[2],
                MainNavTabIndex.notices,
                noticesSubTab: NoticesSubTab.mpu,
              ),
              const SizedBox(width: 12),
              _expandedButton(
                "도서관",
                "자료 검색",
                Icons.local_library,
                tokens.dashboardGradients[3],
                MainNavTabIndex.library,
              ),
            ],
          ),
        ],
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
    final Color accent = colors.last;
    return Expanded(
      child: _HoverFeedback(
        onTap: () => widget.onNavigate(tabIndex, noticesSubTab: noticesSubTab),
        child: Container(
          height: 110,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? scheme.surface : null,
            gradient: isDark
                ? null
                : LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(16),
            border: isDark
                ? Border.all(color: tokens.cardBorder.withValues(alpha: 0.85))
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.36 : 0.0),
                blurRadius: isDark ? 14 : 0,
                offset: const Offset(0, 6),
              ),
              if (!isDark)
                BoxShadow(
                  color: colors.first.withValues(alpha: 0.30),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: isDark
                      ? accent.withValues(alpha: 0.16)
                      : Colors.white.withValues(alpha: 0.0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(isDark ? 8 : 0),
                  child: Icon(
                    icon,
                    color: isDark ? accent : Colors.white,
                    size: isDark ? 24 : 26,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? scheme.onSurface : Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? scheme.onSurfaceVariant : Colors.white70,
                  fontSize: 10,
                ),
              ),
            ],
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
                                  : "${items.length}개 메뉴 중 골라드릴게요.",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                height: 1.2,
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
                          label: const Text("학식 뭐먹지?"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openFoodcourtMenuScreen,
                          icon: const Icon(Icons.restaurant_menu_rounded),
                          label: const Text("학식 메뉴"),
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
    int? parseDDay(dynamic v) {
      final String s = (v ?? "").toString().trim();
      final RegExpMatch? m =
          RegExp(r"^D-(\d+)$", caseSensitive: false).firstMatch(s);
      if (m == null) return null;
      return int.tryParse(m.group(1)!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Text(
                "MPU 신청 마감",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection("core_competencies")
              .doc("all")
              .collection("programs")
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();

            final List<Map<String, dynamic>> items = snapshot.data!.docs
                .map((d) => d.data())
                .where((m) => parseDDay(m["d_day"]) != null)
                .toList()
              ..sort((a, b) {
                final int ad = parseDDay(a["d_day"]) ?? 999999;
                final int bd = parseDDay(b["d_day"]) ?? 999999;
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
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String title = (data["title"] ?? "").toString();
    final String ddayRaw = (data["d_day"] ?? "").toString().trim();
    final String dateLine = (data["end_date"] ??
            data["date"] ??
            data["reg_date"] ??
            data["deadline"] ??
            "")
        .toString()
        .trim();

    final String dNumber = (RegExp(r"^D-(\d+)$", caseSensitive: false)
                .firstMatch(ddayRaw)
                ?.group(1) ??
            "")
        .trim();

    Widget ddayBadge() {
      return SizedBox(
        width: 56,
        height: 56,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.deadlineBadge,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "D-",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dNumber.isEmpty ? "?" : dNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
                    if (dateLine.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        dateLine,
                        maxLines: 1,
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
              ddayBadge(),
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
                      color: scheme.primary,
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

/// 스크롤에 따라 히어로가 접히고, 학교명 한 줄이 햄버거 옆으로 밀려 들어갑니다.
class _HomeHeroHeaderDelegate extends SliverPersistentHeaderDelegate {
  _HomeHeroHeaderDelegate({
    required this.topPadding,
  });

  final double topPadding;

  static const double _heroBody = 240;
  static const double _collapsedBar = 52;
  static const String _heroImageUrl =
      "https://www.mjc.ac.kr/images/common/main_visual01.jpg";

  @override
  double get maxExtent => topPadding + _heroBody;

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

    return SizedBox(
      height: extent,
      width: double.infinity,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: isDark ? const Color(0xFF073A8C) : AppColors.primary,
            ),
            Positioned.fill(
              child: Builder(
                builder: (BuildContext context) {
                  final double dpr = MediaQuery.devicePixelRatioOf(context);
                  final Size size = MediaQuery.sizeOf(context);
                  // 이미지 원본이 큰 편이라, 화면 크기에 맞춰 디코드해 raster 튐을 줄입니다.
                  final int cw = (size.width * dpr).round().clamp(1, 4096);
                  final int ch = (extent * dpr).round().clamp(1, 4096);
                  return Image.network(
                    _heroImageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    alignment: Alignment.center,
                    cacheWidth: cw,
                    cacheHeight: ch,
                    // Opacity(saveLayer) 대신 colorFilter로 블렌딩해서 raster 비용을 줄입니다.
                    color: Colors.black.withValues(
                      alpha:
                          ((isDark ? 0.50 : 0.35) * (1.0 - u)).clamp(0.0, 1.0),
                    ),
                    colorBlendMode: BlendMode.srcOver,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
                  const double bottomBlock =
                      24 + 16 + 6 + 34; // 여백 + 부제 + 간격 + 큰 타이틀
                  final double expandedTitleTop =
                      (ih - bottomBlock).clamp(0.0, ih);
                  final double collapsedTitleTop = (ih - titleSize * 1.15) / 2;
                  final double titleTop =
                      lerpDouble(expandedTitleTop, collapsedTitleTop, u)!;
                  final double subtitleOpacity =
                      (1.0 - u * 1.35).clamp(0.0, 1.0);

                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned(
                        left: titleLeft,
                        top: titleTop,
                        right: 16,
                        child: Text(
                          "MJC in one",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: titleSize,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                      ),
                      if (subtitleOpacity > 0.02)
                        Positioned(
                          left: 24,
                          top: titleTop + titleSize * 0.95 + 6,
                          right: 16,
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: subtitleOpacity,
                              child: const Text(
                                "MJC 통합 정보 서비스",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  height: 1.2,
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
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HomeHeroHeaderDelegate oldDelegate) {
    return topPadding != oldDelegate.topPadding;
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
      title: const Text("학식 뭐먹지?"),
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
