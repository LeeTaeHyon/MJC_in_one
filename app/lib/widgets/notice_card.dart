import "package:flutter/material.dart";
import "package:mio_notice/models/notice_model.dart";
import "package:mio_notice/theme/app_colors.dart";
import "package:mio_notice/widgets/new_notice_badge.dart";
import "package:url_launcher/url_launcher.dart";

class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.notice,
  });

  final Notice notice;

  Future<void> _openUrl(BuildContext context) async {
    final uri = Uri.tryParse(notice.url);
    if (uri == null || !uri.hasScheme) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("유효하지 않은 링크입니다.")),
        );
      }
      return;
    }
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("링크를 열 수 없습니다.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => _openUrl(context),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              notice.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          if (notice.isNew)
            const Padding(
              padding: EdgeInsets.only(left: 8, top: 2),
              child: NewNoticeBadge(color: AppColors.primary),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              notice.date,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          if (notice.source.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                notice.source,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
