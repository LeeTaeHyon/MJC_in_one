import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:mio_notice/screens/common_webview_screen.dart";
import "package:mio_notice/services/notice_manager.dart";
import "package:mio_notice/theme/app_colors.dart";
import "package:url_launcher/url_launcher.dart";

class AcademicScheduleScreen extends StatefulWidget {
  const AcademicScheduleScreen({super.key});

  @override
  State<AcademicScheduleScreen> createState() => _AcademicScheduleScreenState();
}

class _AcademicScheduleScreenState extends State<AcademicScheduleScreen> {
  late Future<List<Map<String, dynamic>>> _scheduleFuture;
  String? _selectedSemester;

  @override
  void initState() {
    super.initState();
    _scheduleFuture = NoticeManager().getNotices(boardId: "main_schedule");
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _scheduleFuture = NoticeManager().getNotices(
        boardId: "main_schedule",
        forceRefresh: true,
      );
    });
    await _scheduleFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("학사일정"),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppColors.primary,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _scheduleFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final List<Map<String, dynamic>> items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 220),
                  Center(child: Text("등록된 학사일정이 없습니다.")),
                ],
              );
            }

            final List<String> semesters = items
                .map((item) => (item["semester"] ?? "").toString().trim())
                .where((semester) => semester.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
            final String? selected = semesters.isEmpty
                ? null
                : (_selectedSemester ?? semesters.first);
            final List<Map<String, dynamic>> visible = selected == null
                ? items
                : items
                    .where((item) => item["semester"]?.toString() == selected)
                    .toList();
            final Map<String, List<Map<String, dynamic>>> byMonth = {};
            for (final Map<String, dynamic> item in visible) {
              final String key = (item["month"] ?? _monthFromDate(item))
                  .toString()
                  .padLeft(2, "0");
              byMonth.putIfAbsent(key, () => []).add(item);
            }
            final List<String> months = byMonth.keys.toList()..sort();

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                if (semesters.isNotEmpty) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<String>(
                      segments: semesters
                          .map(
                            (semester) => ButtonSegment<String>(
                              value: semester,
                              label: Text(semester),
                            ),
                          )
                          .toList(),
                      selected: {selected!},
                      onSelectionChanged: (Set<String> value) {
                        if (value.isEmpty) return;
                        setState(() => _selectedSemester = value.first);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                for (final String month in months) ...[
                  _MonthHeader(month: month),
                  const SizedBox(height: 8),
                  ...byMonth[month]!.map(_ScheduleTile.new),
                  const SizedBox(height: 18),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  String _monthFromDate(Map<String, dynamic> item) {
    final String date = (item["start_date"] ?? item["date"] ?? "").toString();
    final RegExpMatch? match = RegExp(r"^\d{4}-(\d{2})-\d{2}").firstMatch(date);
    return match?.group(1) ?? "";
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.month});

  final String month;

  @override
  Widget build(BuildContext context) {
    return Text(
      "$month월",
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: AppColors.primary,
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile(this.item);

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final String title = (item["title"] ?? "").toString();
    final String start = (item["start_date"] ?? item["date"] ?? "").toString();
    final String end = (item["end_date"] ?? start).toString();
    final String url = (item["url"] ?? "").toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        elevation: 1,
        shadowColor: Colors.black12,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: url.isEmpty
              ? null
              : () async {
                  if (kIsWeb) {
                    await launchUrl(Uri.parse(url),
                        webOnlyWindowName: "_blank");
                  } else {
                    if (!context.mounted) return;
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => CommonWebViewScreen(
                          url: url,
                          title: "학사일정",
                        ),
                      ),
                    );
                  }
                },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.event_note_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatRange(start, end),
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatRange(String start, String end) {
    final String s = start.replaceAll("-", ".");
    final String e = end.replaceAll("-", ".");
    return s == e ? s : "$s~$e";
  }
}
