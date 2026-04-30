import "package:flutter/material.dart";
import "package:mio_notice/services/notice_filter.dart";

class NoticeFilterBar extends StatefulWidget {
  const NoticeFilterBar({
    super.key,
    required this.filter,
    required this.keywordCount,
    required this.totalCount,
    required this.filteredCount,
    required this.onQueryChanged,
    required this.onOpenSettings,
    this.accentColor = const Color(0xFF003FB4),
    this.horizontalPadding = 16,
  });

  final NoticeFilterState filter;
  final int keywordCount;
  final int totalCount;
  final int filteredCount;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onOpenSettings;
  final Color accentColor;
  final double horizontalPadding;

  @override
  State<NoticeFilterBar> createState() => _NoticeFilterBarState();
}

class _NoticeFilterBarState extends State<NoticeFilterBar> {
  late final TextEditingController _controller;
  late final FocusNode _searchFocusNode;
  late bool _searchExpanded;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.filter.quickQuery);
    _searchFocusNode = FocusNode();
    _searchExpanded = widget.filter.quickQuery.trim().isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant NoticeFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filter.quickQuery != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.filter.quickQuery,
        selection: TextSelection.collapsed(
          offset: widget.filter.quickQuery.length,
        ),
      );
    }
    if (widget.filter.quickQuery.trim().isNotEmpty && !_searchExpanded) {
      _searchExpanded = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searchExpanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _clearOrCloseSearch() {
    if (widget.filter.quickQuery.trim().isNotEmpty) {
      widget.onQueryChanged("");
      return;
    }
    _searchFocusNode.unfocus();
    setState(() => _searchExpanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final NoticeFilterState filter = widget.filter;
    final bool active = filter.hasAnyRule;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.horizontalPadding,
        0,
        widget.horizontalPadding,
        10,
      ),
      child: Material(
        color: Colors.white,
        elevation: active ? 1.5 : 0,
        shadowColor: Colors.black12,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (_searchExpanded)
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _searchFocusNode,
                        onChanged: widget.onQueryChanged,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: "공지 검색",
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: IconButton(
                            tooltip: filter.quickQuery.trim().isEmpty
                                ? "검색창 닫기"
                                : "검색어 지우기",
                            icon: const Icon(Icons.close_rounded),
                            onPressed: _clearOrCloseSearch,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: widget.accentColor,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    )
                  else ...[
                    IconButton.filledTonal(
                      tooltip: "공지 검색",
                      onPressed: _openSearch,
                      icon: const Icon(Icons.search_rounded),
                    ),
                    const Spacer(),
                  ],
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: "화면 필터 설정",
                    onPressed: widget.onOpenSettings,
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatusChip(
                    label: "표시 ${widget.filteredCount}/${widget.totalCount}",
                    color: widget.accentColor,
                    active: active,
                  ),
                  if (filter.enabled)
                    _StatusChip(
                      label: "화면 필터",
                      color: widget.accentColor,
                      active: true,
                    ),
                  if (filter.requireKeywordHit)
                    _StatusChip(
                      label: "키워드 ${widget.keywordCount}개",
                      color: widget.accentColor,
                      active: true,
                    ),
                  if (filter.excludes.isNotEmpty)
                    _StatusChip(
                      label: "제외 ${filter.excludes.length}개",
                      color: scheme.error,
                      active: true,
                    ),
                  if (!active)
                    Text(
                      "검색어나 필터를 설정하면 목록이 좁혀집니다.",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.active,
  });

  final String label;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.10) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? color.withValues(alpha: 0.30) : Colors.grey.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: TextStyle(
            color: active ? color : Colors.grey.shade700,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
