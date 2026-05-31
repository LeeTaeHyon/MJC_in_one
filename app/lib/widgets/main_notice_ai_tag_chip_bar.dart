import "package:flutter/material.dart";
import "package:mjc_in_one/theme/app_colors.dart";

/// `test/notice_ai_tags.py`의 ALLOWED_TAGS와 동일 순서(「전체」는 UI 전용).
const List<String> kMainNoticeAiTagFilterChips = <String>[
  "전체",
  "학사/수업",
  "장학/등록금",
  "모집/신청",
  "행사/대회/특강",
  "취업/진로/창업",
  "정책/지원사업/대외홍보",
  "기타",
];

const double kMainNoticeAiTagFilterBarHeight = 52;
const double kMainNoticeAiTagFilterIndicatorHeight = 3;

/// 본교 공지 AI 분류 탭 (선택=브랜드 블루·하단 밑줄, 미선택=보조 텍스트).
Color mainNoticeAiTagFilterForeground(BuildContext context, bool selected) {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  if (selected) {
    return AppColors.primary;
  }
  return scheme.onSurfaceVariant;
}

class MainNoticeAiTagFilterChip extends StatelessWidget {
  const MainNoticeAiTagFilterChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color fg = mainNoticeAiTagFilterForeground(context, selected);
    final Widget chip = Container(
      height: kMainNoticeAiTagFilterBarHeight,
      alignment: Alignment.center,
      padding: const EdgeInsets.fromLTRB(
        8,
        0,
        8,
        kMainNoticeAiTagFilterIndicatorHeight,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: selected ? AppColors.primary : Colors.transparent,
            width: kMainNoticeAiTagFilterIndicatorHeight,
          ),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
        style: TextStyle(
          color: fg,
          fontSize: 14,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );

    if (onTap == null) {
      return chip;
    }

    return InkWell(
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      onTap: onTap,
      child: chip,
    );
  }
}

/// 본교 공지 상단 AI 분류 필터/표시 바.
class MainNoticeAiTagChipBar extends StatelessWidget {
  const MainNoticeAiTagChipBar({
    super.key,
    required this.chips,
    this.selection,
    this.onSelect,
    this.highlightedChips,
    this.interactive = true,
    this.embedded = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<String> chips;
  final String? selection;
  final ValueChanged<String>? onSelect;
  final List<String>? highlightedChips;
  final bool interactive;
  final bool embedded;
  final EdgeInsets padding;

  bool _isSelected(String label) {
    if (highlightedChips != null) {
      return highlightedChips!.contains(label);
    }
    return selection == label;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Widget bar = SizedBox(
      height: kMainNoticeAiTagFilterBarHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: padding,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (BuildContext context, int index) {
          final String label = chips[index];
          final bool selected = _isSelected(label);
          return SizedBox(
            height: kMainNoticeAiTagFilterBarHeight,
            child: MainNoticeAiTagFilterChip(
              label: label,
              selected: selected,
              onTap: interactive
                  ? () {
                      if (selected) return;
                      onSelect?.call(label);
                    }
                  : null,
            ),
          );
        },
      ),
    );

    if (embedded) {
      return bar;
    }

    return Material(
      color: scheme.surface,
      child: bar,
    );
  }
}
