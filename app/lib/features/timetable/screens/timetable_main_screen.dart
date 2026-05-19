import "package:flutter/material.dart";
import "package:mjc_in_one/features/timetable/models/timetable_models.dart";
import "package:mjc_in_one/features/timetable/screens/timetable_add_courses_screen.dart";
import "package:mjc_in_one/features/timetable/services/timetable_official_service.dart";
import "package:mjc_in_one/features/timetable/services/timetable_storage_service.dart";
import "package:mjc_in_one/features/timetable/widgets/timetable_offering_schedule_text_block.dart";
import "package:mjc_in_one/features/timetable/widgets/timetable_week_grid.dart";
import "package:mjc_in_one/theme/app_colors.dart";
import "package:mjc_in_one/theme/app_theme.dart";

/// Saved weekly timetable + import / OCR placeholder.
class TimetableMainScreen extends StatefulWidget {
  const TimetableMainScreen({super.key});

  @override
  State<TimetableMainScreen> createState() => _TimetableMainScreenState();
}

class _TimetableMainScreenState extends State<TimetableMainScreen> {
  List<ParsedCourseOffering> _enrolled = const <ParsedCourseOffering>[];
  bool _loading = true;
  final TimetableOfficialCatalogService _officialService =
      TimetableOfficialCatalogService();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final List<ParsedCourseOffering> list =
        await TimetableStorageService.loadEnrolled();
    if (!mounted) return;
    setState(() {
      _enrolled = list;
      _loading = false;
    });
  }

  Future<void> _saveEnrolledAndReload(List<ParsedCourseOffering> next) async {
    final int removedDupes = await TimetableStorageService.saveEnrolled(next);
    if (!mounted) return;
    if (removedDupes > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("이미 시간표에 있는 강의는 중복으로 추가되지 않습니다."),
        ),
      );
    }
    await _reload();
  }

  List<TimetableSlot> get _gridSlots => _enrolled
      .where((ParsedCourseOffering o) => !o.isRemoteExamFaceToFaceOnly)
      .expand((ParsedCourseOffering o) => o.slots)
      .toList();

  Map<String, String> get _professorByOfferingId => <String, String>{
        for (final ParsedCourseOffering o in _enrolled)
          if (!o.isRemoteExamFaceToFaceOnly && o.professor.trim().isNotEmpty)
            o.offeringId: o.professor.trim(),
      };

  List<ParsedCourseOffering> get _remoteExamOfferings {
    final List<ParsedCourseOffering> list = _enrolled
        .where((ParsedCourseOffering o) => o.isRemoteExamFaceToFaceOnly)
        .toList();
    list.sort(
      (ParsedCourseOffering a, ParsedCourseOffering b) =>
          a.courseName.compareTo(b.courseName),
    );
    return list;
  }

  static double _parseCredits(String raw) {
    final String s = raw.trim();
    if (s.isEmpty) return 0;
    final double? direct = double.tryParse(s);
    if (direct != null) return direct;
    final RegExpMatch? m = RegExp(r"(\d+(?:\.\d+)?)").firstMatch(s);
    if (m == null) return 0;
    return double.tryParse(m.group(1)!) ?? 0;
  }

  double get _totalCredits =>
      _enrolled.fold(0.0, (double sum, ParsedCourseOffering o) {
        return sum + _parseCredits(o.credits);
      });

  String get _totalCreditsLabel {
    final double total = _totalCredits;
    if (total == total.roundToDouble()) {
      return "${total.toInt()}학점";
    }
    return "${total.toStringAsFixed(1)}학점";
  }

  ParsedCourseOffering? _offeringForSlot(TimetableSlot s) {
    for (final ParsedCourseOffering o in _enrolled) {
      if (o.offeringId == s.offeringId) return o;
    }
    return null;
  }

  Future<void> _openOfficialCatalog() async {
    final List<ParsedCourseOffering> catalog = await _officialService.load();
    if (!mounted) return;
    if (catalog.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("공식 시간표 데이터가 없습니다.")),
      );
      return;
    }

    final Set<String> catalogIds =
        catalog.map((ParsedCourseOffering o) => o.offeringId).toSet();
    final Set<String> initialSelected = <String>{};
    for (final ParsedCourseOffering o in _enrolled) {
      if (catalogIds.contains(o.offeringId)) {
        initialSelected.add(o.offeringId);
      }
    }

    final List<ParsedCourseOffering>? picked =
        await Navigator.of(context).push<List<ParsedCourseOffering>>(
      MaterialPageRoute<List<ParsedCourseOffering>>(
        builder: (_) => TimetableAddCoursesScreen(
          catalog: catalog,
          initialSelectedOfferingIds: initialSelected,
        ),
      ),
    );
    if (!mounted || picked == null) return;

    final List<ParsedCourseOffering> kept = _enrolled
        .where((ParsedCourseOffering o) => !catalogIds.contains(o.offeringId))
        .toList();
    final List<ParsedCourseOffering> next = <ParsedCourseOffering>[
      ...kept,
      ...picked,
    ];
    await _saveEnrolledAndReload(next);
  }

  void _onSlotTap(TimetableSlot slot) {
    final ParsedCourseOffering? o = _offeringForSlot(slot);
    if (o == null) return;
    _showOfferingDetailSheet(o);
  }

  void _showOfferingDetailSheet(ParsedCourseOffering o) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        o.courseName,
                        style: TextStyle(
                          fontFamily: kPretendardFontFamily,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(ctx).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  o.professorSectionLine,
                  style: TextStyle(
                    fontFamily: kPretendardFontFamily,
                    fontSize: 14,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  o.credits.isEmpty ? "학점 미상" : "${o.credits}학점",
                  style: TextStyle(
                    fontFamily: kPretendardFontFamily,
                    fontSize: 14,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                TimetableOfferingScheduleTextBlock(offering: o),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text("시간표에서 삭제"),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final List<ParsedCourseOffering> next = _enrolled
                        .where((ParsedCourseOffering x) => x.offeringId != o.offeringId)
                        .toList();
                    await _saveEnrolledAndReload(next);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRemoteExamCourseList(BuildContext context) {
    final List<ParsedCourseOffering> items = _remoteExamOfferings;
    if (items.isEmpty) return const SizedBox.shrink();

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 16),
        Material(
          color: scheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: scheme.outline.withValues(alpha: 0.35),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < items.length; i++) ...<Widget>[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: tokens.hairline,
                  ),
                InkWell(
                  onTap: () => _showOfferingDetailSheet(items[i]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          items[i].courseName,
                          style: TextStyle(
                            fontFamily: kPretendardFontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        if (items[i].sectionLabel.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            items[i].sectionLabel,
                            style: TextStyle(
                              fontFamily: kPretendardFontFamily,
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    // 라이트: primary AppBar. 다크: 전역 cardDark 대신 홈 헤더와 동일한 파란 톤.
    final Color appBarBackground =
        isDark ? const Color(0xFF073A8C) : AppColors.primary;
    const Color appBarForeground = Colors.white;
    const TextStyle appBarTextStyle = TextStyle(
      fontFamily: kPretendardFontFamily,
      color: appBarForeground,
      fontWeight: FontWeight.w600,
    );
    final Color semesterLabelColor =
        isDark ? AppColors.switchActiveDark : scheme.primary;

    return Scaffold(
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      appBar: AppBar(
        backgroundColor: appBarBackground,
        foregroundColor: appBarForeground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: appBarTextStyle.copyWith(fontSize: 20),
        toolbarTextStyle: appBarTextStyle,
        title: const Text("시간표"),
        actions: <Widget>[
          if (!_loading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  _totalCreditsLabel,
                  style: const TextStyle(
                    fontFamily: kPretendardFontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: appBarForeground,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _reload,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      "이번 학기",
                      style: TextStyle(
                        fontFamily: kPretendardFontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: semesterLabelColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "내 시간표",
                      style: TextStyle(
                        fontFamily: kPretendardFontFamily,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TimetableWeekGrid(
                      slots: _gridSlots,
                      onSlotTap: _onSlotTap,
                      professorByOfferingId: _professorByOfferingId,
                      startHour: 9,
                      endHour: 18,
                    ),
                    _buildRemoteExamCourseList(context),
                  ],
                ),
              ),
            ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton(
              heroTag: null,
              onPressed: _openOfficialCatalog,
              tooltip: "시간표 추가",
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.timetableSlotOnColor,
              splashColor: Colors.transparent,
              highlightElevation: 6,
              child: const Icon(Icons.edit_rounded),
            ),
    );
  }
}
