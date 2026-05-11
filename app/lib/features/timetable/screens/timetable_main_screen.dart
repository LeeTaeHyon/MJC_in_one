import "dart:typed_data";

import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:mio_notice/features/timetable/models/timetable_models.dart";
import "package:mio_notice/features/timetable/screens/timetable_add_courses_screen.dart";
import "package:mio_notice/features/timetable/services/timetable_excel_parser.dart";
import "package:mio_notice/features/timetable/services/timetable_storage_service.dart";
import "package:mio_notice/features/timetable/widgets/timetable_manual_entry_sheet.dart";
import "package:mio_notice/features/timetable/widgets/timetable_week_grid.dart";
import "package:mio_notice/theme/app_colors.dart";
import "package:mio_notice/theme/app_theme.dart";

/// Saved weekly timetable + import / OCR placeholder.
class TimetableMainScreen extends StatefulWidget {
  const TimetableMainScreen({super.key});

  @override
  State<TimetableMainScreen> createState() => _TimetableMainScreenState();
}

class _TimetableMainScreenState extends State<TimetableMainScreen> {
  List<ParsedCourseOffering> _enrolled = const <ParsedCourseOffering>[];
  bool _loading = true;

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

  List<TimetableSlot> get _allSlots =>
      _enrolled.expand((ParsedCourseOffering o) => o.slots).toList();

  ParsedCourseOffering? _offeringForSlot(TimetableSlot s) {
    for (final ParsedCourseOffering o in _enrolled) {
      if (o.offeringId == s.offeringId) return o;
    }
    return null;
  }

  Future<void> _pickExcelAndEdit({bool mergeExisting = false}) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>["xlsx"],
      withData: true,
    );
    if (!mounted) return;
    if (result == null || result.files.isEmpty) return;
    final Uint8List? bytes = result.files.first.bytes;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("파일 데이터를 읽을 수 없습니다.")),
      );
      return;
    }
    List<ParsedCourseOffering> catalog;
    try {
      catalog = TimetableExcelParser.parseBytes(bytes);
    } on TimetableExcelParseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("엑셀을 읽는 중 오류가 났습니다: $e")),
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

    if (!mounted) return;
    final List<ParsedCourseOffering>? picked =
        await Navigator.of(context).push<List<ParsedCourseOffering>>(
      MaterialPageRoute<List<ParsedCourseOffering>>(
        builder: (_) => TimetableAddCoursesScreen(
          catalog: catalog,
          initialSelectedOfferingIds: mergeExisting ? initialSelected : <String>{},
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
    await TimetableStorageService.saveEnrolled(next);
    await _reload();
  }

  Future<void> _openManualFromMain() async {
    final ParsedCourseOffering? o =
        await showTimetableManualEntrySheet(context);
    if (!mounted || o == null) return;
    final List<ParsedCourseOffering> next = <ParsedCourseOffering>[
      ..._enrolled,
      o,
    ];
    await TimetableStorageService.saveEnrolled(next);
    await _reload();
  }

  void _onSlotTap(TimetableSlot slot) {
    final ParsedCourseOffering? o = _offeringForSlot(slot);
    if (o == null) return;
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
                Text(
                  o.scheduleSummary,
                  style: TextStyle(
                    fontFamily: kPretendardFontFamily,
                    fontSize: 13,
                    height: 1.4,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text("시간표에서 삭제"),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final List<ParsedCourseOffering> next = _enrolled
                        .where((ParsedCourseOffering x) => x.offeringId != o.offeringId)
                        .toList();
                    await TimetableStorageService.saveEnrolled(next);
                    await _reload();
                  },
                ),
              ],
            ),
          ),
        );
      },
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
                          slots: _allSlots,
                          onSlotTap: _onSlotTap,
                        ),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _pickExcelAndEdit(mergeExisting: true),
              icon: const Icon(Icons.add_rounded),
              label: const Text("강의 추가"),
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
              "학교 공지의 전체 강의시간표 엑셀(xlsx)을 불러와\n원하는 분반을 선택해 주세요.",
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
              onPressed: () => _pickExcelAndEdit(mergeExisting: false),
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text("엑셀에서 시간표 가져오기"),
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
