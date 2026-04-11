import "package:flutter/foundation.dart"; 
import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:mio_notice/screens/common_webview_screen.dart";
import "package:mio_notice/screens/main_navigation_screen.dart";
import "package:mio_notice/services/notice_manager.dart";
import "package:url_launcher/url_launcher.dart";

class MpuScreen extends StatelessWidget {
  const MpuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        body: Column(
          children: [
            _buildHeader(context),
            Container(
              color: Colors.white,
              child: const TabBar(
                indicatorColor: Color(0xFF7986CB),
                indicatorWeight: 3,
                labelColor: Color(0xFF7986CB),
                unselectedLabelColor: Colors.grey,
                labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                tabs: [
                  Tab(text: "진행 중"),
                  Tab(text: "마감 / 완료"),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _MpuListTab(showCompleted: false),
                  _MpuListTab(showCompleted: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7986CB), Color(0xFF90A4AE)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
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
                icon: const Icon(Icons.menu, color: Colors.white),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              const Text("역량관리 시스템 (MPU)", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          const Text("자신의 역량을 관리하고 프로그램을 신청하세요", style: TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
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
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: const Color(0xFF7986CB),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _mpuFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          final allItems = snapshot.data ?? [];
          
          // D-Day를 기준으로 진행 중 / 완료 분리
          // D-Day를 기준으로 진행 중 / 완료 분리
          final filteredItems = allItems.where((item) {
            final dDay = (item["d_day"] ?? "").toString();
            final isCompleted = dDay.isEmpty || dDay.contains("마감") || dDay.contains("+") || dDay == "D-0";
            return widget.showCompleted ? isCompleted : !isCompleted;
          }).toList();

          // D-Day 정렬 로직
          filteredItems.sort((a, b) {
            int getDValue(String d) {
              if (d.contains("마감")) return 9999;
              final match = RegExp(r"D([-+])(\d+)").firstMatch(d);
              if (match != null) {
                int val = int.parse(match.group(2)!);
                return match.group(1) == "-" ? -val : val;
              }
              if (d == "D-0") return 0;
              return 9999;
            }
            
            int valA = getDValue((a["d_day"] ?? "").toString());
            int valB = getDValue((b["d_day"] ?? "").toString());
            
            if (widget.showCompleted) {
              // 마감 탭: 최근 마감(D+1, D+2...) 순서
              return valA.compareTo(valB);
            } else {
              // 진행 중 탭: 임박(D-1, D-2...) 순서 (큰 음수가 뒤로)
              return valB.compareTo(valA);
            }
          });

          if (filteredItems.isEmpty) return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [const SizedBox(height: 100), Center(child: Text(widget.showCompleted ? "완료된 프로그램이 없습니다." : "진행 중인 프로그램이 없습니다."))]);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredItems.length,
            physics: const AlwaysScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final data = filteredItems[index];
              return _buildMpuCard(context, data)
                  .animate()
                  .fadeIn(delay: (index * 30).clamp(0, 300).ms, duration: 300.ms)
                  .slideX(begin: -0.05, end: 0, delay: (index * 30).clamp(0, 300).ms, duration: 300.ms, curve: Curves.easeOut);
            },
          );
        },
      ),
    );
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
