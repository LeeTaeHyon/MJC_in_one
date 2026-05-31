import "package:flutter/material.dart";
import "package:mjc_in_one/services/notice_filter.dart";
import "package:mjc_in_one/theme/app_colors.dart";
import "package:mjc_in_one/theme/app_theme.dart";
import "package:mjc_in_one/utils/mjc_dialog.dart";
import "package:mjc_in_one/widgets/mjc_keyword_capsule.dart";

/// 공지 목록(메인·CTL·MPU 등)에서 설정 화면으로 가지 않고 필터를 조정할 때 사용합니다.
Future<void> showNoticeFilterSheet(
  BuildContext context, {
  required String scopeId,
  required String scopeLabel,
  VoidCallback? onFilterChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (BuildContext ctx) => _NoticeFilterSheetBody(
      scopeId: scopeId,
      scopeLabel: scopeLabel,
      onFilterChanged: onFilterChanged,
    ),
  );
}

class _NoticeFilterSheetBody extends StatefulWidget {
  const _NoticeFilterSheetBody({
    required this.scopeId,
    required this.scopeLabel,
    this.onFilterChanged,
  });

  final String scopeId;
  final String scopeLabel;
  final VoidCallback? onFilterChanged;

  @override
  State<_NoticeFilterSheetBody> createState() => _NoticeFilterSheetBodyState();
}

class _NoticeFilterSheetBodyState extends State<_NoticeFilterSheetBody> {
  bool _loading = true;
  NoticeFilterState _filter = const NoticeFilterState();
  List<String> _includes = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final NoticeFilterState f = await NoticeFilterState.load();
    final bool enabled = await loadScopedNoticeFilterEnabled(widget.scopeId);
    final List<String> includes =
        await loadScopedNoticeFilterIncludes(widget.scopeId);
    if (!mounted) return;
    setState(() {
      _filter = f.copyWith(enabled: enabled);
      _includes = includes;
      _loading = false;
    });
  }

  void _notifyFilterChanged() {
    widget.onFilterChanged?.call();
  }

  Future<void> _setEnabled(bool value) async {
    await saveScopedNoticeFilterEnabled(widget.scopeId, value);
    if (!mounted) return;
    setState(() => _filter = _filter.copyWith(enabled: value));
    _notifyFilterChanged();
  }

  Future<void> _showKeywordDialog() async {
    await showDialog<List<String>>(
      context: context,
      builder: (BuildContext dialogContext) => _KeywordFilterDialog(
        scopeId: widget.scopeId,
        initialIncludes: _includes,
      ),
    );
    if (!mounted) return;
    final List<String> includes =
        await loadScopedNoticeFilterIncludes(widget.scopeId);
    if (!mounted) return;
    setState(() => _includes = includes);
    _notifyFilterChanged();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final bool enabled = _filter.enabled;
    final String includeSummary = _includes.isEmpty
        ? "키워드가 없어서 목록은 그대로 보입니다."
        : "${_includes.length}개 키워드가 포함된 공지만 표시합니다.";

    final double maxH = MediaQuery.sizeOf(context).height * 0.88;
    return Material(
      color: scheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            MediaQuery.paddingOf(context).bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "공지 필터",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: "닫기",
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(
                "적용 범위: ${widget.scopeLabel}",
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("필터 사용"),
                subtitle: Text(
                  enabled
                      ? "현재 화면의 공지 목록에만 키워드 필터를 적용합니다."
                      : "끄면 목록은 필터 없이 표시됩니다.",
                ),
                value: enabled,
                onChanged: _setEnabled,
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState:
                    enabled ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("보고 싶은 키워드 추가/삭제"),
                      subtitle: Text(includeSummary),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _showKeywordDialog,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeywordFilterDialog extends StatefulWidget {
  const _KeywordFilterDialog({
    required this.scopeId,
    required this.initialIncludes,
  });

  final String scopeId;
  final List<String> initialIncludes;

  @override
  State<_KeywordFilterDialog> createState() => _KeywordFilterDialogState();
}

class _KeywordFilterDialogState extends State<_KeywordFilterDialog> {
  late List<String> _includes;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _includes = List<String>.from(widget.initialIncludes);
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addKeyword() async {
    final String text = _controller.text.trim();
    if (text.isEmpty || _includes.contains(text)) {
      return;
    }
    final List<String> next = [..._includes, text];
    await saveScopedNoticeFilterIncludes(widget.scopeId, next);
    if (!mounted) return;
    setState(() {
      _includes = next;
      _controller.clear();
    });
  }

  Future<void> _removeKeyword(String kw) async {
    final List<String> next = _includes.where((e) => e != kw).toList();
    await saveScopedNoticeFilterIncludes(widget.scopeId, next);
    if (!mounted) return;
    setState(() => _includes = next);
  }

  void _close() {
    Navigator.pop(context, _includes);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color fieldBg = isDark
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainerLow;

    return MjcDialogShell(
      centerIcon: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Color(0xFFE3F2FD),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.notifications_active_rounded,
          color: AppColors.primary,
          size: 24,
        ),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "보고 싶은 키워드",
            textAlign: TextAlign.center,
            style: mjcDialogTitleStyle(context),
          ),
          const SizedBox(height: 8),
          Text(
            "키워드가 포함된 공지만 목록에\n보입니다. (선택사항)",
            textAlign: TextAlign.center,
            style: mjcDialogBodyStyle(context),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addKeyword(),
            decoration: InputDecoration(
              hintText: "예: 장학, 수강신청",
              filled: true,
              fillColor: fieldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              suffixIcon: IconButton(
                tooltip: "키워드 추가",
                icon: const Icon(
                  Icons.add_circle_rounded,
                  color: AppColors.primary,
                ),
                onPressed: _addKeyword,
              ),
            ),
          ),
          if (_includes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              "등록된 키워드 (${_includes.length})",
              style: mjcDialogBodyStyle(context).copyWith(
                fontWeight: FontWeight.w700,
                color: mjcDialogTitleColor(context),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _includes.map((String kw) {
                return MjcKeywordCapsule(
                  label: kw,
                  onRemove: () => _removeKeyword(kw),
                );
              }).toList(),
            ),
          ],
        ],
      ),
      actions: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, color: mjcDialogDividerColor(context)),
          SizedBox(
            height: kMjcDialogButtonHeight,
            width: double.infinity,
            child: TextButton(
              onPressed: _close,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize:
                    const Size(double.infinity, kMjcDialogButtonHeight),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
                shape: const RoundedRectangleBorder(),
              ),
              child: const Text(
                "닫기",
                style: TextStyle(
                  fontFamily: kPretendardFontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
