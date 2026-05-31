import "package:flutter/material.dart";
import "package:mjc_in_one/theme/app_theme.dart";
import "package:mjc_in_one/widgets/community_notice_image.dart";
import "package:mjc_in_one/widgets/mjc_notice_list_item.dart";

/// 학과 공지 목록 카드 ([MainWebsiteScreen] 공지 카드와 동일 레이아웃).
class CommunityNoticeListTile extends StatelessWidget {
  const CommunityNoticeListTile({
    super.key,
    required this.title,
    required this.author,
    required this.date,
    this.imageUrl,
    this.imageStoragePath,
    required this.onTap,
    this.isRead = false,
    this.isPinned = false,
    this.isFavorite = false,
    this.onTogglePinned,
    this.onToggleFavorite,
    this.brandColor,
  });

  final String title;
  final String author;
  final String date;
  final String? imageUrl;
  final String? imageStoragePath;
  final VoidCallback onTap;
  final bool isRead;
  final bool isPinned;
  final bool isFavorite;
  final VoidCallback? onTogglePinned;
  final VoidCallback? onToggleFavorite;
  final Color? brandColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    final Color metaColor = scheme.onSurfaceVariant;
    final bool hasThumb = (imageUrl ?? "").isNotEmpty ||
        (imageStoragePath ?? "").isNotEmpty;
    final bool showPinFavorite =
        onTogglePinned != null && onToggleFavorite != null;

    final List<Widget> footer = <Widget>[
      Row(
        children: <Widget>[
          Icon(Icons.person_outline, size: 14, color: metaColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: metaColor, fontSize: 13),
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Row(
        children: <Widget>[
          Icon(Icons.calendar_today_outlined, size: 14, color: metaColor),
          const SizedBox(width: 6),
          Text(
            date,
            style: TextStyle(color: metaColor, fontSize: 13),
          ),
        ],
      ),
    ];

    return MjcNoticeListItem(
      title: title,
      primaryLabel: "학과 공지",
      footer: footer,
      brandColor: brandColor ?? tokens.sourceMjc,
      isRead: isRead,
      isPinned: isPinned,
      isFavorite: isFavorite,
      onTap: onTap,
      showPinFavorite: showPinFavorite,
      onTogglePinned: onTogglePinned ?? () {},
      onToggleFavorite: onToggleFavorite ?? () {},
      titleTrailing: hasThumb
          ? CommunityNoticeImage(
              imageUrl: imageUrl,
              imageStoragePath: imageStoragePath,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(8),
            )
          : null,
    );
  }
}
