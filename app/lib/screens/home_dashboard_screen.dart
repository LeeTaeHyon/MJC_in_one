import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:mio_notice/screens/main_navigation_screen.dart";
import "package:mio_notice/services/notice_manager.dart";
import "package:mio_notice/theme/app_colors.dart";
import "package:url_launcher/url_launcher.dart";

class HomeDashboardScreen extends StatefulWidget {
  final void Function(int) onNavigate;
  const HomeDashboardScreen({super.key, required this.onNavigate});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  late Future<List<Map<String, dynamic>>> _combinedNoticeFuture;

  @override
  void initState() {
    super.initState();
    _combinedNoticeFuture = NoticeManager().getNotices(boardId: "combined_dashboard");
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _combinedNoticeFuture = NoticeManager().getNotices(boardId: "combined_dashboard", forceRefresh: true);
    });
    await _combinedNoticeFuture;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildHeader(context),
            _buildGridButtons(context),
            _buildDeadlineSection(context),
            _buildNoticeHeader(context),
            _buildNoticeList(),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 240,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        image: DecorationImage(
          image: NetworkImage("https://www.mjc.ac.kr/images/common/main_visual01.jpg"),
          fit: BoxFit.cover,
          opacity: 0.35,
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 8, left: 12,
              child: IconButton(
                onPressed: () => MainNavigationScreen.scaffoldKey.currentState?.openDrawer(),
                icon: const Icon(Icons.menu, color: Colors.white, size: 28),
              ),
            ),
            const Positioned(
              bottom: 24, left: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("명지전문대학", style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
                  Text("MJC 통합 정보 서비스", style: TextStyle(color: Colors.white70, fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              _expandedButton("본교 공지", "최신 소식", Icons.school, [const Color(0xFF0D47A1), const Color(0xFF1976D2)], 2),
              const SizedBox(width: 12),
              _expandedButton("교수학습", "학습 지원", Icons.menu_book, [const Color(0xFF2962FF), const Color(0xFF448AFF)], 3),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _expandedButton("역량관리", "프로그램 신청", Icons.emoji_events, [const Color(0xFF7986CB), const Color(0xFF90A4AE)], 4),
              const SizedBox(width: 12),
              _expandedButton("도서관", "자료 검색", Icons.local_library, [const Color(0xFF0288D1), const Color(0xFF26C6DA)], 1),
            ],
          ),
        ],
      ),
    );
  }

  Widget _expandedButton(String title, String sub, IconData icon, List<Color> colors, int tabIndex) {
    return Expanded(
      child: _HoverFeedback(
        onTap: () => widget.onNavigate(tabIndex),
        child: Container(
          height: 110, padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: colors.first.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: Colors.white, size: 26), const Spacer(),
            Text(
              title, 
              maxLines: 1, 
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)
            ),
            Text(
              sub, 
              maxLines: 1, 
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 10)
            ),
          ]),
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
          child: Row(children: [
            Icon(Icons.alarm, color: Colors.redAccent, size: 20),
            SizedBox(width: 8),
            Text("신청 마감 임박", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ]),
        ),
        SizedBox(
          height: 160,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection("core_competencies").doc("all").collection("programs").snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final items = snapshot.data!.docs.where((doc) => (doc["d_day"] ?? "").toString().contains("D-")).toList();
              if (items.isEmpty) return const Center(child: Text("진행 중인 프로그램이 없습니다."));
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                itemBuilder: (context, index) => _buildDeadlineCard(items[index].data() as Map<String, dynamic>),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDeadlineCard(Map<String, dynamic> data) {
    return Container(
      width: 200, margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Material(
        color: Colors.white, borderRadius: BorderRadius.circular(16), elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => launchUrl(Uri.parse("https://mpu.mjc.ac.kr"), webOnlyWindowName: "_blank"),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: const Color(0xFFFFEBEF), borderRadius: BorderRadius.circular(4)), child: Text(data["d_day"] ?? "", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12))),
              const SizedBox(height: 8),
              Text(data["title"] ?? "", maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
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
          const Text("최근 공지사항", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          TextButton(onPressed: () => widget.onNavigate(2), child: const Text("더보기")),
        ],
      ),
    );
  }

  Widget _buildNoticeList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _combinedNoticeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final notices = snapshot.data ?? [];
        if (notices.isEmpty) return const Center(child: Text("새로운 소식이 없습니다."));
        return ListView.separated(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
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
    Color accent = source == "MJC" ? const Color(0xFF1976D2) : (source == "MPU" ? const Color(0xFF7986CB) : const Color(0xFF2962FF));

    return Material(
      color: Colors.white, borderRadius: BorderRadius.circular(12), elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final url = data["url"] ?? data["link"] ?? "";
          if (url.isNotEmpty) launchUrl(Uri.parse(url), webOnlyWindowName: "_blank");
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
                        style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.bold)
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      (data["reg_date"] ?? data["date"] ?? "").split("~")[0].trim(), 
                      style: const TextStyle(color: Colors.grey, fontSize: 11)
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  data["title"] ?? "", 
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, height: 1.3)
                ),
              ],
            ),
          ),
      ),
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
      child: AnimatedScale(scale: _isPressed ? 0.96 : 1.0, duration: const Duration(milliseconds: 100), child: widget.child),
    );
  }
}
