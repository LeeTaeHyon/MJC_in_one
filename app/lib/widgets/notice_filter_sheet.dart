import "package:flutter/material.dart";
import "package:mjc_in_one/services/notice_filter.dart";
import "package:mjc_in_one/theme/app_theme.dart";

/// 공지 목록(메인·CTL·MPU 등)에서 설정 화면으로 가지 않고 필터를 조정할 때 사용합니다.
Future<void> showNoticeFilterSheet(
  BuildContext context, {
  required String scopeId,
  required String scopeLabel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext ctx) => _NoticeFilterSheetBody(
      scopeId: scopeId,
      scopeLabel: scopeLabel,
    ),
  );
}

class _NoticeFilterSheetBody extends StatefulWidget {
  const _NoticeFilterSheetBody({
    required this.scopeId,
    required this.scopeLabel,
  });

  final String scopeId;
  final String scopeLabel;

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

  Future<void> _setEnabled(bool value) async {
    await saveScopedNoticeFilterEnabled(widget.scopeId, value);
    if (!mounted) return;
    setState(() => _filter = _filter.copyWith(enabled: value));
  }

  void _showKeywordDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final ColorScheme scheme = Theme.of(context).colorScheme;
            final bool isDark = Theme.of(context).brightness == Brightness.dark;
            final MjcSurfaceTokens? tokens =
                Theme.of(context).extension<MjcSurfaceTokens>();

            final List<Color> headerGradient = isDark && tokens != null
                ? tokens.dashboardGradients[0]
                : [
                    MjcNoticePalette.mjcHome,
                    MjcNoticePalette.mjcUiLight,
                  ];

            final Color fieldBg = isDark
                ? (tokens?.surfaceContainer.withValues(alpha: 0.65) ?? scheme.surfaceContainerHigh)
                : scheme.surfaceContainerLow;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Material(
                  color: scheme.surface,
                  elevation: isDark ? 2 : 4,
                  shadowColor: Colors.black.withValues(alpha: isDark ? 0.55 : 0.18),
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: headerGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.notifications_active_rounded,
                                  size: 28,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "보고 싶은 키워드",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "키워드가 포함된 공지만 목록에\n보입니다. (선택사항)",
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontSize: 13,
                                        height: 1.35,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: controller,
                                decoration: InputDecoration(
                                  hintText: "예: 장학, 수강신청",
                                  filled: true,
                                  fillColor: fieldBg,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  suffixIcon: IconButton(
                                    icon: Icon(Icons.add_circle_rounded, color: scheme.primary),
                                    onPressed: () async {
                                      final String text = controller.text.trim();
                                      if (text.isEmpty || _includes.contains(text)) {
                                        return;
                                      }
                                      final List<String> next = [..._includes, text];
                                      await saveScopedNoticeFilterIncludes(widget.scopeId, next);
                                      if (!mounted) return;
                                      setState(() => _includes = next);
                                      controller.clear();
                                      setDialogState(() {});
                                    },
                                  ),
                                ),
                              ),
                              if (_includes.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                Text(
                                  "등록된 키워드 (${_includes.length})",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _includes.map((String kw) {
                                    return Chip(
                                      label: Text(kw),
                                      backgroundColor: isDark 
                                          ? fieldBg 
                                          : Colors.white,
                                      side: BorderSide(
                                        color: isDark ? Colors.transparent : scheme.outlineVariant.withValues(alpha: 0.5),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      onDeleted: () async {
                                        final List<String> next =
                                            _includes.where((e) => e != kw).toList();
                                        await saveScopedNoticeFilterIncludes(widget.scopeId, next);
                                        if (!mounted) return;
                                        setState(() => _includes = next);
                                        setDialogState(() {});
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: FilledButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text("닫기"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
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
