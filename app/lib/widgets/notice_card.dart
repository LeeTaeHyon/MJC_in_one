import "package:flutter/material.dart";
import "package:mio_notice/models/notice_model.dart";
import "package:mio_notice/theme/app_colors.dart";
import "package:mio_notice/utils/snack_bar_utils.dart";
import "package:mio_notice/widgets/new_notice_badge.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";

class NoticeCard extends StatefulWidget {
  const NoticeCard({
    super.key,
    required this.notice,
  });

  final Notice notice;

  @override
  State<NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<NoticeCard> {
  bool _hasRead = false;

  @override
  void initState() {
    super.initState();
    _checkIfRead();
  }

  Future<void> _checkIfRead() async {
    final prefs = await SharedPreferences.getInstance();
    final readList = prefs.getStringList("read_notices") ?? [];
    if (readList.contains(widget.notice.id) && mounted) {
      setState(() => _hasRead = true);
    }
  }

  Future<void> _markAsRead() async {
    if (_hasRead) return; // 이미 읽었으면 무시
    if (mounted) {
      setState(() => _hasRead = true);
    }
    final prefs = await SharedPreferences.getInstance();
    final readList = prefs.getStringList("read_notices") ?? [];
    if (!readList.contains(widget.notice.id)) {
      readList.add(widget.notice.id);
      await prefs.setStringList("read_notices", readList);
    }
  }

  bool get _isActuallyNew {
    // 1. 이미 터치하여 읽은 공지면 무조건 제거
    if (_hasRead) return false;
    
    // 2. 관리자가 지정한 isNew 속성이 없으면 안 붙임
    if (!widget.notice.isNew) return false;

    // 3. 업로드된 지 오래되었다면 (예: 14일 초과) NEW 벳지 제거
    try {
      final dateStr = widget.notice.date.replaceAll('.', '-').trim();
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      if (now.difference(date).inDays > 14) {
        return false;
      }
    } catch (_) {
      // 파싱 실패시 무시
    }
    
    return true;
  }

  Future<void> _openUrl(BuildContext context) async {
    _markAsRead(); // 클릭 즉시 읽음 처리하여 뱃지 없앰

    final uri = Uri.tryParse(widget.notice.url);
    if (uri == null || !uri.hasScheme) {
      if (context.mounted) {
        SnackBarUtils.showUnique(
          context,
          key: "notice_invalid_link",
          snackBar: const SnackBar(content: Text("유효하지 않은 링크입니다.")),
        );
      }
      return;
    }
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      SnackBarUtils.showUnique(
        context,
        key: "notice_cannot_open_link",
        snackBar: const SnackBar(content: Text("링크를 열 수 없습니다.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => _openUrl(context),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              widget.notice.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: _hasRead ? FontWeight.w400 : FontWeight.w600,
                color: _hasRead ? Colors.grey.shade600 : Colors.black87,
              ),
            ),
          ),
          if (_isActuallyNew)
            const Padding(
              padding: EdgeInsets.only(left: 8, top: 2),
              child: NewNoticeBadge(color: AppColors.primary),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              widget.notice.date,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
