import "package:flutter/material.dart";
import "package:mjc_in_one/services/user_data_repository.dart";
import "package:mjc_in_one/utils/bookmark_added_feedback.dart";
import "package:mjc_in_one/widgets/notice_search_result_card.dart";
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
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
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

  @override
  State<_GlobalNoticeSearchSheet> createState() =>
      _GlobalNoticeSearchSheetState();
}

class _GlobalNoticeSearchSheetState extends State<_GlobalNoticeSearchSheet> {
  late final TextEditingController _controller = TextEditingController();
  final Map<String, Set<String>> _pinnedByBoard = {};
  final Map<String, Set<String>> _favoriteByBoard = {};

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

  void _showBookmarkFeedback({required bool adding, required bool wasPinned}) {
    if (!mounted) return;
    if (adding) {
      showBookmarkAddedSnackBar(
        context,
        openPinnedTab: wasPinned,
      );
    } else {
      showBookmarkRemovedSnackBar(
        context,
        wasPinned: wasPinned,
      );
    }
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
    _controller.dispose();
    super.dispose();
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

    final Color surface = Theme.of(context).colorScheme.surface;

    // Scaffold는 72% 높이로만 제한 — 전체 높이를 채우면 하단에 흰 여백이 생깁니다.
    return FractionallySizedBox(
      heightFactor: 0.72,
      alignment: Alignment.bottomCenter,
      child: Scaffold(
        backgroundColor: surface,
        body: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: 12 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: "검색어 입력",
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: "지우기",
                    onPressed: () {
                      _controller.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: widget.accentColor, width: 1.4),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
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
                          final String title =
                              (item["title"] ?? "").toString().trim();
                          final String? boardId = _bookmarksEnabled
                              ? widget.boardIdFor!(item)
                              : null;
                          final String? key = _bookmarksEnabled
                              ? widget.noticeKeyFor!(item)
                              : null;
                          final bool isPinned = boardId != null &&
                              key != null &&
                              (_pinnedByBoard[boardId] ?? const <String>{})
                                  .contains(key);
                          final bool isFavorite = boardId != null &&
                              key != null &&
                              (_favoriteByBoard[boardId] ?? const <String>{})
                                  .contains(key);
                          return NoticeSearchResultCard(
                            title: title,
                            chipLabel: widget.chipFor(item),
                            aiTags: _parseAiTagsForSearchCard(item),
                            dateLine: widget.dateFor(item),
                            accentColor: widget.accentColor,
                            trailing: widget.trailingFor?.call(item),
                            isPinned: isPinned,
                            isFavorite: isFavorite,
                            onTogglePinned: boardId != null && key != null
                                ? () => _togglePinned(boardId, key)
                                : null,
                            onToggleFavorite: boardId != null && key != null
                                ? () => _toggleFavorite(boardId, key)
                                : null,
                            onTap: () async {
                              Navigator.of(context).pop();
                              await widget.openItem(item);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
