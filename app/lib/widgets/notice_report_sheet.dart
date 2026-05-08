import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:mio_notice/services/notice_report_service.dart";
import "package:mio_notice/utils/snack_bar_utils.dart";
import "package:shared_preferences/shared_preferences.dart";

/// "내용이 이상해요" 신고 사유 카테고리 (Firestore 에 저장되는 값과 라벨).
enum NoticeReportReason {
  summaryWrong("summary_wrong", "요약이 본문과 안 맞아요"),
  bodyTruncated("body_truncated", "본문이 잘려 있어요"),
  bodyMissing("body_missing", "본문이 안 보여요"),
  other("other", "기타");

  final String value;
  final String label;
  const NoticeReportReason(this.value, this.label);
}

String reportLocalKey(String boardId, String postId) =>
    "notice_report_${boardId}_$postId";

Future<bool> hasAlreadyReported(String boardId, String postId) async {
  if (boardId.isEmpty || postId.isEmpty) return false;
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(reportLocalKey(boardId, postId)) ?? false;
}

/// 신고 시트를 띄우고 사용자가 제출했다면 true 를 반환.
Future<bool> showNoticeReportSheet(
  BuildContext context, {
  required String boardId,
  required String postId,
  required String postTitle,
  required String postUrl,
}) async {
  if (boardId.isEmpty || postId.isEmpty) {
    SnackBarUtils.showUnique(
      context,
      key: "notice_report_invalid",
      snackBar: const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text("이 글은 아직 신고할 수 없습니다."),
      ),
    );
    return false;
  }

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetCtx) {
      return _NoticeReportSheetBody(
        boardId: boardId,
        postId: postId,
        postTitle: postTitle,
        postUrl: postUrl,
      );
    },
  );
  return result ?? false;
}

class _NoticeReportSheetBody extends StatefulWidget {
  const _NoticeReportSheetBody({
    required this.boardId,
    required this.postId,
    required this.postTitle,
    required this.postUrl,
  });

  final String boardId;
  final String postId;
  final String postTitle;
  final String postUrl;

  @override
  State<_NoticeReportSheetBody> createState() => _NoticeReportSheetBodyState();
}

class _NoticeReportSheetBodyState extends State<_NoticeReportSheetBody> {
  final NoticeReportService _svc = NoticeReportService();
  NoticeReportReason _reason = NoticeReportReason.summaryWrong;
  final TextEditingController _commentCtrl = TextEditingController();
  bool _alreadyReported = false;
  bool _submitting = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _checkAlreadyReported();
  }

  Future<void> _checkAlreadyReported() async {
    final v = await hasAlreadyReported(widget.boardId, widget.postId);
    if (!mounted) return;
    setState(() {
      _alreadyReported = v;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || _alreadyReported) return;
    setState(() => _submitting = true);
    try {
      await _svc.submitReport(
        boardId: widget.boardId,
        postId: widget.postId,
        postTitle: widget.postTitle,
        postUrl: widget.postUrl,
        reason: _reason.value,
        reasonLabel: _reason.label,
        comment: _commentCtrl.text.trim(),
        platform: _platformLabel(),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        reportLocalKey(widget.boardId, widget.postId),
        true,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      SnackBarUtils.showUnique(
        context,
        key: "notice_report_submitted_${widget.postId}",
        snackBar: const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("신고가 접수되었습니다. 빠르게 확인하겠습니다."),
        ),
      );
    } catch (e) {
      debugPrint("notice_report submit error: $e");
      if (!mounted) return;
      setState(() => _submitting = false);
      SnackBarUtils.showUnique(
        context,
        key: "notice_report_failed",
        snackBar: const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("신고를 보내지 못했습니다. 잠시 후 다시 시도해 주세요."),
        ),
      );
    }
  }

  String _platformLabel() {
    if (kIsWeb) return "web";
    return defaultTargetPlatform.name;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final EdgeInsets viewInsets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.report_outlined, color: scheme.error),
                const SizedBox(width: 8),
                Text(
                  "내용이 이상해요",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "요약이나 본문이 잘못 보일 때 알려주세요. 관리자가 확인 후 조치합니다.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            if (_loaded && _alreadyReported)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: scheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "이미 신고를 접수했습니다. 검토 중이니 잠시만 기다려 주세요.",
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Text(
                "사유",
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: NoticeReportReason.values.map((r) {
                  final selected = _reason == r;
                  return ChoiceChip(
                    label: Text(r.label),
                    selected: selected,
                    onSelected: (v) {
                      if (!v) return;
                      setState(() => _reason = r);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text(
                "추가 설명 (선택)",
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _commentCtrl,
                minLines: 2,
                maxLines: 4,
                maxLength: 200,
                decoration: const InputDecoration(
                  hintText: "어디가 어떻게 이상한지 적어주시면 큰 도움이 됩니다.",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text("닫기"),
                ),
                const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed: (_alreadyReported || _submitting) ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(_submitting ? "보내는 중" : "신고 보내기"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
