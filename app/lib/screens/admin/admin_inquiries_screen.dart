import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:mjc_in_one/screens/admin/admin_auth_service.dart";
import "package:mjc_in_one/services/admin_moderation_service.dart";
import "package:mjc_in_one/utils/snack_bar_utils.dart";

/// 사용자가 보낸 개발자 문의를 관리하는 화면.
class AdminInquiriesScreen extends StatefulWidget {
  const AdminInquiriesScreen({super.key});

  @override
  State<AdminInquiriesScreen> createState() => _AdminInquiriesScreenState();
}

class _AdminInquiriesScreenState extends State<AdminInquiriesScreen> {
  final AdminModerationService _svc = AdminModerationService();
  String _statusFilter = "open";

  Query<Map<String, dynamic>> _query() {
    return _svc.inquiryQuery(statusFilter: _statusFilter);
  }

  Future<void> _setStatus(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String status,
  ) async {
    final user = AdminAuthService.instance.currentUser;
    if (user == null) return;
    try {
      await _svc.setInquiryStatus(
        ref: doc.reference,
        status: status,
        resolverUid: user.uid,
      );
    } catch (e) {
      debugPrint("admin set status error: $e");
      if (!mounted) return;
      SnackBarUtils.showUnique(
        context,
        key: "admin_inquiry_status_failed",
        snackBar: SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("처리 실패: $e"),
        ),
      );
    }
  }

  Future<void> _saveMemo(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String memo,
  ) async {
    try {
      await _svc.saveInquiryMemo(ref: doc.reference, memo: memo);
    } catch (e) {
      debugPrint("admin memo save error: $e");
    }
  }

  Future<void> _delete(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("문의 삭제"),
        content: const Text(
          "이 문의를 Firestore에서 완전히 삭제합니다.\n되돌릴 수 없습니다.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("삭제"),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.deleteInquiry(ref: doc.reference);
      if (!mounted) return;
      SnackBarUtils.showUnique(
        context,
        key: "admin_inquiry_deleted_${doc.id}",
        snackBar: const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("문의를 삭제했습니다."),
        ),
      );
    } catch (e) {
      debugPrint("admin delete inquiry error: $e");
      if (!mounted) return;
      SnackBarUtils.showUnique(
        context,
        key: "admin_delete_inquiry_failed_${doc.id}",
        snackBar: SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("삭제 실패: $e"),
        ),
      );
    }
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "문의함",
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: "open", label: Text("처리 대기")),
                    ButtonSegment(value: "resolved", label: Text("처리 완료")),
                    ButtonSegment(value: "ignored", label: Text("무시")),
                    ButtonSegment(value: "all", label: Text("전체")),
                  ],
                  selected: {_statusFilter},
                  onSelectionChanged: (s) =>
                      setState(() => _statusFilter = s.first),
                ),
              ),
            ],
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
                      "문의를 불러오지 못했습니다.\n${snap.error}",
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
                    child: Text("표시할 문의가 없습니다."),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _InquiryRow(
                  doc: docs[i],
                  onResolve: () => _setStatus(docs[i], "resolved"),
                  onIgnore: () => _setStatus(docs[i], "ignored"),
                  onReopen: () => _setStatus(docs[i], "open"),
                  onDelete: () => _delete(docs[i]),
                  onSaveMemo: (memo) => _saveMemo(docs[i], memo),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InquiryRow extends StatefulWidget {
  const _InquiryRow({
    required this.doc,
    required this.onResolve,
    required this.onIgnore,
    required this.onReopen,
    required this.onDelete,
    required this.onSaveMemo,
  });

  final DocumentSnapshot<Map<String, dynamic>> doc;
  final Future<void> Function() onResolve;
  final Future<void> Function() onIgnore;
  final Future<void> Function() onReopen;
  final Future<void> Function() onDelete;
  final Future<void> Function(String memo) onSaveMemo;

  @override
  State<_InquiryRow> createState() => _InquiryRowState();
}

class _InquiryRowState extends State<_InquiryRow> {
  late TextEditingController _memoCtrl;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    final data = widget.doc.data() ?? <String, dynamic>{};
    _memoCtrl = TextEditingController(
      text: (data["admin_memo"] as String?) ?? "",
    );
  }

  @override
  void dispose() {
    _memoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final data = widget.doc.data() ?? <String, dynamic>{};
    final String typeLabel = (data["type_label"] as String?) ??
        (data["type"] as String?) ??
        "기타";
    final String message = (data["message"] as String?) ?? "";
    final String contact = (data["contact"] as String?) ?? "";
    final String status = (data["status"] as String?) ?? "open";
    final ts = data["created_at"];
    final DateTime? createdAt = ts is Timestamp ? ts.toDate() : null;
    final di = data["device_info"] as Map<String, dynamic>?;
    final String platform = (di?["platform"] as String?) ?? "";

    final Color statusColor = switch (status) {
      "resolved" => Colors.green,
      "ignored" => scheme.onSurfaceVariant,
      _ => scheme.primary,
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
                child: Text(typeLabel, style: theme.textTheme.labelSmall),
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
          Text(
            _expanded
                ? message
                : (message.length > 240
                    ? "${message.substring(0, 240)}…"
                    : message),
            style: theme.textTheme.bodyMedium,
          ),
          if (message.length > 240)
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 28),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(_expanded ? "접기" : "더 보기"),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            children: [
              if (contact.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.alternate_email,
                        size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    SelectableText(contact, style: theme.textTheme.bodySmall),
                  ],
                ),
              if (platform.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.devices_other,
                        size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(platform, style: theme.textTheme.bodySmall),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _memoCtrl,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: "관리자 메모 (내부)",
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: () => widget.onSaveMemo(_memoCtrl.text.trim()),
                icon: const Icon(Icons.save_outlined, size: 16),
                label: const Text("메모 저장"),
              ),
              if (status != "resolved")
                FilledButton.tonalIcon(
                  onPressed: () => widget.onResolve(),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text("해결 처리"),
                ),
              if (status != "ignored")
                TextButton.icon(
                  onPressed: () => widget.onIgnore(),
                  icon: const Icon(Icons.block, size: 16),
                  label: const Text("무시"),
                ),
              if (status != "open")
                TextButton.icon(
                  onPressed: () => widget.onReopen(),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text("다시 열기"),
                ),
              TextButton.icon(
                onPressed: () => widget.onDelete(),
                icon: Icon(Icons.delete_outline,
                    size: 16, color: scheme.error),
                label: Text("삭제", style: TextStyle(color: scheme.error)),
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
