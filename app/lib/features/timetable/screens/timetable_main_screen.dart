import "package:flutter/material.dart";
import "package:mjc_in_one/features/timetable/models/timetable_models.dart";
import "package:mjc_in_one/features/timetable/screens/timetable_add_courses_screen.dart";
import "package:mjc_in_one/features/timetable/services/timetable_official_service.dart";
import "package:mjc_in_one/features/timetable/services/timetable_storage_service.dart";
import "package:mjc_in_one/features/timetable/widgets/timetable_manual_entry_sheet.dart";
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

  Future<void> _openManualFromMain() async {
    final ParsedCourseOffering? o =
        await showTimetableManualEntrySheet(context);
    if (!mounted || o == null) return;
    final List<ParsedCourseOffering> next = <ParsedCourseOffering>[
      ..._enrolled,
      o,
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
                if (o.professor.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    o.professor,
                    style: TextStyle(
                      fontFamily: kPretendardFontFamily,
                      fontSize: 14,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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
                    child: Text(
                      items[i].courseName,
                      style: TextStyle(
                        fontFamily: kPretendardFontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("시간표"),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == "official") {
                _openOfficialCatalog();
                return;
              }
              if (value == "ocr") {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("스크린샷으로 불러오기는 추후 제공 예정입니다."),
                  ),
                );
              }
            },
            itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: "official",
                child: Text("공식 시간표 불러오기"),
              ),
              PopupMenuItem<String>(
                value: "ocr",
                child: Text("스크린샷으로 불러오기"),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _enrolled.isEmpty
              ? _buildEmpty(context)
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
                            color: scheme.primary,
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
          : FloatingActionButton.extended(
              onPressed: _openOfficialCatalog,
              icon: const Icon(Icons.cloud_download_outlined),
              label: const Text("시간표 추가"),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.timetableSlotOnColor,
            ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.calendar_today_outlined, size: 56, color: scheme.outline),
            const SizedBox(height: 16),
            Text(
              "저장된 시간표가 없습니다.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: kPretendardFontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "공식 시간표(Firestore)에서 강의를 불러와\n원하는 분반을 선택해 주세요.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: kPretendardFontFamily,
                fontSize: 13,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _openOfficialCatalog,
              icon: const Icon(Icons.cloud_download_outlined),
              label: const Text("공식 시간표 불러오기"),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.timetableSlotOnColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openManualFromMain,
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text("직접 추가"),
            ),
          ],
        ),
      ),
    );
  }
}
