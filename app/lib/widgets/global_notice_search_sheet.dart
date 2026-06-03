import "dart:async";

import "package:flutter/material.dart";
import "package:mjc_in_one/services/user_data_repository.dart";
import "package:mjc_in_one/utils/bookmark_added_feedback.dart";
import "package:mjc_in_one/utils/mjc_snack_bar.dart";
import "package:mjc_in_one/widgets/mjc_notice_list_item.dart";
import "package:shared_preferences/shared_preferences.dart";

List<String> _parseAiTagsForSearchCard(Map<String, dynamic> data) {
  final Object? v = data["ai_tags"];
  if (v is! List) return const <String>[];
  return v
      .map((e) => e.toString().trim())
      .where((s) => s.isNotEmpty)
      .take(2)
      .toList();
}

Future<void> showGlobalNoticeSearchSheet(
  BuildContext context, {
  required List<Map<String, dynamic>> items,
  required Color accentColor,
  required Future<void> Function(Map<String, dynamic> item) openItem,
  required String Function(Map<String, dynamic> item) chipFor,
  required String Function(Map<String, dynamic> item) dateFor,
  required String Function(Map<String, dynamic> item) searchTextFor,
  String Function(Map<String, dynamic> item)? boardIdFor,
  String Function(Map<String, dynamic> item)? noticeKeyFor,
  Widget Function(Map<String, dynamic> item)? trailingFor,
  bool secondaryLabelsOnNewLine = false,
  String title = "공지 검색",
  String? scopeLabel,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      return _GlobalNoticeSearchSheet(
        items: items,
        accentColor: accentColor,
        openItem: openItem,
        chipFor: chipFor,
        dateFor: dateFor,
        searchTextFor: searchTextFor,
        boardIdFor: boardIdFor,
        noticeKeyFor: noticeKeyFor,
        trailingFor: trailingFor,
        secondaryLabelsOnNewLine: secondaryLabelsOnNewLine,
        title: title,
        scopeLabel: scopeLabel,
      );
    },
  );
}

class _GlobalNoticeSearchSheet extends StatefulWidget {
  const _GlobalNoticeSearchSheet({
    required this.items,
    required this.accentColor,
    required this.openItem,
    required this.chipFor,
    required this.dateFor,
    required this.searchTextFor,
    this.boardIdFor,
    this.noticeKeyFor,
    this.trailingFor,
    this.secondaryLabelsOnNewLine = false,
    this.title = "공지 검색",
    this.scopeLabel,
  });

  final List<Map<String, dynamic>> items;
  final Color accentColor;
  final Future<void> Function(Map<String, dynamic> item) openItem;
  final String Function(Map<String, dynamic> item) chipFor;
  final String Function(Map<String, dynamic> item) dateFor;
  final String Function(Map<String, dynamic> item) searchTextFor;
  final String Function(Map<String, dynamic> item)? boardIdFor;
  final String Function(Map<String, dynamic> item)? noticeKeyFor;
  final Widget Function(Map<String, dynamic> item)? trailingFor;
  final bool secondaryLabelsOnNewLine;
  final String title;
  final String? scopeLabel;

  @override
  State<_GlobalNoticeSearchSheet> createState() =>
      _GlobalNoticeSearchSheetState();
}

