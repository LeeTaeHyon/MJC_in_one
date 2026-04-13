import "dart:ui" show lerpDouble;

import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/foundation.dart";
import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:mio_notice/screens/common_webview_screen.dart";
import "package:mio_notice/services/notice_manager.dart";
import "package:mio_notice/theme/app_colors.dart";
import "package:mio_notice/widgets/app_menu_drawer.dart";
import "package:mio_notice/widgets/scroll_to_top_scope.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";

/// 홈 슬라이드 메뉴 패널 너비 (본문 제스처·전역 오버레이 공통).
double homeSideMenuDrawerWidth(BuildContext context) {
  final double w = MediaQuery.sizeOf(context).width;
  return (w * 0.86).clamp(280.0, 400.0);
}

void applyHomeSideMenuSnap(
  AnimationController menuOpen, {
  required double velocityX,
}) {
  const double snapThreshold = 0.42;
  const double velocitySnapOpen = 400;
  const double velocitySnapClose = -400;
  final double v = menuOpen.value;
  if (velocityX >= velocitySnapOpen) {
    menuOpen.animateTo(1.0, curve: Curves.easeOutCubic);
  } else if (velocityX <= velocitySnapClose) {
    menuOpen.animateTo(0.0, curve: Curves.easeInCubic);
  } else if (v >= snapThreshold) {
    menuOpen.animateTo(1.0, curve: Curves.easeOutCubic);
  } else {
    menuOpen.animateTo(0.0, curve: Curves.easeInCubic);
  }
}

/// 홈 슬라이드 메뉴. [Scaffold] 위에 두어 하단 바·FAB보다 위에 그려지게 합니다.
class HomeSideMenuOverlay extends StatelessWidget {
  const HomeSideMenuOverlay({
    super.key,
    required this.menuOpen,
    required this.dialogContext,
  });

  final AnimationController menuOpen;
  final BuildContext dialogContext;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: menuOpen,
      builder: (BuildContext context, Widget? child) {
        final double v = menuOpen.value;
        if (v <= 0 && !menuOpen.isAnimating) {
          return const SizedBox.shrink();
        }

        final double dw = homeSideMenuDrawerWidth(context);
        final double slide = v * dw;

        void snapClosed() {
          menuOpen.animateTo(0.0, curve: Curves.easeInCubic);
        }

        final ThemeData theme = Theme.of(context);
        final DrawerThemeData drawerTheme = theme.drawerTheme;
        final ShapeBorder drawerShape = drawerTheme.shape ??
            const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            );

