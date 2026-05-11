import "package:flutter/material.dart";
import "package:mio_notice/features/timetable/models/timetable_models.dart";
import "package:mio_notice/features/timetable/widgets/timetable_manual_entry_sheet.dart";
import "package:mio_notice/features/timetable/widgets/timetable_week_grid.dart";
import "package:mio_notice/theme/app_theme.dart";

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

  @override
  void initState() {
    super.initState();
    _catalog = List<ParsedCourseOffering>.from(widget.catalog);
    _selected = Set<String>.from(widget.initialSelectedOfferingIds);
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
      if (_gradeFilter.isNotEmpty && o.gradeYear != _gradeFilter) return false;
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
      if (_selected.contains(o.offeringId)) {
        out.addAll(o.slots);
      }
    }
    return out;
  }

  Future<void> _openManualAdd() async {
    final ParsedCourseOffering? created =
        await showTimetableManualEntrySheet(context);
    if (!mounted || created == null) return;
    setState(() {
      _catalog = <ParsedCourseOffering>[..._catalog, created];
      _selected.add(created.offeringId);
    });
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

  Set<String> _distinct(String Function(ParsedCourseOffering) pick) {
    return _catalog.map(pick).where((s) => s.isNotEmpty).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text("강의 추가"),
        actions: <Widget>[
          TextButton(
            onPressed: _openManualAdd,
            child: const Text("직접 추가"),
          ),
          TextButton(
            onPressed: () {
              final List<ParsedCourseOffering> out = _catalog
                  .where((ParsedCourseOffering o) => _selected.contains(o.offeringId))
                  .toList();
              Navigator.of(context).pop<List<ParsedCourseOffering>>(out);
            },
            child: const Text("적용"),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TimetableWeekGrid(
              slots: _previewSlots,
              hourHeight: 28,
              headerHeight: 22,
              compact: true,
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              children: <Widget>[
                _chip(
                  context,
                  label: "학과: ${_deptFilter.isEmpty ? "전체" : _deptFilter}",
                  onTap: () => _pickChipFilter(
                    title: "학과",
                    options: _distinct((ParsedCourseOffering o) => o.department)
                        .toList()
                      ..sort(),
                    current: _deptFilter,
                    onPick: (String n) => _deptFilter = n,
                  ),
                ),
                _chip(
                  context,
                  label: "검색",
                  onTap: () async {
                    final String? q = await showDialog<String>(
                      context: context,
                      builder: (BuildContext ctx) {
                        final TextEditingController c =
                            TextEditingController(text: _search);
                        return AlertDialog(
                          title: const Text("과목·교수 검색"),
                          content: TextField(
                            controller: c,
                            decoration: const InputDecoration(
                              hintText: "검색어",
                            ),
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
                  },
                ),
                _chip(
                  context,
                  label: "학년: ${_gradeFilter.isEmpty ? "전체" : _gradeFilter}",
                  onTap: () => _pickChipFilter(
                    title: "학년",
                    options: _distinct((ParsedCourseOffering o) => o.gradeYear)
                        .toList()
                      ..sort(),
                    current: _gradeFilter,
                    onPick: (String n) => _gradeFilter = n,
                  ),
                ),
                _chip(
                  context,
                  label: "학점: ${_creditsFilter.isEmpty ? "전체" : _creditsFilter}",
                  onTap: () => _pickChipFilter(
                    title: "학점",
                    options: _distinct((ParsedCourseOffering o) => o.credits)
                        .toList()
                      ..sort(),
                    current: _creditsFilter,
                    onPick: (String n) => _creditsFilter = n,
                  ),
                ),
                _chip(
                  context,
                  label:
                      "이수: ${_completionFilter.isEmpty ? "전체" : _completionFilter}",
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
              ],
            ),
          ),
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
                      setState(() {
                        if (on) {
                          _selected.remove(o.offeringId);
                        } else {
                          _selected.add(o.offeringId);
                        }
                      });
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
                              setState(() {
                                if (v == true) {
                                  _selected.add(o.offeringId);
                                } else {
                                  _selected.remove(o.offeringId);
                                }
                              });
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
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(
          label,
          style: const TextStyle(
            fontFamily: kPretendardFontFamily,
            fontSize: 12,
          ),
        ),
        onPressed: onTap,
      ),
    );
  }
}
