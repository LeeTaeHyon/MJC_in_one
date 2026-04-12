import "package:flutter/material.dart";
import "package:mio_notice/notification_history_prefs.dart";
import "package:mio_notice/theme/app_colors.dart";

/// 푸시 알람 수신 내역을 모아보는 화면입니다.
class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final list = await loadNotificationHistoryNewestFirst();
    if (!mounted) return;
    setState(() {
      _history = list;
      _isLoading = false;
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
