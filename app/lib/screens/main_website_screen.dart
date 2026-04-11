import "package:flutter/foundation.dart"; // kIsWeb 사용
import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:mio_notice/screens/common_webview_screen.dart";
import "package:mio_notice/screens/main_navigation_screen.dart";
import "package:mio_notice/services/notice_manager.dart";
import "package:mio_notice/theme/app_colors.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";

/// 명지전문대학 공식 홈페이지의 공지사항을 탭별로 보여주는 화면입니다.
class MainWebsiteScreen extends StatelessWidget {
  const MainWebsiteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Column(
          children: [
            _buildHeader(context),
            Container(
              color: Colors.white,
              child: const TabBar(
                indicatorColor: Color(0xFF003FB4),
                indicatorWeight: 3,
                labelColor: Color(0xFF003FB4),
                unselectedLabelColor: Colors.grey,
                labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                tabs: [
                  Tab(text: "공지사항"),
                  Tab(text: "학사공지"),
                  Tab(text: "장학공지"),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                   _NoticeListTab(boardId: "main_notice"),
                   _NoticeListTab(boardId: "main_academic"),
                   _NoticeListTab(boardId: "main_scholarship"),
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
          colors: [Color(0xFF003FB4), Color(0xFF0056D2)],
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
                "메인 홈페이지",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "최신 공지사항을 확인하세요",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _NoticeListTab extends StatefulWidget {
  final String boardId;
  const _NoticeListTab({required this.boardId});

  @override
  State<_NoticeListTab> createState() => _NoticeListTabState();
}

class _NoticeListTabState extends State<_NoticeListTab> {
  Set<String> _readNoticeIds = {};
  late Future<List<Map<String, dynamic>>> _noticeFuture;

  @override
  void initState() {
    super.initState();
    _loadReadHistory();
    _noticeFuture = NoticeManager().getNotices(boardId: widget.boardId);
  }

  Future<void> _loadReadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _readNoticeIds = (prefs.getStringList("read_notices_${widget.boardId}") ?? []).toSet();
    });
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _noticeFuture = NoticeManager().getNotices(
        boardId: widget.boardId, 
        forceRefresh: true
      );
    });
    await _noticeFuture;
  }

  Future<void> _markAsRead(String id) async {
    if (_readNoticeIds.contains(id)) return;
    
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _readNoticeIds.add(id);
    });
    await prefs.setStringList("read_notices_${widget.boardId}", _readNoticeIds.toList());
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: const Color(0xFF003FB4),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _noticeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data ?? [];
  
          if (docs.isEmpty) {
             return ListView( 
               physics: const AlwaysScrollableScrollPhysics(),
               children: const [
                 SizedBox(height: 100),
                 Center(child: Text("표시할 공지가 없습니다.")),
               ],
             );
          }
  
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            physics: const AlwaysScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final data = docs[index];
              final String id = data["id"] ?? "";
              final bool isRead = _readNoticeIds.contains(id);
              final String url = data["url"] ?? "";
              
              return _ScaleFeedbackButton(
                onTap: () async {
                  await _markAsRead(id); 
                  if (url.isEmpty) return;
                  if (kIsWeb) {
                    await launchUrl(Uri.parse(url), webOnlyWindowName: "_blank");
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => CommonWebViewScreen(url: url, title: data["title"] ?? "공지사항")));
                  }
                },
                child: _buildNoticeListItem(context, data, id, isRead, () async {
                   await _markAsRead(id);
                   if (url.isEmpty) return;
                   if (kIsWeb) {
                     await launchUrl(Uri.parse(url), webOnlyWindowName: "_blank");
                   } else {
                     Navigator.push(context, MaterialPageRoute(builder: (_) => CommonWebViewScreen(url: url, title: data["title"] ?? "공지사항")));
                   }
                }),
              ).animate()
                .fadeIn(delay: (index * 30).clamp(0, 300).ms, duration: 300.ms)
                .slideX(begin: -0.05, end: 0, delay: (index * 30).clamp(0, 300).ms, duration: 300.ms, curve: Curves.easeOut);
            },
          );
        },
      ),
    );
  }

  Widget _buildNoticeListItem(BuildContext context, Map<String, dynamic> data, String id, bool isRead, VoidCallback onTap) {
    final String title = data["title"] ?? "";
    final String dateStr = data["date"] ?? "";
    final String type = data["category"] ?? "공지";
    final Color mainColor = isRead ? Colors.grey : const Color(0xFF003FB4);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isRead ? const Color(0xFFF1F3F4) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: isRead ? 0 : 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned(
                  left: 0, top: 0, bottom: 0,
                  child: Container(
                    width: 4, 
                    decoration: BoxDecoration(
                      color: mainColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 48, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: isRead ? Colors.grey.shade200 : const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(4)),
                        child: Text(type, style: TextStyle(color: isRead ? Colors.grey : const Color(0xFF1976D2), fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 12),
                      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: isRead ? FontWeight.normal : FontWeight.bold, color: isRead ? Colors.grey.shade600 : const Color(0xFF222222), height: 1.4)),
                      const SizedBox(height: 12),
                      Row(children: [const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey), const SizedBox(width: 6), Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 13))]),
                    ],
                  ),
                ),
                const Positioned(right: 12, top: 0, bottom: 0, child: Icon(Icons.chevron_right, color: Colors.grey, size: 24)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScaleFeedbackButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _ScaleFeedbackButton({required this.child, required this.onTap});
  @override
  State<_ScaleFeedbackButton> createState() => _ScaleFeedbackButtonState();
}

class _ScaleFeedbackButtonState extends State<_ScaleFeedbackButton> {
  bool _isPressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(scale: _isPressed ? 0.98 : 1.0, duration: const Duration(milliseconds: 100), child: widget.child),
    );
  }
}
