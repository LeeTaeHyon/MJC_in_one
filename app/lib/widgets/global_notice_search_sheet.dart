import "package:flutter/material.dart";
import "package:mio_notice/widgets/notice_search_result_card.dart";

Future<void> showGlobalNoticeSearchSheet(
  BuildContext context, {
  required List<Map<String, dynamic>> items,
  required Color accentColor,
  required Future<void> Function(Map<String, dynamic> item) openItem,
  required String Function(Map<String, dynamic> item) chipFor,
  required String Function(Map<String, dynamic> item) dateFor,
  required String Function(Map<String, dynamic> item) searchTextFor,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: _GlobalNoticeSearchSheet(
          items: items,
          accentColor: accentColor,
          openItem: openItem,
          chipFor: chipFor,
          dateFor: dateFor,
          searchTextFor: searchTextFor,
        ),
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
  });

  final List<Map<String, dynamic>> items;
  final Color accentColor;
  final Future<void> Function(Map<String, dynamic> item) openItem;
  final String Function(Map<String, dynamic> item) chipFor;
  final String Function(Map<String, dynamic> item) dateFor;
  final String Function(Map<String, dynamic> item) searchTextFor;

  @override
  State<_GlobalNoticeSearchSheet> createState() =>
      _GlobalNoticeSearchSheetState();
}

class _GlobalNoticeSearchSheetState extends State<_GlobalNoticeSearchSheet> {
  late final TextEditingController _controller = TextEditingController();

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

    final double sheetHeight = MediaQuery.sizeOf(context).height * 0.72;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      child: SizedBox(
        height: sheetHeight,
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
                  borderSide: BorderSide(color: widget.accentColor, width: 1.4),
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
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
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
                        return NoticeSearchResultCard(
                          title: title,
                          chipLabel: widget.chipFor(item),
                          dateLine: widget.dateFor(item),
                          accentColor: widget.accentColor,
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
    );
  }
}