        return Positioned.fill(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (DragUpdateDetails d) {
                    menuOpen.value =
                        (menuOpen.value + d.delta.dx / dw).clamp(0.0, 1.0);
                  },
                  onHorizontalDragEnd: (DragEndDetails d) {
                    applyHomeSideMenuSnap(
                      menuOpen,
                      velocityX: d.primaryVelocity ?? 0,
                    );
                  },
                  child: Material(
                    color: Colors.black
                        .withValues(alpha: (0.48 * v).clamp(0.0, 0.55)),
                    child: InkWell(
                      onTap: snapClosed,
                      splashColor: Colors.white.withValues(alpha: 0.22),
                      highlightColor: Colors.white.withValues(alpha: 0.10),
                      hoverColor: Colors.white.withValues(alpha: 0.06),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -dw + slide,
                top: 0,
                bottom: 0,
                width: dw,
                child: GestureDetector(
                  onHorizontalDragUpdate: (DragUpdateDetails d) {
                    menuOpen.value =
                        (menuOpen.value + d.delta.dx / dw).clamp(0.0, 1.0);
                  },
                  onHorizontalDragEnd: (DragEndDetails d) {
                    applyHomeSideMenuSnap(
                      menuOpen,
                      velocityX: d.primaryVelocity ?? 0,
                    );
                  },
                  child: Material(
                    color: drawerTheme.backgroundColor ?? Colors.white,
                    elevation: drawerTheme.elevation ?? 1,
                    shadowColor: drawerTheme.shadowColor ?? Colors.black38,
                    surfaceTintColor: drawerTheme.surfaceTintColor,
                    shape: drawerShape,
                    clipBehavior: Clip.antiAlias,
                    child: AppMenuDrawerContent(
                      closeMenu: snapClosed,
                      closeBeforeSystemDialogs: true,
                      dialogContext: dialogContext,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class HomeDashboardScreen extends StatefulWidget {
  final void Function(int) onNavigate;
  final AnimationController menuOpen;

  const HomeDashboardScreen({
    super.key,
    required this.onNavigate,
    required this.menuOpen,
  });

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  late Future<List<Map<String, dynamic>>> _combinedNoticeFuture;
  Set<String> _readDashboardNoticeKeys = {};
  final ScrollController _scrollController = ScrollController();
  ScrollToTopCoordinator? _scrollToTopCoordinator;

  static const String _prefsReadDashboard = "read_notices_combined_dashboard";
  static const double _drawerEdgeDragFraction = 0.5;
  static const String _mpuWebBaseUrl = "https://mpu.mjc.ac.kr/Main/default.aspx";
  static const double _menuFabHit = 52;

  bool _menuPointerDown = false;
  bool _edgePullArmed = false;
  bool _menuHorizontalDrag = false;
  double _edgeAccumDx = 0;
  double _edgeAccumDy = 0;
  VelocityTracker? _menuVelocityTracker;

  @override
  void initState() {
    super.initState();
    _combinedNoticeFuture = _prepareDashboardNotices();
    _scrollController.addListener(_onHomeScrollOffset);
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
    final keys =
        (prefs.getStringList(_prefsReadDashboard) ?? []).toSet();
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
    final String url =
        (data["url"] ?? data["link"] ?? "").toString().trim();
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
    setState(() {
      _combinedNoticeFuture = NoticeManager().getNotices(
        boardId: "combined_dashboard",
        forceRefresh: true,
      );
    });
    await _combinedNoticeFuture;
  }

  void _snapMenuAfterDrag({required double velocityX}) {
    applyHomeSideMenuSnap(widget.menuOpen, velocityX: velocityX);
  }

  void _snapMenuClosed() {
    widget.menuOpen.animateTo(0.0, curve: Curves.easeInCubic);
  }

  void _openMenuFromIcon() {
    widget.menuOpen.animateTo(1.0, curve: Curves.easeOutCubic);
  }

  void _toggleMenuFromFab() {
    if (widget.menuOpen.value > 0.5) {
      _snapMenuClosed();
    } else {
      _openMenuFromIcon();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double topPad = MediaQuery.paddingOf(context).top;
    final double dw = homeSideMenuDrawerWidth(context);
    final double drawerDragEdgeW =
        MediaQuery.sizeOf(context).width * _drawerEdgeDragFraction;
    final Rect menuFabRect =
        Rect.fromLTWH(0, topPad, _menuFabHit, _menuFabHit);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (PointerDownEvent e) {
            if (widget.menuOpen.value > 0.001) return;
            _menuPointerDown = true;
            _edgePullArmed = e.localPosition.dx <= drawerDragEdgeW &&
                !menuFabRect.contains(e.localPosition);
            _menuHorizontalDrag = false;
            _edgeAccumDx = 0;
            _edgeAccumDy = 0;
            _menuVelocityTracker = VelocityTracker.withKind(e.kind)
              ..addPosition(e.timeStamp, e.position);
          },
          onPointerMove: (PointerMoveEvent e) {
            _menuVelocityTracker?.addPosition(e.timeStamp, e.position);
            if (!_menuPointerDown) return;

            if (_menuHorizontalDrag) {
              widget.menuOpen.value =
                  (widget.menuOpen.value + e.delta.dx / dw).clamp(0.0, 1.0);
              return;
            }
            if (!_edgePullArmed) return;

            _edgeAccumDx += e.delta.dx;
            _edgeAccumDy += e.delta.dy.abs();
            if (_edgeAccumDx > 10 && _edgeAccumDx > _edgeAccumDy * 1.25) {
              _menuHorizontalDrag = true;
              widget.menuOpen.value =
                  (widget.menuOpen.value + e.delta.dx / dw).clamp(0.0, 1.0);
            }
          },
          onPointerUp: (PointerUpEvent e) {
            _menuVelocityTracker?.addPosition(e.timeStamp, e.position);
            final double vx = _menuVelocityTracker == null
                ? 0
                : _menuVelocityTracker!.getVelocity().pixelsPerSecond.dx;
            if (_menuHorizontalDrag) {
              _snapMenuAfterDrag(velocityX: vx);
            }
            _menuPointerDown = false;
            _edgePullArmed = false;
            _menuHorizontalDrag = false;
            _menuVelocityTracker = null;
          },
          onPointerCancel: (_) {
            if (_menuHorizontalDrag) {
              _snapMenuAfterDrag(velocityX: 0);
            }
            _menuPointerDown = false;
            _edgePullArmed = false;
            _menuHorizontalDrag = false;
            _menuVelocityTracker = null;
          },
          child: AbsorbPointer(
            absorbing: widget.menuOpen.value > 0.001,
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              color: AppColors.primary,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _HomeHeroHeaderDelegate(
                      topPadding: topPad,
                      onMenuTap: _toggleMenuFromFab,
                      menuOpen: widget.menuOpen,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildGridButtons(context),
                        _buildDeadlineSection(context),
                        _buildNoticeHeader(context),
                        _buildNoticeList(),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGridButtons(BuildContext context) {
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
                [const Color(0xFF0D47A1), const Color(0xFF1976D2)],
                2,
              ),
              const SizedBox(width: 12),
              _expandedButton(
                "교수학습",
                "학습 지원",
                Icons.menu_book,
                [const Color(0xFF2962FF), const Color(0xFF448AFF)],
                3,
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
                [const Color(0xFF7986CB), const Color(0xFF90A4AE)],
                4,
              ),
              const SizedBox(width: 12),
              _expandedButton(
                "도서관",
                "자료 검색",
                Icons.local_library,
                [const Color(0xFF0288D1), const Color(0xFF26C6DA)],
                1,
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
    int tabIndex,
  ) {
    return Expanded(
      child: _HoverFeedback(
        onTap: () => widget.onNavigate(tabIndex),
        child: Container(
          height: 110,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 26),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ),
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
              Icon(Icons.alarm, color: Colors.redAccent, size: 20),
              SizedBox(width: 8),
              Text(
                "신청 마감 임박",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection("core_competencies")
                .doc("all")
                .collection("programs")
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final items = snapshot.data!.docs
                  .where(
                    (doc) =>
                        (doc.data()["d_day"] ?? "").toString().contains("D-"),
                  )
                  .toList();
              if (items.isEmpty) {
                return const Center(child: Text("진행 중인 프로그램이 없습니다."));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                itemBuilder: (context, index) =>
                    _buildDeadlineCard(items[index].data()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDeadlineCard(Map<String, dynamic> data) {
    return Container(
      width: 200,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            if (kIsWeb) {
              await launchUrl(
                Uri.parse(_mpuWebBaseUrl),
                webOnlyWindowName: "_blank",
              );
            } else {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => CommonWebViewScreen(
                    url: _mpuWebBaseUrl,
                    title: "핵심역량 관리 (MPU)",
                  ),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    data["d_day"] ?? "",
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data["title"] ?? "",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
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
            onPressed: () => widget.onNavigate(2),
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
        final notices = all
            .where(
              (Map<String, dynamic> n) =>
                  !_readDashboardNoticeKeys.contains(_dashboardNoticeKey(n)),
            )
            .toList();
        if (notices.isEmpty) {
          return const Center(child: Text("새로운 소식이 없습니다."));
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: notices.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _buildNoticeCard(notices[index]),
        );
      },
    );
  }

  Widget _buildNoticeCard(Map<String, dynamic> data) {
    final String source = data["source"] ?? "본교";
    final Color accent = source == "MJC"
        ? const Color(0xFF1976D2)
        : (source == "MPU"
            ? const Color(0xFF7986CB)
            : const Color(0xFF2962FF));

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
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
                builder: (_) =>
                    CommonWebViewScreen(url: openUrl, title: title),
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
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
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
    required this.onMenuTap,
    required this.menuOpen,
  });

  final double topPadding;
  final VoidCallback onMenuTap;
  final Animation<double> menuOpen;

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

    return SizedBox(
      height: extent,
      width: double.infinity,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.primary),
            Positioned.fill(
              child: Opacity(
                opacity: 0.35 * (1.0 - u),
                child: Image.network(
                  _heroImageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  alignment: Alignment.center,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
                  final double titleLeft = lerpDouble(24, 52, u)!;
                  final double bottomBlock =
                      24 + 16 + 6 + 34; // 여백 + 부제 + 간격 + 큰 타이틀
                  final double expandedTitleTop =
                      (ih - bottomBlock).clamp(0.0, ih);
                  final double collapsedTitleTop =
                      (ih - titleSize * 1.15) / 2;
                  final double titleTop =
                      lerpDouble(expandedTitleTop, collapsedTitleTop, u)!;
                  final double subtitleOpacity =
                      (1.0 - u * 1.35).clamp(0.0, 1.0);

                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned(
                        left: 2,
                        top: 0,
                        child: AnimatedBuilder(
                          animation: menuOpen,
                          builder: (BuildContext context, Widget? child) {
                            final double m = menuOpen.value;
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: onMenuTap,
                                splashColor:
                                    Colors.white.withValues(alpha: 0.38),
                                highlightColor:
                                    Colors.white.withValues(alpha: 0.16),
                                hoverColor:
                                    Colors.white.withValues(alpha: 0.12),
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: m > 0.02
                                          ? Color.lerp(
                                              Colors.white
                                                  .withValues(alpha: 0.18),
                                              Colors.black
                                                  .withValues(alpha: 0.06),
                                              m,
                                            )
                                          : Colors.transparent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: AnimatedIcon(
                                        icon: AnimatedIcons.menu_close,
                                        progress: menuOpen,
                                        color: Color.lerp(
                                          Colors.white,
                                          const Color(0xFF212121),
                                          m,
                                        )!,
                                        size: 26,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
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
    return topPadding != oldDelegate.topPadding ||
        onMenuTap != oldDelegate.onMenuTap ||
        menuOpen != oldDelegate.menuOpen;
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
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}
