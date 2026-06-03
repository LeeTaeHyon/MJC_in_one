import "dart:async";

import "package:flutter/material.dart";
import "package:mjc_in_one/features/timetable/models/timetable_models.dart";
import "package:mjc_in_one/features/timetable/widgets/timetable_added_offering_pulse.dart";
import "package:mjc_in_one/features/timetable/widgets/timetable_manual_entry_sheet.dart";
import "package:mjc_in_one/features/timetable/widgets/timetable_offering_schedule_text_block.dart";
import "package:mjc_in_one/features/timetable/utils/timetable_grid_hours.dart";
import "package:mjc_in_one/features/timetable/widgets/timetable_week_grid.dart";
import "package:mjc_in_one/mpu_profile_prefs.dart";
import "package:mjc_in_one/theme/app_theme.dart";
import "package:mjc_in_one/utils/mjc_snack_bar.dart";
import "package:mjc_in_one/widgets/mjc_floating_pill_cta.dart";

/// Top preview grid + filter chips + course list.
class TimetableAddCoursesScreen extends StatefulWidget {
  const TimetableAddCoursesScreen({
    super.key,
    required this.catalog,
    required this.initialSelectedOfferingIds,
  });

  final List<ParsedCourseOffering> catalog;
  final Set<String> initialSelectedOfferingIds;

  @override
  State<TimetableAddCoursesScreen> createState() =>
      _TimetableAddCoursesScreenState();
}

class _TimetableAddCoursesScreenState extends State<TimetableAddCoursesScreen> {
  late List<ParsedCourseOffering> _catalog;
  late Set<String> _selected;
  String _deptFilter = "";
  String _search = "";
  String _gradeFilter = "";
  String _creditsFilter = "";
  String _completionFilter = "";
  final ScrollController _previewScrollController = ScrollController();
  final ScrollController _listScrollController = ScrollController();
  final GlobalKey _highlightListItemKey = GlobalKey();
  final GlobalKey _remotePreviewSectionKey = GlobalKey();
  String? _pulseOfferingId;
  Timer? _pulseClearTimer;

  static const double _kPreviewViewportHeight = 340;
  static const double _kPreviewHourHeight = 44;
  static const double _kPreviewHeaderHeight = 22;
  static const Duration _kAddedFeedbackScrollDuration =
      Duration(milliseconds: 420);
  static const Duration _kPulseHighlightDuration = Duration(milliseconds: 1200);

  @override
  void initState() {
    super.initState();
    _catalog = List<ParsedCourseOffering>.from(widget.catalog);
    _selected = Set<String>.from(widget.initialSelectedOfferingIds);
    _applySavedProfileFilters();
  }

