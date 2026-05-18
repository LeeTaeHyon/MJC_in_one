import "package:flutter/material.dart";
import "package:mjc_in_one/perf_flags.dart";
import "package:mjc_in_one/theme/app_theme.dart";
/// 메인 공지 리스트(`MainWebsiteScreen` 카드)와 동일한 톤의 검색 결과 카드입니다.
/// 핀/즐겨찾기 버튼은 검색 맥락에서 생략합니다.
class NoticeSearchResultCard extends StatelessWidget {
  const NoticeSearchResultCard({
    super.key,
    required this.title,
    required this.chipLabel,
    this.aiTags = const <String>[],
    required this.dateLine,
    required this.accentColor,
    required this.onTap,
    this.isRead = false,
  });

  final String title;
  final String chipLabel;
  final List<String> aiTags;
  final String dateLine;
  final Color accentColor;
  final VoidCallback onTap;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color readTitleColor = tokens.noticeReadTitle;
    final String displayTitle = title.trim().isEmpty ? "(제목 없음)" : title.trim();
    final String chip = chipLabel.trim().isEmpty ? "공지" : chipLabel.trim();
    final Color stripColor = isRead ? scheme.onSurfaceVariant : accentColor;
    final Color chipBackground =
        accentColor.withValues(alpha: isDark ? 0.18 : 0.12);
    final Color chipForeground = accentColor;
    final Color titleColor = isRead ? readTitleColor : scheme.onSurface;
    final Color dateColor = scheme.onSurfaceVariant;
    const bool lowRaster = kPerfLowRasterMode;

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
              ? Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: stripColor,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: _cardBody(
                        context: context,
                        chip: chip,
                        chipBackground: chipBackground,
                        chipForeground: chipForeground,
                        aiTags: aiTags,
                        displayTitle: displayTitle,
                        titleColor: titleColor,
                        dateLine: dateLine,
                        dateColor: dateColor,
                      ),
                    ),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.hardEdge,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 4,
                          decoration: BoxDecoration(
                            color: stripColor,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              bottomLeft: Radius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: _cardBody(
                          context: context,
                          chip: chip,
                          chipBackground: chipBackground,
                          chipForeground: chipForeground,
                          aiTags: aiTags,
                          displayTitle: displayTitle,
                          titleColor: titleColor,
                          dateLine: dateLine,
                          dateColor: dateColor,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _cardBody({
    required BuildContext context,
    required String chip,
    required Color chipBackground,
    required Color chipForeground,
    required List<String> aiTags,
    required String displayTitle,
    required Color titleColor,
    required String dateLine,
    required Color dateColor,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: chipBackground,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                chip,
                style: TextStyle(
                  color: chipForeground,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...aiTags.map(
              (t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Text(
                  t,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          displayTitle,
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
              Icons.calendar_today_outlined,
              size: 14,
              color: dateColor,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                dateLine.trim().isEmpty ? "—" : dateLine.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: dateColor, fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
