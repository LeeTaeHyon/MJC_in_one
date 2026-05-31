import "package:flutter/material.dart";
import "package:mjc_in_one/perf_flags.dart";
import "package:mjc_in_one/theme/app_theme.dart";

class MjcNoticeListActionIcons extends StatelessWidget {
  const MjcNoticeListActionIcons({
    super.key,
    required this.isPinned,
    required this.isFavorite,
    required this.onTogglePinned,
    required this.onToggleFavorite,
  });

  final bool isPinned;
  final bool isFavorite;
  final VoidCallback onTogglePinned;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color inactive = scheme.onSurfaceVariant.withValues(alpha: 0.72);
    const Color favActive = Color(0xFFFFC107);
    const Color pinActive = Color(0xFFE53935);

    Widget iconButton({
      required IconData icon,
      required bool active,
      required VoidCallback onTap,
      required String tooltip,
      required Color activeColor,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Tooltip(
              message: tooltip,
              child: Icon(
                icon,
                size: 20,
                color: active ? activeColor : inactive,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        iconButton(
          icon: isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
          active: isFavorite,
          onTap: onToggleFavorite,
          tooltip: "즐겨찾기",
          activeColor: favActive,
        ),
        iconButton(
          icon: isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
          active: isPinned,
          onTap: onTogglePinned,
          tooltip: "상단 고정",
          activeColor: pinActive,
        ),
      ],
    );
  }
}

class MjcNoticeListCategoryHeader extends StatelessWidget {
  const MjcNoticeListCategoryHeader({
    super.key,
    required this.primaryLabel,
    this.secondaryLabels = const <String>[],
    required this.accentColor,
    this.tagHighlightColor,
    this.selectedTag = "전체",
    required this.isPinned,
    required this.isFavorite,
    required this.onTogglePinned,
    required     this.onToggleFavorite,
    this.showActionIcons = true,
    this.secondaryLabelsOnNewLine = false,
  });

  final String primaryLabel;
  final List<String> secondaryLabels;
  final Color accentColor;
  final Color? tagHighlightColor;
  final String selectedTag;
  final bool isPinned;
  final bool isFavorite;
  final VoidCallback onTogglePinned;
  final VoidCallback onToggleFavorite;
  final bool showActionIcons;
  final bool secondaryLabelsOnNewLine;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final MjcComponentTokens? components =
        Theme.of(context).extension<MjcComponentTokens>();
    final Color secondaryColor = scheme.onSurfaceVariant;
    final Color baseHighlight = tagHighlightColor ?? accentColor;
    final Color highlightAccent = isDark && components != null
        ? components.bottomNavSelected
        : baseHighlight;
    final String selected = selectedTag.trim();
    final bool canHighlight = selected.isNotEmpty && selected != "전체";

    TextStyle tagStyle(String tag) {
      final bool highlight = canHighlight && tag.trim() == selected;
      return TextStyle(
        color: highlight ? highlightAccent : secondaryColor,
        fontSize: 13,
        fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
      );
    }

    final TextStyle primaryStyle = TextStyle(
      color: accentColor,
      fontSize: 13,
      fontWeight: FontWeight.w700,
    );

    final List<String> visibleTags = secondaryLabels
        .map((String tag) => tag.trim())
        .where((String tag) => tag.isNotEmpty)
        .toList();

    final Widget labelBlock = secondaryLabelsOnNewLine
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                primaryLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: primaryStyle,
              ),
              if (visibleTags.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    for (final String tag in visibleTags)
                      Text(
                        tag,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tagStyle(tag),
                      ),
                  ],
                ),
              ],
            ],
          )
        : Wrap(
            spacing: 0,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                primaryLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: primaryStyle,
              ),
              for (final String tag in visibleTags) ...<Widget>[
                Text(
                  " · ",
                  style: TextStyle(color: secondaryColor, fontSize: 13),
                ),
                Text(
                  tag,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tagStyle(tag),
                ),
              ],
            ],
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: labelBlock),
      if (showActionIcons) ...<Widget>[
        const SizedBox(width: 4),
        MjcNoticeListActionIcons(
          isPinned: isPinned,
          isFavorite: isFavorite,
          onTogglePinned: onTogglePinned,
          onToggleFavorite: onToggleFavorite,
        ),
      ],
    ],
  );
}
}

