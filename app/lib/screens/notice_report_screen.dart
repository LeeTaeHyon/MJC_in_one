import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:mjc_in_one/services/notice_report_service.dart";
import "package:mjc_in_one/utils/mjc_snack_bar.dart";
import "package:mjc_in_one/widgets/main_navigation_scope.dart";
import "package:mjc_in_one/widgets/mjc_floating_pill_cta.dart";
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

  IconData get icon => switch (this) {
        NoticeReportReason.summaryWrong => Icons.summarize_outlined,
        NoticeReportReason.bodyTruncated => Icons.content_cut_outlined,
        NoticeReportReason.bodyMissing => Icons.visibility_off_outlined,
        NoticeReportReason.other => Icons.more_horiz_rounded,
      };
}

String reportLocalKey(String boardId, String postId) =>
    "notice_report_${boardId}_$postId";

Future<bool> hasAlreadyReported(String boardId, String postId) async {
  if (boardId.isEmpty || postId.isEmpty) return false;
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(reportLocalKey(boardId, postId)) ?? false;
}

/// 공지 요약·본문 문제 신고 화면. 결과는 Firestore `notice_reports` 컬렉션에 저장됩니다.
class NoticeReportScreen extends StatefulWidget {
  const NoticeReportScreen({
    super.key,
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
  State<NoticeReportScreen> createState() => _NoticeReportScreenState();
}

class _NoticeReportScreenState extends State<NoticeReportScreen> {
  final NoticeReportService _svc = NoticeReportService();
  final TextEditingController _commentCtrl = TextEditingController();
  NoticeReportReason _reason = NoticeReportReason.summaryWrong;
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

  String _platformLabel() {
    if (kIsWeb) return "web";
    return defaultTargetPlatform.name;
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
      showUniqueMjcSnackBar(
        context,
        key: "notice_report_submitted_${widget.postId}",
        message: "신고가 접수되었습니다. 빠르게 확인하겠습니다.",
        margin: MainNavLayout.snackBarMargin(context),
      );
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint("notice_report submit error: $e");
      if (!mounted) return;
      setState(() => _submitting = false);
      showUniqueMjcSnackBar(
        context,
        key: "notice_report_failed",
        message: "신고를 보내지 못했습니다. 잠시 후 다시 시도해 주세요.",
        margin: MainNavLayout.snackBarMargin(context),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "내용이 이상해요",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: scheme.outline.withValues(alpha: 0.4),
            height: 1.0,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MjcFloatingCtaLayout.scrollBottomPadding(
                context,
                buttonHeight: _loaded && _alreadyReported
                    ? 0
                    : MjcFloatingCtaLayout.compactHeight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildGuideCard(theme, scheme),
                if (_loaded && _alreadyReported) ...[
                  const SizedBox(height: 16),
                  _buildAlreadyReportedCard(theme, scheme),
                ] else if (_loaded) ...[
                  const SizedBox(height: 16),
                  _buildFormCard(theme, scheme),
                ],
              ],
            ),
          ),
          if (_loaded && !_alreadyReported)
            Positioned(
              left: 0,
              right: 0,
              bottom: MjcFloatingCtaLayout.positionedBottom(context),
              child: Center(
                child: MjcFloatingPillCta(
                  variant: MjcFloatingPillCtaVariant.primaryCompact,
                  label: _submitting ? "보내는 중" : "신고 보내기",
                  icon: Icons.send_rounded,
                  onTap: _submit,
                  enabled: !_submitting,
                  loading: _submitting,
                ),
              ),
            ),
        ],
      ),
    );
  }

  BoxDecoration _surfaceCardDecoration(
    ColorScheme scheme, {
    required bool isDark,
  }) {
    return BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.05),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(
    ThemeData theme,
    ColorScheme scheme, {
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(
    ColorScheme scheme, {
    required String hintText,
  }) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: border,
    );
  }

  Widget _buildGuideCard(ThemeData theme, ColorScheme scheme) {
    const List<String> bullets = <String>[
      "접수 후 관리자가 확인해 조치합니다.",
      "요약이나 본문이 잘못 표시될 때 신고해 주세요.",
      "같은 글은 한 번만 신고할 수 있습니다.",
    ];

    final bool isDark = theme.brightness == Brightness.dark;
    final TextStyle bulletStyle = theme.textTheme.bodySmall!.copyWith(
      color: scheme.onSurfaceVariant,
      height: 1.45,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _surfaceCardDecoration(scheme, isDark: isDark).copyWith(
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            theme,
            scheme,
            icon: Icons.info_outline_rounded,
            title: "신고 전 확인해 주세요",
          ),
          const SizedBox(height: 10),
          ...bullets.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      "•",
                      style: bulletStyle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(text, style: bulletStyle)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadyReportedCard(ThemeData theme, ColorScheme scheme) {
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _surfaceCardDecoration(scheme, isDark: isDark),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline_rounded,
              color: scheme.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "이미 신고를 접수했습니다. 검토 중이니 잠시만 기다려 주세요.",
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(ThemeData theme, ColorScheme scheme) {
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _surfaceCardDecoration(scheme, isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            theme,
            scheme,
            icon: Icons.category_outlined,
            title: "신고 사유",
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<NoticeReportReason>(
                value: _reason,
                isExpanded: true,
                icon: Icon(
                  Icons.expand_more_rounded,
                  color: scheme.onSurfaceVariant,
                ),
                borderRadius: BorderRadius.circular(12),
                items: NoticeReportReason.values
                    .map(
                      (reason) => DropdownMenuItem<NoticeReportReason>(
                        value: reason,
                        child: Row(
                          children: [
                            Icon(reason.icon, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(reason.label)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                selectedItemBuilder: (context) => NoticeReportReason.values
                    .map(
                      (reason) => Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Icon(
                              reason.icon,
                              size: 18,
                              color: scheme.onSurface,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                reason.label,
                                style: theme.textTheme.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (NoticeReportReason? value) {
                  if (value == null) return;
                  setState(() => _reason = value);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionTitle(
            theme,
            scheme,
            icon: Icons.edit_outlined,
            title: "추가 설명 (선택)",
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentCtrl,
            minLines: 5,
            maxLines: 12,
            maxLength: 200,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            decoration: _fieldDecoration(
              scheme,
              hintText: "어디가 어떻게 이상한지 적어주시면 큰 도움이 됩니다.",
            ),
          ),
        ],
      ),
    );
  }
}
