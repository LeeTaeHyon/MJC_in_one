import "package:flutter/material.dart";
import "package:mjc_in_one/services/notice_filter.dart";
import "package:mjc_in_one/theme/app_theme.dart";

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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.filter.quickQuery);
    _searchFocusNode = FocusNode();
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
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    if (widget.filter.quickQuery.trim().isEmpty) return;
    widget.onQueryChanged("");
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final NoticeFilterState filter = widget.filter;
    final bool filterEnabled = filter.enabled;
    final int hiddenCount = (widget.totalCount - widget.filteredCount).clamp(
      0,
      widget.totalCount,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.horizontalPadding,
        0,
        widget.horizontalPadding,
        10,
      ),
      child: Material(
        color: scheme.surface,
        elevation: filterEnabled ? 1.5 : 0,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
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
                          tooltip: "검색어 지우기",
                          icon: const Icon(Icons.close_rounded),
                          onPressed: _clearSearch,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tokens.cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tokens.cardBorder),
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
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    tooltip: "화면 필터 설정",
                    onPressed: widget.onOpenSettings,
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    "${widget.filteredCount}개 표시됨",
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (filterEnabled && hiddenCount > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      "($hiddenCount개 가려짐)",
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
