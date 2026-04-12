import "dart:ui" show lerpDouble;

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:mio_notice/screens/common_webview_screen.dart";
import "package:mio_notice/screens/main_navigation_screen.dart";
import "package:mio_notice/services/notice_manager.dart";
import "package:mio_notice/widgets/nested_scroll_refresh_indicator.dart";
import "package:url_launcher/url_launcher.dart";

class _MpuListEntrance {
  static bool _playedOnce = false;
  static bool _scheduleEntranceEnd = false;
  static int _generation = 0;

  static bool get shouldAnimateList => !_playedOnce;

  static void resetForNextVisit() {
    _generation++;
    _playedOnce = false;
    _scheduleEntranceEnd = false;
  }

  static void scheduleEndEntranceAnimation() {
    if (_playedOnce || _scheduleEntranceEnd) return;
    _scheduleEntranceEnd = true;
    final int g = _generation;
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (g != _generation) return;
      _playedOnce = true;
    });
  }
}

class MpuScreen extends StatefulWidget {
  const MpuScreen({super.key});

  @override
  State<MpuScreen> createState() => _MpuScreenState();
}

class _MpuScreenState extends State<MpuScreen> {
  @override
  void dispose() {
    _MpuListEntrance.resetForNextVisit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double topPad = MediaQuery.paddingOf(context).top;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverOverlapAbsorber(
                handle:
                    NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                sliver: SliverPersistentHeader(
                  pinned: true,
                  delegate: _MpuCollapsingHeaderDelegate(
                    topPadding: topPad,
                    tabBar: TabBar(
                      controller: DefaultTabController.of(context),
                      indicatorColor: const Color(0xFF7986CB),
                      indicatorWeight: 3,
                      labelColor: const Color(0xFF7986CB),
                      unselectedLabelColor: Colors.grey,
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
          body: const TabBarView(
            children: [
              _MpuListTab(showCompleted: false),
              _MpuListTab(showCompleted: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _MpuCollapsingHeaderDelegate extends SliverPersistentHeaderDelegate {
  _MpuCollapsingHeaderDelegate({
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
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints c) {
                        final double ih = c.maxHeight;
                        final double titleSize = lerpDouble(24, 17, u)!;
                        final double titleLeft = lerpDouble(20, 50, u)!;
                        final double bottomBlock = 20 + 13 + 6 + 24;
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
                              left: 0,
                              top: 0,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => MainNavigationScreen
                                      .scaffoldKey.currentState
                                      ?.openDrawer(),
                                  splashColor:
                                      Colors.white.withValues(alpha: 0.35),
                                  highlightColor:
                                      Colors.white.withValues(alpha: 0.14),
                                  child: const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: Icon(
                                      Icons.menu_rounded,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: titleLeft,
                              top: titleTop,
                              right: 12,
                              child: Text(
                                "역량관리 시스템 (MPU)",
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
                                  child: Opacity(
                                    opacity: subtitleOpacity,
                                    child: const Text(
                                      "자신의 역량을 관리하고 프로그램을 신청하세요",
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
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
            Material(
              color: Colors.white,
              elevation: overlapsContent || u > 0.02 ? 0.5 : 0,
              shadowColor: Colors.black12,
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
    return topPadding != old.topPadding || tabBar != old.tabBar;
  }
}

class _MpuListTab extends StatefulWidget {
  final bool showCompleted;
  const _MpuListTab({required this.showCompleted});
  @override
  State<_MpuListTab> createState() => _MpuListTabState();
}

class _MpuListTabState extends State<_MpuListTab> {
  late Future<List<Map<String, dynamic>>> _mpuFuture;

  @override
  void initState() {
    super.initState();
    _mpuFuture = NoticeManager().getNotices(boardId: "mpu_programs");
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _mpuFuture = NoticeManager().getNotices(boardId: "mpu_programs", forceRefresh: true);
    });
    await _mpuFuture;
  }

  @override
  Widget build(BuildContext context) {
    return NestedScrollRefreshIndicator(
      onRefresh: _handleRefresh,
      color: const Color(0xFF7986CB),
      backgroundColor: Colors.white,
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
    final List<Map<String, dynamic>> filteredItems = allItems.where((item) {
      final String dDay = (item["d_day"] ?? "").toString();
      final bool isCompleted = dDay.isEmpty ||
          dDay.contains("마감") ||
          dDay.contains("+") ||
          dDay == "D-0";
      return widget.showCompleted ? isCompleted : !isCompleted;
    }).toList();

    int getDValue(String d) {
      if (d.contains("마감")) return 9999;
      final RegExpMatch? match = RegExp(r"D([-+])(\d+)").firstMatch(d);
      if (match != null) {
        final int val = int.parse(match.group(2)!);
        return match.group(1) == "-" ? -val : val;
      }
      if (d == "D-0") return 0;
      return 9999;
    }

    filteredItems.sort((a, b) {
      final int valA = getDValue((a["d_day"] ?? "").toString());
      final int valB = getDValue((b["d_day"] ?? "").toString());
      if (widget.showCompleted) {
        return valA.compareTo(valB);
      }
      return valB.compareTo(valA);
    });

    if (filteredItems.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 48),
              Text(
                widget.showCompleted
                    ? "완료된 프로그램이 없습니다."
                    : "진행 중인 프로그램이 없습니다.",
                style: TextStyle(color: Colors.grey.shade600),
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
              if (index == 0 && _MpuListEntrance.shouldAnimateList) {
                _MpuListEntrance.scheduleEndEntranceAnimation();
              }
              final Map<String, dynamic> data = filteredItems[index];
              final Widget card = _buildMpuCard(context, data);
              if (_MpuListEntrance.shouldAnimateList) {
                return card
                    .animate()
                    .fadeIn(
                      delay: (index * 30).clamp(0, 300).ms,
                      duration: 300.ms,
                    )
                    .slideX(
                      begin: -0.05,
                      end: 0,
                      delay: (index * 30).clamp(0, 300).ms,
                      duration: 300.ms,
                      curve: Curves.easeOut,
                    );
              }
              return card;
            },
            childCount: filteredItems.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildMpuCard(BuildContext context, Map<String, dynamic> data) {
    final String title = data["title"] ?? "";
    final String branch = data["branch"] ?? "";
    final String dDay = data["d_day"] ?? "";
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: widget.showCompleted ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: widget.showCompleted ? 0 : 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            const url = "https://mpu.mjc.ac.kr/Main/default.aspx";
            if (kIsWeb) {
              await launchUrl(Uri.parse(url), webOnlyWindowName: "_blank");
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CommonWebViewScreen(url: url, title: "핵심역량 관리 (MPU)")));
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned(
                  left: 0, top: 0, bottom: 0, 
                  child: Container(
                    width: 5, 
                    decoration: BoxDecoration(
                      color: widget.showCompleted ? Colors.grey : const Color(0xFF7986CB),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: widget.showCompleted ? Colors.grey.shade200 : const Color(0xFFE8EAF6), borderRadius: BorderRadius.circular(6)),
                            child: Text(branch.isEmpty ? "핵심역량" : branch, style: TextStyle(color: widget.showCompleted ? Colors.grey : const Color(0xFF7986CB), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          if (dDay.isNotEmpty) Text(dDay, style: TextStyle(color: widget.showCompleted ? Colors.grey : const Color(0xFFFF4E6A), fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: widget.showCompleted ? Colors.grey.shade600 : const Color(0xFF222222), height: 1.3)),
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
}
