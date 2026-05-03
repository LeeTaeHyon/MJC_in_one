import "package:flutter/material.dart";
import "package:mio_notice/services/notice_filter.dart";
import "package:mio_notice/services/user_data_repository.dart";
import "package:mio_notice/utils/snack_bar_utils.dart";
import "package:mio_notice/theme/app_theme.dart";

/// 공지 목록(메인·CTL·MPU 등)에서 설정 화면으로 가지 않고 필터를 조정할 때 사용합니다.
Future<void> showNoticeFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext ctx) => const _NoticeFilterSheetBody(),
  );
}

class _NoticeFilterSheetBody extends StatefulWidget {
  const _NoticeFilterSheetBody();

  @override
  State<_NoticeFilterSheetBody> createState() => _NoticeFilterSheetBodyState();
}

class _NoticeFilterSheetBodyState extends State<_NoticeFilterSheetBody> {
  bool _loading = true;
  NoticeFilterState _filter = const NoticeFilterState();
  List<String> _alarmKeywords = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final NoticeFilterState f = await NoticeFilterState.load();
    final List<String> kw = await loadSharedNoticeKeywords();
    if (!mounted) return;
    setState(() {
      _filter = f;
      _alarmKeywords = kw;
      _loading = false;
    });
  }

  EdgeInsets _snackBarMargin(BuildContext context) {
    final double bottom = MediaQuery.paddingOf(context).bottom;
    return EdgeInsets.fromLTRB(16, 0, 16, bottom + 24);
  }

  Future<void> _setFilter(NoticeFilterState next) async {
    final NoticeFilterState safe = next.copyWith(
      sources: next.sources.isEmpty ? kNoticeFilterSourceOptions : next.sources,
      types: next.types.isEmpty ? kNoticeFilterTypeOptions : next.types,
    );
    await safe.save();
    await UserDataRepository.instance.updateNoticeFilter(safe);
    if (!mounted) return;
    setState(() => _filter = safe);
  }

  Future<void> _toggleSource(String source, bool selected) async {
    final Set<String> next = Set<String>.from(_filter.sources);
    if (selected) {
      next.add(source);
    } else {
      next.remove(source);
      if (next.isEmpty) {
        SnackBarUtils.showUnique(
          context,
          key: "sheet_filter_sources_min_one",
          snackBar: SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: _snackBarMargin(context),
            content: const Text("화면 필터 출처는 최소 하나 선택해야 합니다."),
          ),
        );
        return;
      }
    }
    await _setFilter(_filter.copyWith(sources: next.toList()));
  }

  Future<void> _toggleType(String type, bool selected) async {
    final Set<String> next = Set<String>.from(_filter.types);
    if (selected) {
      next.add(type);
    } else {
      next.remove(type);
      if (next.isEmpty) {
        SnackBarUtils.showUnique(
          context,
          key: "sheet_filter_types_min_one",
          snackBar: SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: _snackBarMargin(context),
            content: const Text("화면 필터 유형은 최소 하나 선택해야 합니다."),
          ),
        );
        return;
      }
    }
    await _setFilter(_filter.copyWith(types: next.toList()));
  }

  void _showIncludeKeywordDialog() {
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
                : const [Color(0xFF0D47A1), Color(0xFF1976D2)];

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
                                      if (text.isEmpty || _filter.includes.contains(text)) {
                                        return;
                                      }
                                      final List<String> next = [..._filter.includes, text];
                                      await _setFilter(_filter.copyWith(includes: next));
                                      if (!mounted) return;
                                      controller.clear();
                                      setDialogState(() {});
                                    },
                                  ),
                                ),
                              ),
                              if (_filter.includes.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                Text(
                                  "등록된 키워드 (${_filter.includes.length})",
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
                                  children: _filter.includes.map((String kw) {
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
                                            _filter.includes.where((e) => e != kw).toList();
                                        await _setFilter(_filter.copyWith(includes: next));
                                        if (!mounted) return;
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

  Widget _chipGroup({
    required List<String> options,
    required List<String> selected,
    required void Function(String value, bool on) onToggle,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: options.map((String value) {
        final bool isSelected = selected.contains(value);
        return FilterChip(
          label: Text(value),
          selected: isSelected,
          onSelected: (bool next) => onToggle(value, next),
        );
      }).toList(),
    );
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
    final bool requireKeyword = _filter.requireKeywordHit;
    final String includeSummary = _filter.includes.isEmpty
        ? "등록된 보기 키워드 없음(출처·유형만 적용)"
        : "${_filter.includes.length}개 키워드가 포함된 공지만 표시";

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
                      "공지 목록 필터",
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
                "이 화면의 공지 목록에 바로 적용됩니다. (다른 탭·홈과 동일한 저장값)",
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("공지 화면 필터 사용"),
                subtitle: Text(
                  enabled
                      ? "홈·공지·CTL·MPU 목록에 필터를 적용 중입니다."
                      : "끄면 목록은 필터 없이 표시됩니다.",
                ),
                value: enabled,
                onChanged: (bool value) =>
                    _setFilter(_filter.copyWith(enabled: value)),
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
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("키워드 알람과 동일한 키워드만 표시"),
                      subtitle: Text(
                        _alarmKeywords.isEmpty
                            ? "키워드가 없으면 필터 사용 시 목록이 비어 보일 수 있습니다."
                            : "${_alarmKeywords.length}개 키워드를 화면 필터에도 사용",
                      ),
                      value: requireKeyword,
                      onChanged: (bool value) => _setFilter(
                        _filter.copyWith(requireKeywordHit: value),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 6),
                      child: Text(
                        "출처",
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _chipGroup(
                      options: kNoticeFilterSourceOptions,
                      selected: _filter.sources,
                      onToggle: (v, on) => _toggleSource(v, on),
                    ),
                    const Divider(height: 24),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        "유형",
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _chipGroup(
                      options: kNoticeFilterTypeOptions,
                      selected: _filter.types,
                      onToggle: (v, on) => _toggleType(v, on),
                    ),
                    const Divider(height: 24),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("보고 싶은 키워드 추가/삭제"),
                      subtitle: Text(includeSummary),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _showIncludeKeywordDialog,
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
