import "package:flutter/material.dart";
import "package:mjc_in_one/perf_flags.dart";
import "package:mjc_in_one/theme/app_theme.dart";
import "package:mjc_in_one/widgets/community_notice_image.dart";

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
  });

  final String title;
  final String author;
  final String date;
  final String? imageUrl;
  final String? imageStoragePath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color chipBackground =
        tokens.sourceMjc.withValues(alpha: isDark ? 0.18 : 0.12);
    final Color chipForeground = tokens.sourceMjc;
    final Color titleColor = scheme.onSurface;
    final Color metaColor = scheme.onSurfaceVariant;
    const bool lowRaster = kPerfLowRasterMode;
    final bool hasThumb = (imageUrl ?? "").isNotEmpty ||
        (imageStoragePath ?? "").isNotEmpty;

    final Widget cardBody = Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Container(
            width: 4,
            decoration: BoxDecoration(
              color: tokens.sourceMjc,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: chipBackground,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "학과 공지",
                        style: TextStyle(
                          color: chipForeground,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: metaColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: metaColor,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: metaColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          date,
                          style: TextStyle(
                            color: metaColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (hasThumb) ...[
                const SizedBox(width: 12),
                CommunityNoticeImage(
                  imageUrl: imageUrl,
                  imageStoragePath: imageStoragePath,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        elevation: lowRaster ? 0 : 2,
        shadowColor: lowRaster
            ? Colors.transparent
            : Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
        clipBehavior: lowRaster ? Clip.hardEdge : Clip.none,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: lowRaster
              ? cardBody
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.hardEdge,
                  child: cardBody,
                ),
        ),
      ),
    );
  }
}
