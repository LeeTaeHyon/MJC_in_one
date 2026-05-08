import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:mio_notice/screens/admin/admin_auth_service.dart";
import "package:mio_notice/screens/admin/admin_post_editor_dialog.dart";
import "package:mio_notice/services/admin_moderation_service.dart";
import "package:mio_notice/utils/snack_bar_utils.dart";
import "package:url_launcher/url_launcher.dart";

/// 사용자가 보낸 공지 신고를 관리하는 화면.
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final AdminModerationService _svc = AdminModerationService();
  String _statusFilter = "open";

  Query<Map<String, dynamic>> _query() {
    return _svc.reportQuery(statusFilter: _statusFilter);
  }

  Future<void> _resolve(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String newStatus,
  ) async {
    final user = AdminAuthService.instance.currentUser;
    if (user == null) return;
    try {
      await _svc.setReportStatus(
        ref: doc.reference,
        status: newStatus,
        resolverUid: user.uid,
      );
    } catch (e) {
      debugPrint("admin resolve error: $e");
      if (!mounted) return;
      SnackBarUtils.showUnique(
        context,
        key: "admin_resolve_failed_${doc.id}",
        snackBar: SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("처리 실패: $e"),
        ),
      );
    }
  }

  Future<void> _flagForResummary(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data() ?? <String, dynamic>{};
    final String boardId = (data["board_id"] as String?) ?? "";
    final String postId = (data["post_id"] as String?) ?? "";
    if (boardId.isEmpty || postId.isEmpty) return;
    try {
      await _svc.flagPostForResummary(boardId: boardId, postId: postId);
      if (!mounted) return;
      SnackBarUtils.showUnique(
        context,
        key: "admin_flag_${doc.id}",
        snackBar: const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("재요약 큐에 등록했습니다. 다음 backfill 실행 시 처리됩니다."),
        ),
      );
    } catch (e) {
      debugPrint("flag for resummary error: $e");
    }
  }

  Future<void> _openEditor(
    DocumentSnapshot<Map<String, dynamic>> reportDoc,
  ) async {
    final data = reportDoc.data() ?? <String, dynamic>{};
    final String boardId = (data["board_id"] as String?) ?? "";
    final String postId = (data["post_id"] as String?) ?? "";
    if (boardId.isEmpty || postId.isEmpty) return;
    DocumentSnapshot<Map<String, dynamic>> postSnap;
    try {
      postSnap = await _svc.getNoticePost(boardId: boardId, postId: postId);
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showUnique(
        context,
        key: "admin_load_post_failed",
        snackBar: SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("게시글 로드 실패: $e"),
        ),
      );
      return;
    }
    if (!postSnap.exists) {
      if (!mounted) return;
      SnackBarUtils.showUnique(
        context,
        key: "admin_post_missing",
        snackBar: const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("원본 공지를 찾을 수 없습니다."),
        ),
      );
      return;
    }
    final pdata = postSnap.data() ?? <String, dynamic>{};
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AdminPostEditorDialog(
        boardId: boardId,
        postId: postId,
        postTitle: (pdata["title"] as String?) ?? "",
        postUrl: (pdata["url"] as String?) ?? "",
        currentSummary: (pdata["summary"] as String?) ?? "",
        currentBody: (pdata["body"] as String?) ?? "",
        relatedReportId: reportDoc.id,
      ),
    );
    if (ok == true && mounted) {
      SnackBarUtils.showUnique(
        context,
        key: "admin_summary_saved",
        snackBar: const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("요약을 저장하고 신고를 처리했습니다."),
        ),
      );
    }
  }

  Future<void> _openOriginal(String url) async {
    if (url.isEmpty) return;
    await launchUrl(Uri.parse(url), webOnlyWindowName: "_blank");
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final Widget segmented = SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: "open", label: Text("처리 대기")),
                  ButtonSegment(value: "resolved", label: Text("처리 완료")),
                  ButtonSegment(value: "ignored", label: Text("무시")),
                  ButtonSegment(value: "all", label: Text("전체")),
                ],
                selected: {_statusFilter},
                onSelectionChanged: (s) =>
                    setState(() => _statusFilter = s.first),
              );
              final Widget scrollFilters = SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: segmented,
              );
              final Widget title = Text(
                "신고함",
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              );
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 10),
                    scrollFilters,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  title,
                  const SizedBox(width: 12),
                  Expanded(child: scrollFilters),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _query().snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      "신고를 불러오지 못했습니다.\n${snap.error}",
                      style: TextStyle(color: scheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text("표시할 신고가 없습니다."),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  return _ReportRow(
                    doc: docs[i],
                    onResolve: () => _resolve(docs[i], "resolved"),
                    onIgnore: () => _resolve(docs[i], "ignored"),
                    onReopen: () => _resolve(docs[i], "open"),
                    onFlagResummary: () => _flagForResummary(docs[i]),
                    onEdit: () => _openEditor(docs[i]),
                    onOpenOriginal: _openOriginal,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.doc,
    required this.onResolve,
    required this.onIgnore,
    required this.onReopen,
    required this.onFlagResummary,
    required this.onEdit,
    required this.onOpenOriginal,
  });

  final DocumentSnapshot<Map<String, dynamic>> doc;
  final Future<void> Function() onResolve;
  final Future<void> Function() onIgnore;
  final Future<void> Function() onReopen;
  final Future<void> Function() onFlagResummary;
  final Future<void> Function() onEdit;
  final Future<void> Function(String url) onOpenOriginal;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final data = doc.data() ?? <String, dynamic>{};
    final String boardId = (data["board_id"] as String?) ?? "";
    final String postId = (data["post_id"] as String?) ?? "";
    final String title = (data["post_title"] as String?) ?? postId;
    final String url = (data["post_url"] as String?) ?? "";
    final String reasonLabel = (data["reason_label"] as String?) ??
        (data["reason"] as String?) ??
        "사유 없음";
    final String comment = (data["comment"] as String?) ?? "";
    final String platform = (data["platform"] as String?) ?? "";
    final String status = (data["status"] as String?) ?? "open";
    final ts = data["created_at"];
    final DateTime? createdAt =
        ts is Timestamp ? ts.toDate() : null;

    final Color statusColor = switch (status) {
      "resolved" => Colors.green,
      "ignored" => scheme.onSurfaceVariant,
      _ => scheme.error,
    };
    final String statusLabel = switch (status) {
      "resolved" => "처리 완료",
      "ignored" => "무시",
      _ => "처리 대기",
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  boardId,
                  style: theme.textTheme.labelSmall,
                ),
              ),
              if (createdAt != null)
                Text(
                  _fmt(createdAt),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: url.isEmpty ? null : () => onOpenOriginal(url),
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                decoration: url.isEmpty ? null : TextDecoration.underline,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.flag_outlined, size: 14, color: scheme.error),
              const SizedBox(width: 4),
              Text(
                reasonLabel,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
              if (platform.isNotEmpty) ...[
                const SizedBox(width: 12),
                Icon(Icons.devices_other,
                    size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(platform, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(comment, style: theme.textTheme.bodyMedium),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => onEdit(),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text("요약 수정"),
              ),
              OutlinedButton.icon(
                onPressed: () => onFlagResummary(),
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text("재요약 플래그"),
              ),
              if (status != "resolved")
                TextButton.icon(
                  onPressed: () => onResolve(),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text("해결 처리"),
                ),
              if (status != "ignored")
                TextButton.icon(
                  onPressed: () => onIgnore(),
                  icon: const Icon(Icons.block, size: 16),
                  label: const Text("무시"),
                ),
              if (status != "open")
                TextButton.icon(
                  onPressed: () => onReopen(),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text("다시 열기"),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime t) {
    String two(int n) => n.toString().padLeft(2, "0");
    return "${t.year}.${two(t.month)}.${two(t.day)} ${two(t.hour)}:${two(t.minute)}";
  }
}
