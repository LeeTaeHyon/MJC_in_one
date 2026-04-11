import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:mio_notice/screens/main_navigation_screen.dart";
import "package:mio_notice/services/notice_manager.dart";
import "package:url_launcher/url_launcher.dart";

/// MPU 핵심역량 관리 시스템의 프로그램 목록을 보여주는 화면입니다.
class MpuScreen extends StatelessWidget {
  const MpuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // MPU 테마 컬러 (퍼플)
    const mpuThemeColor = Color(0xFF7986CB);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Column(
          children: [
            // 1. 헤더 (퍼플 그라데이션)
            _buildHeader(context, mpuThemeColor),

            // 2. 탭 바
            Container(
              color: Theme.of(context).colorScheme.surface,
              child: const TabBar(
                indicatorColor: mpuThemeColor,
                indicatorWeight: 3,
                labelColor: mpuThemeColor,
                unselectedLabelColor: Colors.grey,
                labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                tabs: [
                  Tab(text: "진행 중인 프로그램"),
                  Tab(text: "완료된 프로그램"),
                ],
              ),
            ),

            // 3. 리스트 영역
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

  Widget _buildHeader(BuildContext context, Color color) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withAlpha(200)],
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
                "핵심역량 관리 (MPU)",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "미래 인재를 위한 맞춤형 역량 강화 코스",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
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
          if (snapshot.hasError) return Center(child: Text("에러: ${snapshot.error}"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          // 1. 필터링 로직
          final allData = snapshot.data ?? [];
          final filteredItems = allData.where((data) {
            final String dday = data["d_day"] ?? "";
            final bool isOngoing = dday.contains("D-") || dday.contains("D-DAY");
            return widget.showCompleted ? !isOngoing : isOngoing;
          }).toList();

          // 2. 정렬 로직
          filteredItems.sort((a, b) {
            final String aDDay = a["d_day"] ?? "";
            final String bDDay = b["d_day"] ?? "";

            if (widget.showCompleted) {
              int getDPlusValue(String dday) {
                final match = RegExp(r"D\+(\d+)").firstMatch(dday);
                if (match != null) return int.parse(match.group(1)!);
                return 9999; 
              }
              int aVal = getDPlusValue(aDDay);
              int bVal = getDPlusValue(bDDay);
              if (aVal != bVal) return aVal.compareTo(bVal);
            } else {
              int getDMinusValue(String dday) {
                if (dday.contains("D-DAY")) return 0;
                final match = RegExp(r"D-(\d+)").firstMatch(dday);
                if (match != null) return int.parse(match.group(1)!);
                return 9999;
              }
              int aVal = getDMinusValue(aDDay);
              int bVal = getDMinusValue(bDDay);
              if (aVal != bVal) return aVal.compareTo(bVal);
            }
            
            final aTime = a["created_at"] ?? "";
            final bTime = b["created_at"] ?? "";
            return bTime.compareTo(aTime);
          });

          if (filteredItems.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 100),
                Center(child: Text(widget.showCompleted ? "완료된 프로그램이 없습니다." : "현재 진행 중인 프로그램이 없습니다.")),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredItems.length,
            physics: const AlwaysScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final data = filteredItems[index];
              return _buildMpuCard(context, data)
                  .animate()
                  .fadeIn(delay: (index * 50).ms, duration: 300.ms)
                  .slideX(begin: -0.05, end: 0, delay: (index * 50).ms, duration: 300.ms, curve: Curves.easeOut);
            },
          );
        },
      ),
    );
  }

  Widget _buildMpuCard(BuildContext context, Map<String, dynamic> data) {
    final String title = data["title"] ?? "";
    final String branch = data["branch"] ?? "";
    final String date = data["reg_date"] ?? "";
    final String dDay = data["d_day"] ?? "";
    final List<dynamic> tags = data["tags"] ?? [];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: widget.showCompleted ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: widget.showCompleted ? 0 : 2,
        shadowColor: Colors.black.withOpacity(0.08),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: const Color(0xFFE8EAF6),
          highlightColor: const Color(0xFFE8EAF6).withOpacity(0.3),
          onTap: () async {
            const url = "https://mpu.mjc.ac.kr/Main/default.aspx";
            await launchUrl(Uri.parse(url), webOnlyWindowName: "_blank");
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Positioned(
                  left: 0, top: 0, bottom: 0,
                  child: Container(width: 5, color: widget.showCompleted ? Colors.grey : const Color(0xFF7986CB)),
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
                            decoration: BoxDecoration(
                              color: widget.showCompleted ? Colors.grey.shade200 : const Color(0xFFE8EAF6), 
                              borderRadius: BorderRadius.circular(6)
                            ),
                            child: Text(branch.isEmpty ? "핵심역량" : branch, 
                               style: TextStyle(color: widget.showCompleted ? Colors.grey : const Color(0xFF7986CB), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          if (dDay.isNotEmpty)
                            Text(dDay, style: TextStyle(
                              color: widget.showCompleted ? Colors.grey : const Color(0xFFFF4E6A), 
                              fontSize: 12, 
                              fontWeight: FontWeight.bold
                            )),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 17, 
                          fontWeight: FontWeight.bold, 
                          color: widget.showCompleted ? Colors.grey.shade600 : const Color(0xFF222222), 
                          height: 1.3
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Wrap(
                            spacing: 6,
                            children: tags.map((t) => Text("#$t", style: const TextStyle(color: Colors.grey, fontSize: 11))).toList(),
                          ),
                        ),
                      Row(
                        children: [
                          const Icon(Icons.assignment_ind_outlined, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text("신청: $date", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
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
}
