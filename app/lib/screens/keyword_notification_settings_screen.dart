import "package:flutter/material.dart";
import "package:mio_notice/services/user_data_repository.dart";
import "package:mio_notice/utils/snack_bar_utils.dart";
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
    await _persistKeywords();
  }

  Future<void> _removeSelected() async {
    if (_selected.isEmpty) return;
    setState(() {
      _keywords = _keywords.where((k) => !_selected.contains(k)).toList();
      _selected.clear();
    });
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
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            MediaQuery.paddingOf(ctx).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                keyword,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                "키워드별 세부 조건(가격·제외 키워드 등)은 추후 지원 예정입니다.",
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
              ),
            ],
          ),
        );
      },
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