class _SheetBookmarkFeedback {
  const _SheetBookmarkFeedback({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
}

class _GlobalNoticeSearchSheetState extends State<_GlobalNoticeSearchSheet> {
  late final TextEditingController _controller = TextEditingController();
  final Map<String, Set<String>> _pinnedByBoard = {};
  final Map<String, Set<String>> _favoriteByBoard = {};
  _SheetBookmarkFeedback? _feedback;
  Timer? _feedbackDismissTimer;

  bool get _bookmarksEnabled =>
      widget.boardIdFor != null && widget.noticeKeyFor != null;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    if (!_bookmarksEnabled) return;
    final prefs = await SharedPreferences.getInstance();
    final Set<String> boardIds = widget.items
        .map((e) => widget.boardIdFor!(e))
        .where((s) => s.isNotEmpty)
        .toSet();
    if (!mounted) return;
    setState(() {
      for (final String boardId in boardIds) {
        _pinnedByBoard[boardId] =
            (prefs.getStringList("pinned_notices_$boardId") ?? []).toSet();
        _favoriteByBoard[boardId] =
            (prefs.getStringList("favorite_notices_$boardId") ?? []).toSet();
      }
    });
  }

  void _clearBookmarkFeedback() {
    _feedbackDismissTimer?.cancel();
    _feedbackDismissTimer = null;
    if (_feedback != null && mounted) {
      setState(() => _feedback = null);
    }
  }

  void _showBookmarkFeedback({required bool adding, required bool wasPinned}) {
    if (!mounted) return;
    _feedbackDismissTimer?.cancel();

    final String message;
    String? actionLabel;
    VoidCallback? onAction;
    if (adding) {
      message = wasPinned ? "고정되었습니다." : "저장되었습니다.";
      actionLabel = "마이페이지에서 확인";
      onAction = () {
        _clearBookmarkFeedback();
        Navigator.of(context).pop();
        openMyPageBookmarkTab(context, openPinnedTab: wasPinned);
      };
    } else {
      message =
          wasPinned ? "상단 고정을 해제했습니다." : "즐겨찾기를 해제했습니다.";
    }

    setState(() {
      _feedback = _SheetBookmarkFeedback(
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
      );
    });
    _feedbackDismissTimer = Timer(
      const Duration(milliseconds: 1500),
      _clearBookmarkFeedback,
    );
  }

  Future<void> _togglePinned(String boardId, String key) async {
    final Set<String> cur = _pinnedByBoard[boardId] ?? {};
    final bool adding = !cur.contains(key);
    final Set<String> next = {...cur};
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    if (mounted) {
      setState(() => _pinnedByBoard[boardId] = next);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList("pinned_notices_$boardId", next.toList());
    await UserDataRepository.instance.updateBookmarks(
      boardId,
      pinned: true,
      values: next.toList(),
    );
    _showBookmarkFeedback(adding: adding, wasPinned: true);
  }

  Future<void> _toggleFavorite(String boardId, String key) async {
    final Set<String> cur = _favoriteByBoard[boardId] ?? {};
    final bool adding = !cur.contains(key);
    final Set<String> next = {...cur};
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    if (mounted) {
      setState(() => _favoriteByBoard[boardId] = next);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList("favorite_notices_$boardId", next.toList());
    await UserDataRepository.instance.updateBookmarks(
      boardId,
      pinned: false,
      values: next.toList(),
    );
    _showBookmarkFeedback(adding: adding, wasPinned: false);
  }

  @override
  void dispose() {
    _feedbackDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _buildBookmarkFeedbackBanner(BuildContext context) {
    final _SheetBookmarkFeedback? feedback = _feedback;
    if (feedback == null) return const SizedBox.shrink();

    return Material(
      color: mjcSnackBarBackground(context),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: mjcSnackBarContent(
          message: feedback.message,
          actionLabel: feedback.actionLabel,
          onAction: feedback.onAction,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String q = _controller.text.trim().toLowerCase();
    final List<Map<String, dynamic>> filtered = q.isEmpty
        ? widget.items
        : widget.items.where((e) {
            final String hay =
                widget.searchTextFor(e).toLowerCase().replaceAll("\n", " ");
            return hay.contains(q);
          }).toList();

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color sheetBackground = isDark
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainerLow;
    final Color cardBackground = scheme.surface;
    final Color searchFieldBackground = isDark
        ? scheme.surfaceContainerHighest
        : scheme.surface;
    final EdgeInsets viewInsets = MediaQuery.viewInsetsOf(context);
    final double availableHeight =
        MediaQuery.sizeOf(context).height - viewInsets.bottom;
    final double sheetHeight = availableHeight * 0.72;

    // 바텀시트 안에 Scaffold를 두면 키보드 올라올 때 viewInsets가 이중 적용되어
    // 흰 배경이 화면을 덮습니다. Material + 고정 높이로만 구성합니다.
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Material(
        color: sheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: sheetHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          tooltip: "닫기",
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    if (widget.scopeLabel != null)
                      Text(
                        "검색 범위: ${widget.scopeLabel}",
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: "검색어 입력",
                        filled: true,
                        fillColor: searchFieldBackground,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _controller.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: "지우기",
                                onPressed: () {
                                  _controller.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.clear_rounded),
                              ),
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
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                "검색 결과가 없습니다.",
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                              itemCount: filtered.length,
                              itemBuilder: (context, idx) {
                                final item = filtered[idx];
                                final String rawTitle =
                                    (item["title"] ?? "").toString().trim();
                                final String title = rawTitle.isEmpty
                                    ? "(제목 없음)"
                                    : rawTitle;
                                final String? boardId = _bookmarksEnabled
                                    ? widget.boardIdFor!(item)
                                    : null;
                                final String? key = _bookmarksEnabled
                                    ? widget.noticeKeyFor!(item)
                                    : null;
                                final bool isPinned = boardId != null &&
                                    key != null &&
                                    (_pinnedByBoard[boardId] ??
                                            const <String>{})
                                        .contains(key);
                                final bool isFavorite = boardId != null &&
                                    key != null &&
                                    (_favoriteByBoard[boardId] ??
                                            const <String>{})
                                        .contains(key);
                                return MjcNoticeListItem(
                                  title: title,
                                  primaryLabel: widget.chipFor(item),
                                  secondaryLabels:
                                      _parseAiTagsForSearchCard(item),
                                  secondaryLabelsOnNewLine:
                                      widget.secondaryLabelsOnNewLine,
                                  dateLabel: widget.dateFor(item),
                                  brandColor: widget.accentColor,
                                  surfaceColor: cardBackground,
                                  isRead: false,
                                  isPinned: isPinned,
                                  isFavorite: isFavorite,
                                  showPinFavorite: _bookmarksEnabled,
                                  titleTrailing:
                                      widget.trailingFor?.call(item),
                                  onTap: () async {
                                    Navigator.of(context).pop();
                                    await widget.openItem(item);
                                  },
                                  onTogglePinned: boardId != null && key != null
                                      ? () => _togglePinned(boardId, key)
                                      : () {},
                                  onToggleFavorite:
                                      boardId != null && key != null
                                          ? () => _toggleFavorite(boardId, key)
                                          : () {},
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              if (_feedback != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: _buildBookmarkFeedbackBanner(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
