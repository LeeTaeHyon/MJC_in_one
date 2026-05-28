import "package:flutter/material.dart";
import "package:mjc_in_one/notification_sources.dart";
import "package:mjc_in_one/services/keyword_notification_detail.dart";
import "package:mjc_in_one/services/user_data_repository.dart";
import "package:mjc_in_one/utils/snack_bar_utils.dart";
import "package:shared_preferences/shared_preferences.dart";

/// 푸시 알림용 키워드 등록·편집 화면.
class KeywordNotificationSettingsScreen extends StatefulWidget {
  const KeywordNotificationSettingsScreen({super.key});

  static const int maxKeywords = 30;

  @override
  State<KeywordNotificationSettingsScreen> createState() =>
      _KeywordNotificationSettingsScreenState();
}

class _KeywordNotificationSettingsScreenState
    extends State<KeywordNotificationSettingsScreen> {
  final TextEditingController _inputController = TextEditingController();
  List<String> _keywords = [];
  bool _editMode = false;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _loadKeywords();
    _inputController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _loadKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _keywords = List<String>.from(prefs.getStringList("keywords") ?? []);
    });
  }

  Future<void> _persistKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList("keywords", _keywords);
    try {
      await UserDataRepository.instance.updateKeywords(_keywords);
    } catch (_) {}
  }

  Future<void> _addKeyword() async {
    final String text = _inputController.text.trim();
    if (text.isEmpty) return;
    if (_keywords.length >= KeywordNotificationSettingsScreen.maxKeywords) {
      if (!mounted) return;
      SnackBarUtils.showUnique(
        context,
        key: "keyword_max",
        snackBar: const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("키워드는 최대 30개까지 등록할 수 있어요."),
        ),
      );
      return;
    }
    if (_keywords.contains(text)) {
      if (!mounted) return;
      SnackBarUtils.showUnique(
        context,
        key: "keyword_dup",
        snackBar: const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("이미 등록된 키워드입니다."),
        ),
      );
      return;
    }
    setState(() {
      _keywords = [..._keywords, text];
    });
    _inputController.clear();
    await _persistKeywords();
  }

  Future<void> _removeKeyword(String kw) async {
    setState(() {
      _keywords = _keywords.where((k) => k != kw).toList();
      _selected.remove(kw);
    });
    await removeKeywordNotificationDetail(kw);
    await _persistKeywords();
  }

  Future<void> _removeSelected() async {
    if (_selected.isEmpty) return;
    final List<String> removed = _selected.toList();
    setState(() {
      _keywords = _keywords.where((k) => !_selected.contains(k)).toList();
      _selected.clear();
    });
    for (final String kw in removed) {
      await removeKeywordNotificationDetail(kw);
    }
    await _persistKeywords();
    if (_keywords.isEmpty) {
      setState(() => _editMode = false);
    }
  }

  void _toggleEditMode() {
    setState(() {
      _editMode = !_editMode;
      _selected.clear();
    });
  }

  void _onKeywordSettings(String keyword) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      builder: (ctx) => _KeywordDetailSheet(keyword: keyword),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool canRegister = _inputController.text.trim().isNotEmpty &&
        _keywords.length < KeywordNotificationSettingsScreen.maxKeywords;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(
          "키워드 알림 설정 (${_keywords.length}/${KeywordNotificationSettingsScreen.maxKeywords})",
        ),
        actions: [
          if (_editMode && _selected.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: "선택 삭제",
              onPressed: _removeSelected,
            ),
          TextButton(
            onPressed: _toggleEditMode,
            child: Text(_editMode ? "완료" : "편집"),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _inputController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addKeyword(),
              decoration: InputDecoration(
                hintText: "알림 받을 키워드를 입력해주세요.",
                filled: true,
                fillColor: scheme.surfaceContainerLow,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
                  child: TextButton(
                    onPressed: canRegister ? _addKeyword : null,
                    child: Text(
                      "등록",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: canRegister
                            ? scheme.primary
                            : scheme.onSurfaceVariant
                                .withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 64,
                  minHeight: 48,
                ),
              ),
            ),
          ),
          Expanded(
            child: _keywords.isEmpty
                ? Center(
                    child: Text(
                      "등록된 키워드가 없습니다.",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: _keywords.length,
                    itemBuilder: (context, index) {
                      final String kw = _keywords[index];
                      if (_editMode) {
                        final bool sel = _selected.contains(kw);
                        return CheckboxListTile(
                          value: sel,
                          onChanged: (v) {
                            setState(() {
                              if (v ?? false) {
                                _selected.add(kw);
                              } else {
                                _selected.remove(kw);
                              }
                            });
                          },
                          title: Text(
                            kw,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                        );
                      }
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        title: Text(
                          kw,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.tune_rounded,
                                color: scheme.onSurface.withValues(alpha: 0.55),
                              ),
                              tooltip: "세부 설정",
                              onPressed: () => _onKeywordSettings(kw),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: scheme.onSurfaceVariant,
                              ),
                              tooltip: "삭제",
                              onPressed: () => _removeKeyword(kw),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _KeywordDetailSheet extends StatefulWidget {
  const _KeywordDetailSheet({required this.keyword});

  final String keyword;

  static const int maxExcludeKeywords = 10;

  @override
  State<_KeywordDetailSheet> createState() => _KeywordDetailSheetState();
}

class _KeywordDetailSheetState extends State<_KeywordDetailSheet> {
  final TextEditingController _excludeInput = TextEditingController();

  bool _loading = true;
  List<String> _selectedSourceIds = [];
  List<String> _excludeKeywords = [];

  @override
  void initState() {
    super.initState();
    _excludeInput.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _excludeInput.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final KeywordNotificationDetail detail =
        await loadKeywordNotificationDetail(widget.keyword);
    if (!mounted) return;
    setState(() {
      _selectedSourceIds = detail.sources
          .where(kNotificationSourceIds.contains)
          .toList();
      _excludeKeywords = List<String>.from(detail.excludeKeywords);
      _loading = false;
    });
  }

  Future<void> _save() async {
    await saveKeywordNotificationDetail(
      widget.keyword,
      KeywordNotificationDetail(
        sources: _selectedSourceIds,
        excludeKeywords: _excludeKeywords,
      ),
    );
    try {
      await UserDataRepository.instance.updateKeywordNotificationDetails();
    } catch (_) {}
  }

  Future<void> _toggleSource(String label, bool selected) async {
    final String id = notificationSourceIdFromChipLabel(label);
    if (id.isEmpty) return;
    setState(() {
      if (selected) {
        if (!_selectedSourceIds.contains(id)) {
          _selectedSourceIds = [..._selectedSourceIds, id];
        }
      } else {
        _selectedSourceIds =
            _selectedSourceIds.where((s) => s != id).toList();
      }
    });
    await _save();
  }

  List<String> _selectedSourceChipLabels() {
    return kNotificationSourceChipLabels
        .where((label) =>
            _selectedSourceIds.contains(notificationSourceIdFromChipLabel(label)))
        .toList();
  }

  Future<void> _addExcludeKeyword() async {
    final String text = _excludeInput.text.trim();
    if (text.isEmpty) return;
    if (_excludeKeywords.contains(text)) {
      if (!mounted) return;
      SnackBarUtils.showUnique(
        context,
        key: "keyword_exclude_dup",
        snackBar: const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("이미 등록된 제외 키워드입니다."),
        ),
      );
      return;
    }
    if (_excludeKeywords.length >= _KeywordDetailSheet.maxExcludeKeywords) {
      if (!mounted) return;
      SnackBarUtils.showUnique(
        context,
        key: "keyword_exclude_max",
        snackBar: const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            "제외 키워드는 최대 10개까지 등록할 수 있어요.",
          ),
        ),
      );
      return;
    }
    setState(() {
      _excludeKeywords = [..._excludeKeywords, text];
    });
    _excludeInput.clear();
    await _save();
  }

  Future<void> _removeExcludeKeyword(String kw) async {
    setState(() {
      _excludeKeywords = _excludeKeywords.where((k) => k != kw).toList();
    });
    await _save();
  }

  String get _sourceSummary {
    if (_selectedSourceIds.isEmpty) return "전체 출처";
    if (_selectedSourceIds.length == kNotificationSourceIds.length) {
      return "전체 출처";
    }
    return _selectedSourceIds
        .map(notificationSourceChipLabelFromId)
        .map(notificationSourceDisplayLabel)
        .where((s) => s.isNotEmpty)
        .join(", ");
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    if (_loading) {
      return Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset + 32),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final bool canAddExclude = _excludeInput.text.trim().isNotEmpty &&
        _excludeKeywords.length < _KeywordDetailSheet.maxExcludeKeywords;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        bottomInset + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.keyword,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "이 키워드로 알림을 받을 조건을 설정합니다.",
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "알림 받을 출처",
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "선택하지 않으면 본교 공지·교수학습·역량관리 전체에서 알림을 받습니다. · $_sourceSummary",
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              expandedInsets: EdgeInsets.zero,
              multiSelectionEnabled: true,
              emptySelectionAllowed: true,
              segments: kNotificationSourceChipLabels
                  .map(
                    (String label) => ButtonSegment<String>(
                      value: label,
                      label: Text(
                        notificationSourceDisplayLabel(label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      icon: Icon(notificationSourceDisplayIcon(label)),
                    ),
                  )
                  .toList(),
              selected: _selectedSourceChipLabels().toSet(),
              onSelectionChanged: (Set<String> next) {
                final Set<String> selected = _selectedSourceChipLabels().toSet();
                for (final String label in kNotificationSourceChipLabels) {
                  final bool wasSelected = selected.contains(label);
                  final bool isSelected = next.contains(label);
                  if (wasSelected != isSelected) {
                    _toggleSource(label, isSelected);
                    return;
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "제외 키워드",
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "제목·본문에 아래 단어가 함께 있으면 이 키워드 알림을 보내지 않습니다. (최대 10개)",
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _excludeInput,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (canAddExclude) _addExcludeKeyword();
            },
            decoration: InputDecoration(
              hintText: "예: 모집 마감, 취소",
              filled: true,
              fillColor: scheme.surfaceContainerLow,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: TextButton(
                  onPressed: canAddExclude ? _addExcludeKeyword : null,
                  child: Text(
                    "추가",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: canAddExclude
                          ? scheme.primary
                          : scheme.onSurfaceVariant
                              .withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 56,
                minHeight: 48,
              ),
            ),
          ),
          if (_excludeKeywords.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _excludeKeywords.map((String kw) {
                return InputChip(
                  label: Text(kw),
                  onDeleted: () => _removeExcludeKeyword(kw),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("완료"),
          ),
        ],
      ),
    );
  }
}
