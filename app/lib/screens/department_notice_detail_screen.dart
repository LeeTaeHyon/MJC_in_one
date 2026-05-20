import "package:flutter/material.dart";
import "package:mjc_in_one/models/community_notice_media.dart";
import "package:mjc_in_one/theme/app_theme.dart";
import "package:mjc_in_one/widgets/community_notice_image.dart";
import "package:mjc_in_one/widgets/community_notice_image_viewer.dart";
import "package:mjc_in_one/widgets/linkified_selectable_text.dart";
import "package:url_launcher/url_launcher.dart";

/// 학과 공지 상세.
class DepartmentNoticeDetailScreen extends StatelessWidget {
  const DepartmentNoticeDetailScreen({
    super.key,
    required this.title,
    required this.author,
    required this.date,
    required this.body,
    this.images = const [],
    this.attachments = const [],
    this.sourceNote,
  });

  final String title;
  final String author;
  final String date;
  final String body;
  final List<CommunityNoticeMediaItem> images;
  final List<CommunityNoticeMediaItem> attachments;
  final String? sourceNote;

  Future<void> _openAttachment(
    BuildContext context,
    CommunityNoticeMediaItem item,
  ) async {
    final String url = item.url.trim();
    if (url.isEmpty) return;
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("첨부파일을 열 수 없습니다.")),
      );
    }
  }

  Widget _buildHeaderCard(
    ThemeData theme,
    ColorScheme scheme,
    MjcSurfaceTokens tokens,
  ) {
    final bool isDark = theme.brightness == Brightness.dark;
    final Color chipBg =
        tokens.sourceMjc.withValues(alpha: isDark ? 0.18 : 0.12);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              "학과 공지",
              style: TextStyle(
                color: tokens.sourceMjc,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            softWrap: true,
            overflow: TextOverflow.visible,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.person_outline,
                  size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.calendar_today_outlined,
                  size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                date,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          if ((sourceNote ?? "").trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              sourceNote!.trim(),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBodyCard(
    ThemeData theme,
    ColorScheme scheme,
    MjcSurfaceTokens tokens,
  ) {
    final bool isDark = theme.brightness == Brightness.dark;
    final TextStyle bodyStyle =
        theme.textTheme.bodyMedium?.copyWith(height: 1.55) ??
            const TextStyle(height: 1.55);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes_rounded,
                  size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                "본문",
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinkifiedSelectableText(
            text: body,
            style: bodyStyle,
            linkStyle: bodyStyle.copyWith(
              color: tokens.sourceMjc,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final MjcSurfaceTokens tokens = theme.extension<MjcSurfaceTokens>()!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "학과 공지",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: scheme.outline.withValues(alpha: 0.4),
            height: 1.0,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _buildHeaderCard(theme, scheme, tokens),
          if (images.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              "사진",
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ...images.asMap().entries.map((entry) {
              final CommunityNoticeMediaItem item = entry.value;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key < images.length - 1 ? 12 : 0,
                ),
                child: Material(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  elevation: 1,
                  shadowColor: Colors.black.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.45 : 0.08,
                  ),
                  child: InkWell(
                    onTap: () =>
                        CommunityNoticeImageViewer.open(context, item),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CommunityNoticeImage(
                          imageUrl: item.url,
                          imageStoragePath: item.storagePath,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.touch_app_outlined,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    "탭하여 확대·저장",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              "첨부파일",
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ...attachments.map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: theme.brightness == Brightness.dark ? 0.45 : 0.05,
                      ),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: const Icon(Icons.attach_file_outlined),
                  title: Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _openAttachment(context, item),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildBodyCard(theme, scheme, tokens),
        ],
      ),
    );
  }
}
