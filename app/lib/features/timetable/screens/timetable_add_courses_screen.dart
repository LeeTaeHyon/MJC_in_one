import "package:flutter/material.dart";
import "package:mjc_in_one/features/timetable/models/timetable_models.dart";
import "package:mjc_in_one/features/timetable/widgets/timetable_manual_entry_sheet.dart";
import "package:mjc_in_one/features/timetable/widgets/timetable_offering_schedule_text_block.dart";
import "package:mjc_in_one/features/timetable/widgets/timetable_week_grid.dart";
import "package:mjc_in_one/mpu_profile_prefs.dart";
import "package:mjc_in_one/theme/app_theme.dart";

/// Top preview grid + filter chips + course list (Everytime-like flow).
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            snackMessage,
            style: const TextStyle(fontFamily: kPretendardFontFamily),
          ),
        ),
      );
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
            !o.professor.toLowerCase().contains(q)) {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "이미 선택한 강의와 수업 시간이 겹칩니다: ${conflictsWith.courseName}",
          style: const TextStyle(fontFamily: kPretendardFontFamily),
        ),
      ),
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
      }
    });
    if (conflict != null) {
      _showScheduleConflictSnack(conflict);
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
  }) async {
    final String? next = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: ListView(
            children: <Widget>[
              ListTile(
                title: const Text("전체"),
                onTap: () => Navigator.pop(ctx, ""),
              ),
              for (final String o in options)
                ListTile(
                  title: Text(o.isEmpty ? "(빈 값)" : o),
                  onTap: () => Navigator.pop(ctx, o),
                ),
            ],
          ),
        );
      },
    );
    if (next != null) onPick(next);
    setState(() {});
  }

  Future<void> _openSearchDialog() async {
    final String? q = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        final TextEditingController c = TextEditingController(text: _search);
        return AlertDialog(
          title: const Text("과목·교수 검색"),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(hintText: "검색어"),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, ""),
              child: const Text("지우기"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text("확인"),
            ),
          ],
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
                  child: Padding(
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
    _previewScrollController.dispose();
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
        body: Column(
          children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SizedBox(
              height: 340,
              child: Scrollbar(
                controller: _previewScrollController,
                child: SingleChildScrollView(
                  controller: _previewScrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TimetableWeekGrid(
                        slots: _previewSlots,
                        startHour: 9,
                        endHour: 18,
                        hourHeight: 44,
                        headerHeight: 22,
                        compact: true,
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
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (BuildContext context, int i) {
                final ParsedCourseOffering o = _filtered[i];
                final bool on = _selected.contains(o.offeringId);
                return Material(
                  color: scheme.surface,
                  elevation: 0.5,
                  shadowColor: Colors.black.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (on) {
                        setState(() => _selected.remove(o.offeringId));
                        return;
                      }
                      final ParsedCourseOffering? conflict =
                          _firstScheduleConflict(o);
                      if (conflict != null) {
                        _showScheduleConflictSnack(conflict);
                        return;
                      }
                      setState(() => _selected.add(o.offeringId));
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
                                  o.professor.isEmpty ? "교수 미상" : o.professor,
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
                                final ParsedCourseOffering? conflict =
                                    _firstScheduleConflict(o);
                                if (conflict != null) {
                                  _showScheduleConflictSnack(conflict);
                                  return;
                                }
                                setState(() => _selected.add(o.offeringId));
                              } else if (v == false) {
                                setState(() => _selected.remove(o.offeringId));
                              }
                            },
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
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: FilledButton(
              onPressed: _popWithSelection,
              child: const Text("적용"),
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterPillShell(BuildContext context, {required Widget child}) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcComponentTokens components =
        Theme.of(context).extension<MjcComponentTokens>()!;
    final MjcSurfaceTokens surfaceTokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: scheme.surface.withValues(alpha: isDark ? 0.98 : 0.96),
      elevation: 10,
      shadowColor: components.noticeSubNavShadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: surfaceTokens.hairline, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: child,
      ),
    );
  }

  /// [MainNavigationScreen._buildNoticeSubNav]와 동일한 플로팅 pill 바 스타일.
  Widget _buildFilterBar(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcComponentTokens components =
        Theme.of(context).extension<MjcComponentTokens>()!;

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        children: <Widget>[
          if (_hasActiveFilters) ...<Widget>[
            _filterPillShell(
              context,
              child: Tooltip(
                message: "필터·검색 초기화",
                child: InkWell(
                  onTap: _resetFilters,
                  borderRadius: BorderRadius.circular(28),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          _filterPillShell(
            context,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Tooltip(
                  message:
                      _search.isEmpty ? "과목·교수 검색" : "검색: $_search",
                  child: _pillSegment(
                    context,
                    selected: _search.isNotEmpty,
                    onTap: _openSearchDialog,
                    padding: EdgeInsets.symmetric(
                      horizontal: _search.isEmpty ? 10 : 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: _search.isNotEmpty
                              ? components.bottomNavSelected
                              : scheme.onSurfaceVariant,
                        ),
                        if (_search.isNotEmpty) ...<Widget>[
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 140),
                            child: Text(
                              _search,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: kPretendardFontFamily,
                                color: components.bottomNavSelected,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                _filterPill(
                    context,
                    label:
                        "학과: ${_deptFilter.isEmpty ? "전체" : _deptFilter}",
                    selected: _deptFilter.isNotEmpty,
                    onTap: () => _pickChipFilter(
                      title: "학과",
                      options:
                          _distinct((ParsedCourseOffering o) => o.department)
                              .toList()
                        ..sort(),
                      current: _deptFilter,
                      onPick: (String n) => _deptFilter = n,
                    ),
                  ),
                  _filterPill(
                    context,
                    label:
                        "학년: ${_gradeFilter.isEmpty ? "전체" : _gradeFilter}",
                    selected: _gradeFilter.isNotEmpty,
                    onTap: () => _pickChipFilter(
                      title: "학년",
                      options:
                          _distinct((ParsedCourseOffering o) => o.gradeYear)
                              .toList()
                        ..sort(),
                      current: _gradeFilter,
                      onPick: (String n) => _gradeFilter = n,
                    ),
                  ),
                  _filterPill(
                    context,
                    label:
                        "이수: ${_completionFilter.isEmpty ? "전체" : _completionFilter}",
                    selected: _completionFilter.isNotEmpty,
                    onTap: () => _pickChipFilter(
                      title: "이수구분",
                      options: _distinct(
                        (ParsedCourseOffering o) => o.completionType,
                      ).toList()
                        ..sort(),
                      current: _completionFilter,
                      onPick: (String n) => _completionFilter = n,
                    ),
                  ),
                  _filterPill(
                    context,
                    label:
                        "학점: ${_creditsFilter.isEmpty ? "전체" : _creditsFilter}",
                    selected: _creditsFilter.isNotEmpty,
                    onTap: () => _pickChipFilter(
                      title: "학점",
                      options:
                          _distinct((ParsedCourseOffering o) => o.credits)
                              .toList()
                        ..sort(),
                      current: _creditsFilter,
                      onPick: (String n) => _creditsFilter = n,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterPill(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcComponentTokens components =
        Theme.of(context).extension<MjcComponentTokens>()!;
    final Color accent = components.bottomNavSelected;

    return _pillSegment(
      context,
      selected: selected,
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: kPretendardFontFamily,
          color: selected ? accent : scheme.onSurfaceVariant,
          fontSize: 13,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
        ),
      ),
    );
  }

  Widget _pillSegment(
    BuildContext context, {
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  }) {
    final MjcComponentTokens components =
        Theme.of(context).extension<MjcComponentTokens>()!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = components.bottomNavSelected;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        padding: padding,
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: isDark ? 0.20 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          border: selected
              ? Border.all(
                  color: accent.withValues(alpha: isDark ? 0.35 : 0.18),
                )
              : null,
        ),
        child: child,
      ),
    );
  }
}