/// 본교·CTL·MPU·학과 공지 등 공통 카드 레이아웃.
class MjcNoticeListItem extends StatelessWidget {
  const MjcNoticeListItem({
    super.key,
    required this.title,
    required this.primaryLabel,
    this.secondaryLabels = const <String>[],
    this.selectedTag = "전체",
    this.dateLabel,
    this.footer = const <Widget>[],
    this.titleTrailing,
    this.overlayTrailing,
    required this.brandColor,
    required this.isRead,
    required this.isPinned,
    required this.isFavorite,
    required this.onTap,
    required this.onTogglePinned,
    required this.onToggleFavorite,
    this.showPinFavorite = true,
    this.surfaceColor,
    this.elevation,
    this.titleColor,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
    this.secondaryLabelsOnNewLine = false,
  });

  final String title;
  final String primaryLabel;
  final List<String> secondaryLabels;
  final String selectedTag;
  final String? dateLabel;
  final List<Widget> footer;
  final Widget? titleTrailing;
  final Widget? overlayTrailing;
  final Color brandColor;
  final bool isRead;
  final bool isPinned;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onTogglePinned;
  final VoidCallback onToggleFavorite;
  final bool showPinFavorite;
  final Color? surfaceColor;
  final double? elevation;
  final Color? titleColor;
  final EdgeInsets contentPadding;
  final bool secondaryLabelsOnNewLine;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accentColor =
        isRead ? scheme.onSurfaceVariant : brandColor;
    final Color resolvedTitleColor = titleColor ??
        (isRead ? tokens.noticeReadTitle : scheme.onSurface);
    final Color dateColor = scheme.onSurfaceVariant;
    const bool lowRaster = kPerfLowRasterMode;
    final double cardElevation =
        elevation ?? (lowRaster ? 0 : 2);

    final List<Widget> footerRows = footer.isNotEmpty
        ? footer
        : <Widget>[
            if ((dateLabel ?? "").trim().isNotEmpty)
              Row(
                children: <Widget>[
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: dateColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      dateLabel!.trim(),
                      style: TextStyle(color: dateColor, fontSize: 13),
                    ),
                  ),
                ],
              ),
          ];

    final Widget titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: resolvedTitleColor,
            height: 1.4,
          ),
        ),
        if (footerRows.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          ...footerRows,
        ],
      ],
    );

    final Widget content = Padding(
      padding: contentPadding,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              width: 4,
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  MjcNoticeListCategoryHeader(
                    primaryLabel: primaryLabel,
                    secondaryLabels: secondaryLabels,
                    accentColor: accentColor,
                    tagHighlightColor: brandColor,
                    selectedTag: selectedTag,
                    isPinned: isPinned,
                    isFavorite: isFavorite,
                    onTogglePinned: onTogglePinned,
                    onToggleFavorite: onToggleFavorite,
                    showActionIcons: showPinFavorite,
                    secondaryLabelsOnNewLine: secondaryLabelsOnNewLine,
                  ),
                  const SizedBox(height: 10),
                  if (titleTrailing == null)
                    titleBlock
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(child: titleBlock),
                        const SizedBox(width: 12),
                        titleTrailing!,
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final Widget cardChild = overlayTrailing == null
        ? content
        : Stack(
            children: <Widget>[
              content,
              Positioned(
                right: 12,
                bottom: 16,
                child: overlayTrailing!,
              ),
            ],
          );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: surfaceColor ?? scheme.surface,
        borderRadius: BorderRadius.circular(12),
        elevation: cardElevation,
        shadowColor: cardElevation <= 0 || lowRaster
            ? Colors.transparent
            : Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
        clipBehavior: lowRaster ? Clip.hardEdge : Clip.none,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: lowRaster
              ? cardChild
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.hardEdge,
                  child: cardChild,
                ),
        ),
      ),
    );
  }
}
