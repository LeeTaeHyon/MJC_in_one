import "dart:io" show Platform;

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:mio_notice/services/developer_support_service.dart";
import "package:mio_notice/utils/snack_bar_utils.dart";
import "package:shared_preferences/shared_preferences.dart";

/// 사용자가 개발자에게 보내는 문의 유형.
enum InquiryType {
  bug("bug", "버그 신고"),
  suggestion("suggestion", "기능 제안"),
  general("general", "일반 문의"),
  other("other", "기타");

  final String value;
  final String label;
  const InquiryType(this.value, this.label);
}

const String _kInquiryCooldownKey = "developer_inquiry_last_at";
const Duration _kInquiryCooldown = Duration(seconds: 60);

/// 개발자에게 문의 보내기 화면. 결과는 Firestore `developer_inquiries` 컬렉션에 저장됩니다.
///
/// 기존 mailto 흐름을 대체합니다.
class InquiryScreen extends StatefulWidget {
  const InquiryScreen({super.key});

  @override
  State<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends State<InquiryScreen> {
  final DeveloperSupportService _support = DeveloperSupportService();
  final TextEditingController _messageCtrl = TextEditingController();
  final TextEditingController _contactCtrl = TextEditingController();
  final FocusNode _messageFocus = FocusNode();
  InquiryType _type = InquiryType.general;
  bool _submitting = false;
  bool _showAllLogs = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    _contactCtrl.dispose();
    _messageFocus.dispose();
    super.dispose();
  }

  String _platformLabel() {
    if (kIsWeb) return "web";
    try {
      return Platform.operatingSystem;
    } catch (_) {
      return "unknown";
    }
  }

  Future<bool> _checkCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_kInquiryCooldownKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsedMs = now - lastMs;
    if (elapsedMs < _kInquiryCooldown.inMilliseconds) {
      final remain =
          (_kInquiryCooldown.inMilliseconds - elapsedMs) ~/ 1000 + 1;
      if (mounted) {
        SnackBarUtils.showUnique(
          context,
          key: "inquiry_cooldown",
          snackBar: SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text("문의는 잠시 후 다시 보낼 수 있습니다. ($remain초)"),
          ),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final String msg = _messageCtrl.text.trim();
    if (msg.length < 5) {
      SnackBarUtils.showUnique(
        context,
        key: "inquiry_too_short",
        snackBar: const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("문의 내용을 5자 이상 입력해 주세요."),
        ),
      );
      return;
    }
    if (!await _checkCooldown()) return;

    setState(() => _submitting = true);
    try {
      await _support.submitInquiry(
        type: _type.value,
        typeLabel: _type.label,
        message: msg,
        contact: _contactCtrl.text.trim(),
        platform: _platformLabel(),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _kInquiryCooldownKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      if (!mounted) return;
      SnackBarUtils.showUnique(
        context,
        key: "inquiry_submitted",
        snackBar: const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("문의가 접수되었습니다. 빠르게 확인하겠습니다."),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint("inquiry submit error: $e");
      if (!mounted) return;
      setState(() => _submitting = false);
      SnackBarUtils.showUnique(
        context,
        key: "inquiry_failed",
        snackBar: const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("문의를 보내지 못했습니다. 잠시 후 다시 시도해 주세요."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text(
          "개발자에게 문의",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!kReleaseMode || const bool.fromEnvironment('PREVIEW', defaultValue: false))
                      _buildDevLogSection(context),
                    Text(
                      "어떤 문의를 보내시겠습니까?",
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "보내주신 내용은 관리자 페이지에서 확인 후 답변드립니다.",
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: InquiryType.values.map((t) {
                        final selected = _type == t;
                        return ChoiceChip(
                          label: Text(t.label),
                          selected: selected,
                          onSelected: (v) {
                            if (!v) return;
                            setState(() => _type = t);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "문의 내용",
                      style: theme.textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _messageCtrl,
                      focusNode: _messageFocus,
                      minLines: 5,
                      maxLines: 12,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        hintText:
                            "발생한 상황, 화면, 기대했던 동작 등을 자세히 적어주시면 빠르게 도와드릴 수 있습니다.",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "답변 받을 연락처 (선택)",
                      style: theme.textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _contactCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: "예: 학교 메일 주소",
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                  top: BorderSide(color: scheme.outlineVariant, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _submitting ? "보내는 중" : "문의 보내기",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevLogSection(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bug_report, color: scheme.primary),
              const SizedBox(width: 8),
              const Text(
                "개발 로그 (Test Build)",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _support.streamDevLogs(limit: 10),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text("로그를 불러오지 못했습니다.");
              }
              if (!snapshot.hasData) return const SizedBox();

              final items = snapshot.data!;
              if (items.isEmpty) {
                return const Text("등록된 로그가 없습니다.");
              }

              final displayCount = _showAllLogs ? items.length : (items.isNotEmpty ? 1 : 0);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: displayCount,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final data = items[index];
                      final String title = (data["title"] ?? "제목 없음").toString();
                      final String content = (data["content"] ?? "").toString();
                      final String dateStr = () {
                        final v = data["created_at"];
                        if (v is DateTime) return v.toString().split(".").first;
                        return "";
                      }();

                      return Material(
                        color: isDark
                            ? const Color(0xFF2A2A35)
                            : const Color(0xFFF0F4F8),
                        borderRadius: BorderRadius.circular(14),
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  height: 1.2,
                                ),
                              ),
                              if (content.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  content,
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 13,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                              if (dateStr.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    color: scheme.primary.withValues(alpha: 0.8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  if (items.length > 1) ...[
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _showAllLogs = !_showAllLogs;
                        });
                      },
                      icon: Icon(
                        _showAllLogs ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                      ),
                      label: Text(
                        _showAllLogs
                            ? "접기"
                            : "이전 개발 일지 보기 (${items.length - 1}개 더보기)",
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Divider(color: scheme.outlineVariant),
        ],
      ),
    );
  }
}
