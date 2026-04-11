import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:mio_notice/screens/main_navigation_screen.dart";
import "package:mio_notice/services/notice_manager.dart";
import "package:url_launcher/url_launcher.dart";

/// 교수학습개발센터(CTL)의 공지와 프로그램을 보여주는 화면입니다.
class CtlScreen extends StatelessWidget {
  const CtlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // CTL 테마 컬러 (코발트 블루)
    const ctlThemeColor = Color(0xFF2962FF);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Column(
          children: [
            // 1. 헤더 (디자인 일관성 유지)
            _buildHeader(context, ctlThemeColor),

            // 2. 탭 바
            Container(
              color: Theme.of(context).colorScheme.surface,
              child: const TabBar(
                indicatorColor: ctlThemeColor,
                indicatorWeight: 3,
                labelColor: ctlThemeColor,
                unselectedLabelColor: Colors.grey,
                labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                tabs: [
                  Tab(text: "학습공지"),
                  Tab(text: "학습 프로그램"),
                ],
              ),
            ),

            // 3. 리스트 영역
            const Expanded(
              child: TabBarView(
                children: [
                   _CtlListTab(boardId: "notices", isProgram: false),
                   _CtlListTab(boardId: "programs", isProgram: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color color) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => MainNavigationScreen.scaffoldKey.currentState?.openDrawer(),
                icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              const Text(
                "교수학습개발센터 (CTL)",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "학생들의 학습 역량 강화를 지원합니다",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _CtlListTab extends StatefulWidget {
  final String boardId;
  final bool isProgram;
  const _CtlListTab({required this.boardId, required this.isProgram});

  @override
  State<_CtlListTab> createState() => _CtlListTabState();
}

class _CtlListTabState extends State<_CtlListTab> {
  late Future<List<Map<String, dynamic>>> _ctlFuture;
  String get _fetchId => widget.isProgram ? "ctl_programs" : "ctl_notices";

  @override
  void initState() {
    super.initState();
    _ctlFuture = NoticeManager().getNotices(boardId: _fetchId);
  }

  Future<void> _handleRefresh() async {
    setState(() {
       _ctlFuture = NoticeManager().getNotices(boardId: _fetchId, forceRefresh: true);
    });
    await _ctlFuture;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: const Color(0xFF2962FF),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ctlFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("에러: ${snapshot.error}"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          final items = snapshot.data ?? [];
          // 날짜 정렬 (매니저에서 기본 보장하지만 한 번 더 안정화)
          items.sort((a, b) {
            final aDate = a["reg_date"] ?? a["date"] ?? "";
            final bDate = b["reg_date"] ?? b["date"] ?? "";
            return bDate.compareTo(aDate);
          });
  
          if (items.isEmpty) {
             return ListView(
               physics: const AlwaysScrollableScrollPhysics(),
               children: const [
                 SizedBox(height: 100),
                 Center(child: Text("등록된 항목이 없습니다.")),
               ],
             );
          }
  
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            physics: const AlwaysScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final data = items[index];
              return _buildCtlCard(context, data)
                  .animate()
                  .fadeIn(delay: (index * 50).ms, duration: 300.ms)
                  .slideX(begin: -0.05, end: 0, delay: (index * 50).ms, duration: 300.ms, curve: Curves.easeOut);
            },
          );
        },
      ),
    );
  }

  Widget _buildCtlCard(BuildContext context, Map<String, dynamic> data) {
    final String title = data["title"] ?? "";
    final String date = data["reg_date"] ?? data["date"] ?? "";
    final String opPeriod = data["op_period"] ?? ""; // 진행 기간 필드 추가
    final String url = data["link"] ?? "";
    final String status = data["status"] ?? "진행중";
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.08),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          splashColor: const Color(0xFFE8EAF6),
          highlightColor: const Color(0xFFE8EAF6).withOpacity(0.3),
          onTap: () async {
            if (url.isEmpty) return;
            await launchUrl(Uri.parse(url), webOnlyWindowName: "_blank");
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Positioned(
                  left: 0, top: 0, bottom: 0,
                  child: Container(width: 4, color: const Color(0xFF2962FF)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 48, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (widget.isProgram)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(color: const Color(0xFFE8EAF6), borderRadius: BorderRadius.circular(4)),
                              child: Text(status, style: const TextStyle(color: Color(0xFF2962FF), fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          const Text("CTL", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF222222), height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      if (widget.isProgram && opPeriod.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF2962FF)),
                              const SizedBox(width: 6),
                              Expanded(child: Text("진행: $opPeriod", style: const TextStyle(color: Color(0xFF2962FF), fontSize: 13, fontWeight: FontWeight.w500))),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text("신청: $date", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Positioned(
                  right: 12, top: 0, bottom: 0,
                  child: Icon(Icons.chevron_right, color: Colors.grey, size: 24),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
