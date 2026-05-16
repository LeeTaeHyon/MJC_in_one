import "package:flutter/material.dart";
import "package:mjc_in_one/screens/admin/admin_auth_service.dart";
import "package:mjc_in_one/services/admin_moderation_service.dart";
import "package:mjc_in_one/utils/snack_bar_utils.dart";

/// 관리자 페이지에서 신고된 공지의 요약을 인라인 편집하기 위한 다이얼로그.
///
/// 저장 시:
///   - posts.summary, summary_version="manual", summary_generated_at, needs_resummary=false
///   - reportRef 가 있으면 status=resolved, resolved_by=uid, resolved_at=now
class AdminPostEditorDialog extends StatefulWidget {
  const AdminPostEditorDialog({
    super.key,
    required this.boardId,
    required this.postId,
    required this.postTitle,
    required this.postUrl,
    required this.currentSummary,
    required this.currentBody,
    this.relatedReportId,
  });

  final String boardId;
  final String postId;
  final String postTitle;
  final String postUrl;
  final String currentSummary;
  final String currentBody;

  /// 함께 resolve 처리할 신고 ID (있을 때만).
  final String? relatedReportId;

  @override
  State<AdminPostEditorDialog> createState() => _AdminPostEditorDialogState();
}

class _AdminPostEditorDialogState extends State<AdminPostEditorDialog> {
  final AdminModerationService _svc = AdminModerationService();
  late final TextEditingController _summaryCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _summaryCtrl = TextEditingController(text: widget.currentSummary);
  }

  @override
  void dispose() {
    _summaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final user = AdminAuthService.instance.currentUser;
    if (user == null) {
      SnackBarUtils.showUnique(
        context,
        key: "admin_save_no_auth",
        snackBar: const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("로그인이 필요합니다."),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _svc.saveManualSummary(
        boardId: widget.boardId,
        postId: widget.postId,
        summary: _summaryCtrl.text.trim(),
        editorUid: user.uid,
        relatedReportId: widget.relatedReportId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint("admin save summary error: $e");
      if (!mounted) return;
      setState(() => _saving = false);
      SnackBarUtils.showUnique(
        context,
        key: "admin_save_failed",
        snackBar: SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("저장 실패: $e"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "요약 직접 수정",
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                widget.postTitle,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Text(
                "요약",
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _summaryCtrl,
                minLines: 3,
                maxLines: 6,
                maxLength: 600,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "사용자에게 보여줄 요약",
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "본문 (참고용)",
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 240),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    widget.currentBody.isEmpty
                        ? "(본문 없음)"
                        : widget.currentBody,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(false),
                    child: const Text("취소"),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(_saving ? "저장 중" : "저장"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