  /// 마이페이지(프로필)에 저장된 학과·학년이 현재 강의 목록과 맞을 때만 초기 필터로 적용합니다.
  Future<void> _applySavedProfileFilters() async {
    final MpuProfile profile = await loadMpuProfile();
    if (!mounted) return;
    final String dept = profile.department.trim();
    final String grade = profile.grade.trim();
    final bool applyDept = dept.isNotEmpty &&
        _catalog.any((ParsedCourseOffering o) => o.department == dept);
    final bool applyGrade = grade.isNotEmpty &&
        _catalog.any(
          (ParsedCourseOffering o) => _gradeMatches(o.gradeYear, grade),
        );
    setState(() {
      if (applyDept) _deptFilter = dept;
      if (applyGrade) _gradeFilter = grade;
    });
    if (!mounted || (!applyDept && !applyGrade)) return;
    final String snackMessage = applyDept && applyGrade
        ? "마이페이지에 저장된 학과·학년으로 목록 필터를 맞춰 두었습니다."
        : applyDept
            ? "마이페이지에 저장된 학과로 목록 필터를 맞춰 두었습니다."
            : "마이페이지에 저장된 학년으로 목록 필터를 맞춰 두었습니다.";
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showMjcSnackBar(context, message: snackMessage);
    });
  }

  static int? _gradeNumber(String raw) {
    final String s = raw.trim();
    if (s.isEmpty) return null;
    final RegExpMatch? m = RegExp(r"(\d+)").firstMatch(s);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  static bool _gradeMatches(String offeringGrade, String filter) {
    if (filter.isEmpty) return true;
    final int? o = _gradeNumber(offeringGrade);
    final int? f = _gradeNumber(filter);
    if (o != null && f != null) return o == f;
    return offeringGrade.trim() == filter.trim();
  }

  List<ParsedCourseOffering> get _filtered {
    return _catalog.where((ParsedCourseOffering o) {
      if (_deptFilter.isNotEmpty && o.department != _deptFilter) {
        return false;
      }
      if (_search.isNotEmpty) {
        final String q = _search.toLowerCase();
        if (!o.courseName.toLowerCase().contains(q) &&
            !o.professor.toLowerCase().contains(q) &&
            !o.section.toLowerCase().contains(q)) {
          return false;
        }
      }
      if (!_gradeMatches(o.gradeYear, _gradeFilter)) return false;
      if (_creditsFilter.isNotEmpty && o.credits != _creditsFilter) {
        return false;
      }
      if (_completionFilter.isNotEmpty &&
          o.completionType != _completionFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  List<TimetableSlot> get _previewSlots {
    final List<TimetableSlot> out = <TimetableSlot>[];
    for (final ParsedCourseOffering o in _catalog) {
      if (_selected.contains(o.offeringId) && !o.isRemoteExamFaceToFaceOnly) {
        out.addAll(o.slots);
      }
    }
    return out;
  }

  List<ParsedCourseOffering> get _selectedRemoteExamOfferings {
    final List<ParsedCourseOffering> out = <ParsedCourseOffering>[];
    for (final ParsedCourseOffering o in _catalog) {
      if (_selected.contains(o.offeringId) && o.isRemoteExamFaceToFaceOnly) {
        out.add(o);
      }
    }
    out.sort(
      (ParsedCourseOffering a, ParsedCourseOffering b) =>
          a.courseName.compareTo(b.courseName),
    );
    return out;
  }

  /// 같은 요일에서 수업 시간대가 겹치면 true (경계만 맞닿는 경우는 제외).
  static bool _slotsOverlap(TimetableSlot a, TimetableSlot b) {
    if (a.weekday != b.weekday) return false;
    return a.startMinute < b.endMinute && b.startMinute < a.endMinute;
  }

  /// 그리드에 올라가는 수업끼리만 검사. 원격·대면시험 전용 행은 시간 겹침 검사에서 제외.
  ParsedCourseOffering? _firstScheduleConflict(ParsedCourseOffering candidate) {
    if (candidate.isRemoteExamFaceToFaceOnly || candidate.slots.isEmpty) {
      return null;
    }
    for (final ParsedCourseOffering other in _catalog) {
      if (!_selected.contains(other.offeringId)) continue;
      if (other.offeringId == candidate.offeringId) continue;
      if (other.isRemoteExamFaceToFaceOnly || other.slots.isEmpty) continue;
      for (final TimetableSlot a in candidate.slots) {
        for (final TimetableSlot b in other.slots) {
          if (_slotsOverlap(a, b)) return other;
        }
      }
    }
    return null;
  }

  void _showScheduleConflictSnack(ParsedCourseOffering conflictsWith) {
    if (!mounted) return;
    showMjcSnackBar(
      context,
      message: "이미 선택한 강의와 수업 시간이 겹칩니다: ${conflictsWith.courseName}",
    );
  }

  void _selectOffering(ParsedCourseOffering o) {
    final ParsedCourseOffering? conflict = _firstScheduleConflict(o);
    if (conflict != null) {
      _showScheduleConflictSnack(conflict);
      return;
    }
    setState(() {
      _selected.add(o.offeringId);
      _pulseOfferingId = o.offeringId;
    });
    _scheduleAddedOfferingFeedback(o);
  }

  void _scheduleAddedOfferingFeedback(ParsedCourseOffering o) {
    _pulseClearTimer?.cancel();
    _pulseClearTimer = Timer(_kPulseHighlightDuration, () {
      if (!mounted) return;
      if (_pulseOfferingId != o.offeringId) return;
      setState(() => _pulseOfferingId = null);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollPreviewToOffering(o);
      _scrollListToOfferingIfNeeded(o);
    });
  }

  TimetableSlot? _earliestWeekdaySlot(ParsedCourseOffering o) {
    TimetableSlot? earliest;
    for (final TimetableSlot s in o.slots) {
      if (s.weekday < 1 || s.weekday > 5) continue;
      if (earliest == null || s.startMinute < earliest.startMinute) {
        earliest = s;
      }
    }
    return earliest;
  }

  void _scrollPreviewToOffering(ParsedCourseOffering o) {
    if (!_previewScrollController.hasClients) return;

    if (o.isRemoteExamFaceToFaceOnly) {
      final BuildContext? remoteCtx = _remotePreviewSectionKey.currentContext;
      if (remoteCtx != null) {
        Scrollable.ensureVisible(
          remoteCtx,
          alignment: 0.05,
          duration: _kAddedFeedbackScrollDuration,
          curve: Curves.easeOutCubic,
        );
        return;
      }
      final double max = _previewScrollController.position.maxScrollExtent;
      _previewScrollController.animateTo(
        max,
        duration: _kAddedFeedbackScrollDuration,
        curve: Curves.easeOutCubic,
      );
      return;
    }

    final TimetableSlot? slot = _earliestWeekdaySlot(o);
    if (slot == null) return;

    final int endHour = timetableGridEndHourForSlots(_previewSlots);
    const int startMin = kTimetableGridStartHour * 60;
    final int endMin = endHour * 60;
    final int spanMin = endMin - startMin;
    if (spanMin <= 0) return;

    final double gridBodyHeight =
        (endHour - kTimetableGridStartHour) * _kPreviewHourHeight;
    final double t =
        ((slot.startMinute - startMin) / spanMin).clamp(0.0, 1.0).toDouble();
    final double slotTop = _kPreviewHeaderHeight + t * gridBodyHeight;
    final double target = (slotTop - _kPreviewViewportHeight * 0.28)
        .clamp(0.0, _previewScrollController.position.maxScrollExtent);

    _previewScrollController.animateTo(
      target,
      duration: _kAddedFeedbackScrollDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollListToOfferingIfNeeded(ParsedCourseOffering o) {
    final BuildContext? itemCtx = _highlightListItemKey.currentContext;
    if (itemCtx == null) return;
    Scrollable.ensureVisible(
      itemCtx,
      alignment: 0.35,
      duration: _kAddedFeedbackScrollDuration,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openManualAdd() async {
    final ParsedCourseOffering? created =
        await showTimetableManualEntrySheet(context);
    if (!mounted || created == null) return;
    final ParsedCourseOffering? conflict =
        _firstScheduleConflict(created);
    setState(() {
      _catalog = <ParsedCourseOffering>[..._catalog, created];
      if (conflict == null) {
        _selected.add(created.offeringId);
        _pulseOfferingId = created.offeringId;
      }
    });
    if (conflict != null) {
      _showScheduleConflictSnack(conflict);
    } else {
      _scheduleAddedOfferingFeedback(created);
    }
  }

  void _popWithSelection() {
    final List<ParsedCourseOffering> out = _catalog
        .where((ParsedCourseOffering o) => _selected.contains(o.offeringId))
        .toList();
    Navigator.of(context).pop<List<ParsedCourseOffering>>(out);
  }

  Future<void> _pickChipFilter({
    required String title,
    required List<String> options,
    required String current,
    required void Function(String next) onPick,
    bool showSearch = false,
  }) async {
    final String? next = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      useSafeArea: true,
      builder: (BuildContext ctx) {
        return _TimetableFilterPickerSheet(
          title: "$title 선택",
          options: options,
          current: current,
          showSearch: showSearch,
        );
      },
    );
    if (next != null) onPick(next);
    setState(() {});
  }

  Future<void> _openSearchSheet() async {
    final String? q = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return _TimetableCourseSearchSheet(
          catalog: _catalog,
          initialQuery: _search,
        );
      },
    );
    if (q != null) setState(() => _search = q);
  }

  bool get _hasActiveFilters =>
      _search.isNotEmpty ||
      _deptFilter.isNotEmpty ||
      _gradeFilter.isNotEmpty ||
      _creditsFilter.isNotEmpty ||
      _completionFilter.isNotEmpty;

  void _resetFilters() {
    setState(() {
      _search = "";
      _deptFilter = "";
      _gradeFilter = "";
      _creditsFilter = "";
      _completionFilter = "";
    });
  }

  Set<String> _distinct(String Function(ParsedCourseOffering) pick) {
    return _catalog.map(pick).where((s) => s.isNotEmpty).toSet();
  }

  void _showRemoteOfferingPreviewSheet(ParsedCourseOffering o) {
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
                Text(
                  o.courseName,
                  style: TextStyle(
                    fontFamily: kPretendardFontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(ctx).colorScheme.onSurface,
                  ),
                ),
                Text(
                  o.professorSectionLine,
                  style: TextStyle(
                    fontFamily: kPretendardFontFamily,
                    fontSize: 14,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                TimetableOfferingScheduleTextBlock(offering: o),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text("닫기"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectedRemotePreview(BuildContext context) {
    final List<ParsedCourseOffering> items = _selectedRemoteExamOfferings;
    if (items.isEmpty) return const SizedBox.shrink();

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 10),
        Text(
          "선택한 원격 강의 · 대면 시험 (시간 그리드에는 표시되지 않음)",
          style: TextStyle(
            fontFamily: kPretendardFontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Material(
          key: _remotePreviewSectionKey,
          color: scheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
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
                  onTap: () => _showRemoteOfferingPreviewSheet(items[i]),
                  child: Stack(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          items[i].courseName,
                          style: TextStyle(
                            fontFamily: kPretendardFontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        if (items[i].sectionLabel.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            items[i].sectionLabel,
                            style: TextStyle(
                              fontFamily: kPretendardFontFamily,
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (items[i].slots.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            items[i].scheduleSummary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: kPretendardFontFamily,
                              fontSize: 11,
                              height: 1.35,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                        ),
                      ),
                      TimetableAddedOfferingPulseOverlay(
                        active: items[i].offeringId == _pulseOfferingId,
                        accent: Theme.of(context)
                            .extension<MjcComponentTokens>()!
                            .bottomNavSelected,
                        borderRadius: BorderRadius.zero,
                      ),
                    ],
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
  void dispose() {
    _pulseClearTimer?.cancel();
    _previewScrollController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  static const Color _kDirectAddLabelDark = Color(0xFFD4D4D4);

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _popWithSelection();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _popWithSelection,
          ),
          title: const Text("강의 추가"),
          actions: <Widget>[
            TextButton(
              onPressed: _openManualAdd,
              style: TextButton.styleFrom(
                foregroundColor:
                    isDark ? _kDirectAddLabelDark : scheme.primary,
              ),
              child: const Text("직접 추가"),
            ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: SizedBox(
                    height: _kPreviewViewportHeight,
                    child: Scrollbar(
                      controller: _previewScrollController,
                      child: SingleChildScrollView(
                        controller: _previewScrollController,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            TimetableWeekGrid(
                              slots: _previewSlots,
                              startHour: kTimetableGridStartHour,
                              endHour:
                                  timetableGridEndHourForSlots(_previewSlots),
                              hourHeight: _kPreviewHourHeight,
                              headerHeight: _kPreviewHeaderHeight,
                              compact: true,
                              pulseOfferingId: _pulseOfferingId,
                            ),
                            _buildSelectedRemotePreview(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                _buildFilterBar(context),
                Expanded(
                  child: ListView.separated(
                    controller: _listScrollController,
                    padding: EdgeInsets.fromLTRB(
                      12,
                      0,
                      12,
                      MjcFloatingCtaLayout.scrollBottomPadding(
                        context,
                        buttonHeight: MjcFloatingCtaLayout.compactHeight,
                      ),
                    ),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (BuildContext context, int i) {
                final ParsedCourseOffering o = _filtered[i];
                final bool on = _selected.contains(o.offeringId);
                final bool pulse = o.offeringId == _pulseOfferingId;
                final MjcComponentTokens components =
                    Theme.of(context).extension<MjcComponentTokens>()!;
                const BorderRadius cardRadius =
                    BorderRadius.all(Radius.circular(12));
                return Material(
                  key: pulse ? _highlightListItemKey : null,
                  color: scheme.surface,
                  elevation: 0.5,
                  shadowColor: Colors.black.withValues(alpha: 0.08),
                  clipBehavior: Clip.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: cardRadius,
                    side: BorderSide(
                      color: scheme.outline.withValues(alpha: 0.35),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: cardRadius,
                    child: Stack(
                      children: <Widget>[
                        InkWell(
                          onTap: () {
                            if (on) {
                              setState(() => _selected.remove(o.offeringId));
                              return;
                            }
                            _selectOffering(o);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  o.courseName,
                                  style: TextStyle(
                                    fontFamily: kPretendardFontFamily,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  o.professorSectionLine,
                                  style: TextStyle(
                                    fontFamily: kPretendardFontFamily,
                                    fontSize: 13,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  o.scheduleSummary,
                                  style: TextStyle(
                                    fontFamily: kPretendardFontFamily,
                                    fontSize: 12,
                                    height: 1.35,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${o.gradeYear.isEmpty ? "-" : "${o.gradeYear}학년"} · ${o.credits.isEmpty ? "-" : "${o.credits}학점"}",
                                  style: TextStyle(
                                    fontFamily: kPretendardFontFamily,
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Checkbox(
                            value: on,
                            onChanged: (bool? v) {
                              if (v == true) {
                                _selectOffering(o);
                              } else if (v == false) {
                                setState(() => _selected.remove(o.offeringId));
                              }
                            },
                          ),
                        ],
                            ),
                          ),
                        ),
                        TimetableAddedOfferingPulseOverlay(
                          active: pulse,
                          accent: components.bottomNavSelected,
                          borderRadius: cardRadius,
                        ),
                      ],
                    ),
                  ),
                );
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: MjcFloatingCtaLayout.positionedBottom(context),
              child: Center(
                child: MjcFloatingPillCta(
                  variant: MjcFloatingPillCtaVariant.primaryCompact,
                  label: "적용",
                  icon: Icons.check_rounded,
                  onTap: _popWithSelection,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const double _kFilterChipRadius = 12;
  static const double _kFilterChipElevation = 0.5;

  Widget _buildFilterResetChip(BuildContext context) {
    return _filterChipShell(
      context,
      selected: false,
      onTap: _resetFilters,
      tooltip: "필터·검색 초기화",
      child: const Icon(
        Icons.close_rounded,
        size: 18,
        color: Colors.red,
      ),
    );
  }

  /// 강의 목록 카드와 동일한 사각형 Material 스타일.
  Widget _filterChipShell(
    BuildContext context, {
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
    String? tooltip,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcComponentTokens components =
        Theme.of(context).extension<MjcComponentTokens>()!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = components.bottomNavSelected;
    final Color fill = selected
        ? accent.withValues(alpha: isDark ? 0.20 : 0.12)
        : scheme.surface;
    final Color borderColor = selected
        ? accent.withValues(alpha: isDark ? 0.35 : 0.28)
        : scheme.outline.withValues(alpha: 0.35);

    final Widget chip = Material(
      color: fill,
      elevation: _kFilterChipElevation,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kFilterChipRadius),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );

    if (tooltip == null) return chip;
    return Tooltip(message: tooltip, child: chip);
  }

  Widget _buildFilterBar(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcComponentTokens components =
        Theme.of(context).extension<MjcComponentTokens>()!;
    final Color accent = components.bottomNavSelected;

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        children: <Widget>[
          if (_hasActiveFilters) ...<Widget>[
            _buildFilterResetChip(context),
            const SizedBox(width: 8),
          ],
          _filterChipShell(
            context,
            selected: _search.isNotEmpty,
            onTap: _openSearchSheet,
            tooltip: _search.isEmpty ? "과목·교수 검색" : "검색: $_search",
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: _search.isNotEmpty
                      ? accent
                      : scheme.onSurfaceVariant,
                ),
                if (_search.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      _search,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kPretendardFontFamily,
                        color: accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _filterChip(
            context,
            label: "학과: ${_deptFilter.isEmpty ? "전체" : _deptFilter}",
            selected: _deptFilter.isNotEmpty,
            onTap: () => _pickChipFilter(
              title: "학과",
              options: _distinct((ParsedCourseOffering o) => o.department)
                  .toList()
                ..sort(),
              current: _deptFilter,
              onPick: (String n) => _deptFilter = n,
              showSearch: true,
            ),
          ),
          const SizedBox(width: 8),
          _filterChip(
            context,
            label: "학년: ${_gradeFilter.isEmpty ? "전체" : _gradeFilter}",
            selected: _gradeFilter.isNotEmpty,
            onTap: () => _pickChipFilter(
              title: "학년",
              options:
                  _distinct((ParsedCourseOffering o) => o.gradeYear).toList()
                    ..sort(),
              current: _gradeFilter,
              onPick: (String n) => _gradeFilter = n,
            ),
          ),
          const SizedBox(width: 8),
          _filterChip(
            context,
            label:
                "이수: ${_completionFilter.isEmpty ? "전체" : _completionFilter}",
            selected: _completionFilter.isNotEmpty,
            onTap: () => _pickChipFilter(
              title: "이수구분",
              options:
                  _distinct((ParsedCourseOffering o) => o.completionType)
                      .toList()
                    ..sort(),
              current: _completionFilter,
              onPick: (String n) => _completionFilter = n,
            ),
          ),
          const SizedBox(width: 8),
          _filterChip(
            context,
            label: "학점: ${_creditsFilter.isEmpty ? "전체" : _creditsFilter}",
            selected: _creditsFilter.isNotEmpty,
            onTap: () => _pickChipFilter(
              title: "학점",
              options:
                  _distinct((ParsedCourseOffering o) => o.credits).toList()
                    ..sort(),
              current: _creditsFilter,
              onPick: (String n) => _creditsFilter = n,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcComponentTokens components =
        Theme.of(context).extension<MjcComponentTokens>()!;
    final Color accent = components.bottomNavSelected;

    return _filterChipShell(
      context,
      selected: selected,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontFamily: kPretendardFontFamily,
              color: selected ? accent : scheme.onSurface,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: selected ? accent : scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

/// [showGlobalNoticeSearchSheet]와 동일한 바텀시트 검색 UI.
class _TimetableCourseSearchSheet extends StatefulWidget {
  const _TimetableCourseSearchSheet({
    required this.catalog,
    required this.initialQuery,
  });

  final List<ParsedCourseOffering> catalog;
  final String initialQuery;

  @override
  State<_TimetableCourseSearchSheet> createState() =>
      _TimetableCourseSearchSheetState();
}

class _TimetableCourseSearchSheetState extends State<_TimetableCourseSearchSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialQuery);

  static String _searchHaystack(ParsedCourseOffering o) {
    return "${o.courseName} ${o.professor} ${o.section}";
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyAndClose([String? query]) {
    Navigator.of(context).pop((query ?? _controller.text).trim());
  }

  @override
  Widget build(BuildContext context) {
    final String q = _controller.text.trim().toLowerCase();
    final List<ParsedCourseOffering> filtered = q.isEmpty
        ? widget.catalog
        : widget.catalog
            .where(
              (ParsedCourseOffering o) =>
                  _searchHaystack(o).toLowerCase().contains(q),
            )
            .toList();

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color sheetBackground = isDark
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainerLow;
    final Color cardBackground = scheme.surface;
    final Color searchFieldBackground = isDark
        ? scheme.surfaceContainerHighest
        : scheme.surface;
    final EdgeInsets viewInsets = MediaQuery.viewInsetsOf(context);
    final double availableHeight =
        MediaQuery.sizeOf(context).height - viewInsets.bottom;
    final double sheetHeight = availableHeight * 0.72;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Material(
        color: sheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: sheetHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        "과목·교수 검색",
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      tooltip: "닫기",
                      onPressed: _applyAndClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                Text(
                  "검색 범위: 강의 목록",
                  style: TextStyle(
                    fontFamily: kPretendardFontFamily,
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: _applyAndClose,
                  textInputAction: TextInputAction.search,
                  style: TextStyle(
                    fontFamily: kPretendardFontFamily,
                    color: scheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: "검색어 입력",
                    hintStyle: TextStyle(
                      fontFamily: kPretendardFontFamily,
                      color: scheme.onSurfaceVariant,
                    ),
                    filled: true,
                    fillColor: searchFieldBackground,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: "지우기",
                            onPressed: () {
                              _controller.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear_rounded),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            "검색 결과가 없습니다.",
                            style: TextStyle(
                              fontFamily: kPretendardFontFamily,
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (BuildContext context, int i) {
                            final ParsedCourseOffering o = filtered[i];
                            return Material(
                              color: cardBackground,
                              elevation: 0.5,
                              shadowColor:
                                  Colors.black.withValues(alpha: 0.08),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: scheme.outline
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => _applyAndClose(o.courseName),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        o.courseName,
                                        style: TextStyle(
                                          fontFamily: kPretendardFontFamily,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: scheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        o.professorSectionLine,
                                        style: TextStyle(
                                          fontFamily: kPretendardFontFamily,
                                          fontSize: 13,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        o.scheduleSummary,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: kPretendardFontFamily,
                                          fontSize: 12,
                                          height: 1.35,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 강의 필터(학과·학년 등) 단일 선택 바텀시트 — 라디오 + 검색 + 더보기.
class _TimetableFilterPickerSheet extends StatefulWidget {
  const _TimetableFilterPickerSheet({
    required this.title,
    required this.options,
    required this.current,
    this.showSearch = false,
  });

  final String title;
  final List<String> options;
  final String current;
  final bool showSearch;

  @override
  State<_TimetableFilterPickerSheet> createState() =>
      _TimetableFilterPickerSheetState();
}

class _TimetableFilterPickerSheetState
    extends State<_TimetableFilterPickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isSearching =>
      widget.showSearch && _searchController.text.trim().isNotEmpty;

  List<String> get _filteredOptions {
    if (!widget.showSearch) return widget.options;
    final String q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options
        .where((String o) => o.toLowerCase().contains(q))
        .toList();
  }

  void _pick(String value) {
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcComponentTokens components =
        Theme.of(context).extension<MjcComponentTokens>()!;
    final Color accent = components.bottomNavSelected;
    final EdgeInsets viewInsets = MediaQuery.viewInsetsOf(context);
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    final Color searchFillColor =
        Theme.of(context).brightness == Brightness.light
            ? scheme.surfaceContainerLow
            : scheme.surfaceContainerHigh;

    final bool showAllOption = !_isSearching ||
        "전체".contains(_searchController.text.trim().toLowerCase());

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Material(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          widget.title,
                          style: TextStyle(
                            fontFamily: kPretendardFontFamily,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: "닫기",
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.showSearch)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: searchFillColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      style: TextStyle(
                        fontFamily: kPretendardFontFamily,
                        color: scheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: "학과 검색",
                        hintStyle: TextStyle(
                          fontFamily: kPretendardFontFamily,
                          color: scheme.onSurfaceVariant,
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: "지우기",
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.clear_rounded),
                              ),
                      ),
                    ),
                  ),
                ),
              Flexible(
                child: _filteredOptions.isEmpty && !showAllOption
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            "검색 결과가 없습니다.",
                            style: TextStyle(
                              fontFamily: kPretendardFontFamily,
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                        children: <Widget>[
                          if (showAllOption)
                            _FilterRadioTile(
                              value: "",
                              groupValue: widget.current,
                              label: "전체",
                              accent: accent,
                              onTap: () => _pick(""),
                            ),
                          for (final String o in _filteredOptions)
                            _FilterRadioTile(
                              value: o,
                              groupValue: widget.current,
                              label: o.isEmpty ? "(빈 값)" : o,
                              accent: accent,
                              onTap: () => _pick(o),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterRadioTile extends StatelessWidget {
  const _FilterRadioTile({
    required this.value,
    required this.groupValue,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final String value;
  final String groupValue;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  bool get _selected => value == groupValue;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            _FilterRadioIndicator(
              selected: _selected,
              accent: accent,
              unselectedColor: scheme.outline,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: kPretendardFontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterRadioIndicator extends StatelessWidget {
  const _FilterRadioIndicator({
    required this.selected,
    required this.accent,
    required this.unselectedColor,
  });

  final bool selected;
  final Color accent;
  final Color unselectedColor;

  static const double _size = 20;
  static const double _dotSize = 8;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? accent : Colors.transparent,
          border: selected
              ? null
              : Border.all(color: unselectedColor, width: 1.5),
        ),
        child: selected
            ? Center(
                child: Container(
                  width: _dotSize,
                  height: _dotSize,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
