import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:mjc_in_one/screens/common_webview_screen.dart";
import "package:mjc_in_one/theme/app_theme.dart";
import "package:mjc_in_one/widgets/notice_report_sheet.dart";
import "package:share_plus/share_plus.dart";
import "package:url_launcher/url_launcher.dart";

/// 공지 상세(요약 미리보기) 화면.
///
/// 입력은 NoticeManager 가 들고 다니는 풀 맵 (`Map<String, dynamic>`).
/// 본문/요약 필드(`body`, `summary`, `summary_version`)는 누락 가능 — placeholder 처리.
///
/// 하단 CTA "본문 확인" 으로 기존 [CommonWebViewScreen] 또는 새 탭 열기 동작 호출.
class NoticeDetailScreen extends StatefulWidget {
  const NoticeDetailScreen({
    super.key,
    required this.notice,
    required this.boardId,
    this.isPinned = false,
    this.isFavorite = false,
    this.onTogglePinned,
    this.onToggleFavorite,
  });

  /// Firestore `notices/{boardId}/posts/{id}` 문서를 그대로 받습니다.
  final Map<String, dynamic> notice;
  final String boardId;

  final bool isPinned;
  final bool isFavorite;
  final VoidCallback? onTogglePinned;
  final VoidCallback? onToggleFavorite;

  @override
  State<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends State<NoticeDetailScreen> {
  late bool _isPinned;
  late bool _isFavorite;

  String get _id => (widget.notice["id"] as String?) ?? "";
  String get _title {
    final Object? raw = widget.notice["title"];
    if (raw == null) return "공지사항";
    final String s = raw.toString().trim();
    return s.isEmpty ? "공지사항" : s;
  }
  String get _date => (widget.notice["date"] as String?) ?? "";
  String get _category => (widget.notice["category"] as String?) ?? "공지";
  String get _source => (widget.notice["source"] as String?) ?? "";
  String get _url => (widget.notice["url"] as String?) ?? "";
  String get _summary => (widget.notice["summary"] as String?) ?? "";
  String get _body => (widget.notice["body"] as String?) ?? "";
  String get _summaryVersion =>
      (widget.notice["summary_version"] as String?) ?? "";

  List<String> get _aiTags {
    final v = widget.notice["ai_tags"];
    if (v is! List) return const <String>[];
    return v
        .map((e) => e.toString())
        .where((s) => s.trim().isNotEmpty)
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _isPinned = widget.isPinned;
    _isFavorite = widget.isFavorite;
  }

  Future<void> _openOriginal() async {
    if (_url.isEmpty) return;
    if (kIsWeb) {
      await launchUrl(Uri.parse(_url), webOnlyWindowName: "_blank");
      return;
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CommonWebViewScreen(url: _url, title: _title),
      ),
    );
  }

  Future<void> _shareLink() async {
    if (_url.isEmpty) return;
    await Share.share("$_title\n$_url");
  }

  Future<void> _showReportSheet() async {
    if (_id.isEmpty || widget.boardId.isEmpty) return;
    await showNoticeReportSheet(
      context,
      boardId: widget.boardId,
      postId: _id,
      postTitle: _title,
      postUrl: _url,
    );
  }

  String _summaryStatusLabel() {
    switch (_summaryVersion) {
      case "lmstudio-v1":
        return "AI 요약";
      case "manual":
        return "관리자 검수 요약";
      case "heuristic-v1":
        return "자동 추출 요약";
      default:
        return _summary.isEmpty ? "요약 준비 중" : "요약";
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final MjcSurfaceTokens tokens = theme.extension<MjcSurfaceTokens>()!;
    final bool hasUrl = _url.isNotEmpty;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "공지 상세",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "내용이 이상해요",
            icon: const Icon(Icons.report_outlined),
            onPressed: _showReportSheet,
          ),
          IconButton(
            tooltip: _isPinned ? "고정 해제" : "상단 고정",
            icon: Icon(
              _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              color: _isPinned ? const Color(0xFFE53935) : null,
            ),
            onPressed: () {
              setState(() => _isPinned = !_isPinned);
              widget.onTogglePinned?.call();
            },
          ),
          IconButton(
            tooltip: _isFavorite ? "즐겨찾기 해제" : "즐겨찾기",
            icon: Icon(
              _isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: _isFavorite ? const Color(0xFFFFC107) : null,
            ),
            onPressed: () {
              setState(() => _isFavorite = !_isFavorite);
              widget.onToggleFavorite?.call();
            },
          ),
          if (hasUrl)
            IconButton(
              tooltip: "공유",
              icon: const Icon(Icons.share_outlined),
              onPressed: _shareLink,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: scheme.outline.withValues(alpha: 0.4),
            height: 1.0,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                _buildHeaderCard(theme, scheme, tokens),
                const SizedBox(height: 16),
                _buildSummaryCard(theme, scheme),
                if (_body.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildBodyPreviewCard(theme, scheme),
                ],
              ],
            ),
          ),
          _buildBottomCta(theme, scheme),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(
    ThemeData theme,
    ColorScheme scheme,
    MjcSurfaceTokens tokens,
  ) {
    final List<String> tags = _aiTags;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color chipBg =
        tokens.sourceMjc.withValues(alpha: isDark ? 0.18 : 0.12);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _category,
                  style: TextStyle(
                    color: tokens.sourceMjc,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...tags.map(
                (t) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest
                        .withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Text(
                    t,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 리스트에서는 maxLines로 잘리므로 상세(요약) 화면에서는 줄바꿈으로 전체 제목 표시.
          Text(
            _title,
            softWrap: true,
            overflow: TextOverflow.visible,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                _date,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (_source.isNotEmpty) ...[
                const SizedBox(width: 12),
                Icon(Icons.source_outlined,
                    size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  _source,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme, ColorScheme scheme) {
    final bool hasSummary = _summary.trim().isNotEmpty;
    final bool isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary.withValues(alpha: isDark ? 0.25 : 0.12),
            scheme.primary.withValues(alpha: isDark ? 0.05 : 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: scheme.primary)
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 1.seconds)
                  .shimmer(duration: 2.seconds, color: Colors.white.withValues(alpha: 0.5)),
              const SizedBox(width: 6),
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    scheme.primary,
                    isDark ? const Color(0xFFD500F9) : const Color(0xFF9C27B0),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Text(
                  _summaryStatusLabel(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _showReportSheet,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 32),
                  visualDensity: VisualDensity.compact,
                ),
                icon: Icon(Icons.flag_outlined,
                    size: 16, color: scheme.error),
                label: Text(
                  "내용이 이상해요",
                  style: TextStyle(
                    color: scheme.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (hasSummary)
            Text(
              _summary,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
            )
          else
            Text(
              "아직 요약이 준비되지 않았습니다. 본문 확인을 눌러 원문을 확인해 주세요.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBodyPreviewCard(ThemeData theme, ColorScheme scheme) {
    const int maxChars = 700;
    final String preview =
        _body.length <= maxChars ? _body : "${_body.substring(0, maxChars)}…";
    final bool truncated = _body.length > maxChars;
    final bool isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes_rounded,
                  size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                "본문 미리보기",
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            preview,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
          ),
          if (truncated) ...[
            const SizedBox(height: 8),
            Text(
              "전체 본문은 본문 확인을 눌러 주세요.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomCta(ThemeData theme, ColorScheme scheme) {
    final bool hasUrl = _url.isNotEmpty;
    return SafeArea(
      top: false,
      child: Container(
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
                onPressed: hasUrl ? _openOriginal : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 20),
                label: const Text(
                  "본문 확인",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
