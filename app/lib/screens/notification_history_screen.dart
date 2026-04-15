import "package:flutter/material.dart";
import "package:flutter/foundation.dart" show kIsWeb;
import "package:mio_notice/notification_history_prefs.dart";
import "package:mio_notice/screens/common_webview_screen.dart";
import "package:mio_notice/theme/app_colors.dart";
import "package:mio_notice/widgets/scroll_to_top_scope.dart";
import "package:url_launcher/url_launcher.dart";

/// 푸시 알람 수신 내역을 모아보는 화면입니다.
class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  ScrollToTopCoordinator? _scrollRouteCoordinator;
  bool _registeredScrollRoute = false;

  String _extractNotificationOpenUrl(Map<String, dynamic> item) {
    final dynamic dataAny = item["data"];
    if (dataAny is Map) {
      final dynamic urlAny = dataAny["url"] ?? dataAny["link"];
      if (urlAny != null) {
        final String url = urlAny.toString().trim();
        if (url.isNotEmpty) return url;
      }
    }
    final dynamic direct = item["url"] ?? item["link"];
    if (direct != null) {
      final String url = direct.toString().trim();
      if (url.isNotEmpty) return url;
    }
    return "";
  }

  Future<void> _openNoticeFromHistoryItem(Map<String, dynamic> item) async {
    final String openUrl = _extractNotificationOpenUrl(item);
    if (openUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("이 알림에는 이동할 공지 링크가 없습니다.")),
      );
      return;
    }

    await markNotificationHistoryItemRead(item);
    final String title = (item["title"] ?? "공지사항").toString();

    if (kIsWeb) {
      await launchUrl(Uri.parse(openUrl), webOnlyWindowName: "_blank");
      return;
    }
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CommonWebViewScreen(url: openUrl, title: title),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onHistoryScroll);
    _loadHistory();
  }

  void _onHistoryScroll() {
    if (!mounted) return;
    _scrollRouteCoordinator?.reportRouteScroll(
      _scrollController.offset,
      ScrollFabMetrics.viewportHeightInScrollListener(_scrollController),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_registeredScrollRoute) return;
    final ScrollToTopCoordinator? c = ScrollToTopScope.maybeOf(context);
    if (c != null) {
      _scrollRouteCoordinator = c;
      c.pushRouteHandler(_scrollContentToTop);
      _registeredScrollRoute = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        c.reportRouteScroll(
          _scrollController.offset,
          ScrollFabMetrics.viewportHeightForThreshold(_scrollController, context),
        );
      });
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
    _scrollController.removeListener(_onHistoryScroll);
    if (_registeredScrollRoute) {
      _scrollRouteCoordinator?.popRouteHandler();
    }
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final list = await loadNotificationHistoryNewestFirst();
    if (!mounted) return;
    setState(() {
      _history = list;
      _isLoading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollRouteCoordinator?.reportRouteScroll(
        _scrollController.offset,
        ScrollFabMetrics.viewportHeightForThreshold(_scrollController, context),
      );
    });
  }

  Future<void> _clearHistory() async {
    await clearNotificationHistory();
    if (!mounted) return;
    setState(() {
      _history = [];
    });
  }

  Future<void> _removeOneAt(int newestFirstIndex) async {
    await removeNotificationHistoryAtNewestFirstIndex(newestFirstIndex);
    if (!mounted) return;
    await _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          "알림 내역",
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("알림 삭제"),
                    content: const Text("모든 알림 내역을 지울까요?"),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소")),
                      TextButton(
                        onPressed: () {
                          _clearHistory();
                          Navigator.pop(context);
                        },
                        child: const Text("지우기", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _history.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.iconBackdrop(AppColors.primary),
                        child: const Icon(Icons.notifications, color: AppColors.primary, size: 20),
                      ),
                      title: Text(
                        item["title"] ?? "새로운 알림",
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          if (item["body"] != null) Text(item["body"]),
                          const SizedBox(height: 4),
                          Text(
                            item["received_at"] ?? "",
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.close_rounded, color: Colors.grey.shade500),
                        tooltip: "이 알림 삭제",
                        onPressed: () => _removeOneAt(index),
                      ),
                      onTap: () => _openNoticeFromHistoryItem(item),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("수신된 알림이 없습니다.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
