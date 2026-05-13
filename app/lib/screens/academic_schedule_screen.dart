import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:mio_notice/features/academic_schedule/domain/academic_schedule_classifier.dart";
import "package:mio_notice/features/academic_schedule/domain/academic_schedule_kind.dart";
import "package:mio_notice/features/academic_schedule/presentation/academic_schedule_visuals.dart";
import "package:mio_notice/screens/common_webview_screen.dart";
import "package:mio_notice/services/notice_manager.dart";
import "package:mio_notice/theme/app_colors.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";

class AcademicScheduleScreen extends StatefulWidget {
  const AcademicScheduleScreen({super.key});

  @override
  State<AcademicScheduleScreen> createState() => _AcademicScheduleScreenState();
}

class _AcademicScheduleScreenState extends State<AcademicScheduleScreen> {
  late Future<List<Map<String, dynamic>>> _scheduleFuture;
  String? _selectedSemester;
  bool _calendarView = false;
  DateTime? _focusedMonth;
  DateTime? _selectedDate;

  static const String _prefCalendarView = "academic_schedule_calendar_view";

  DateTime get _today => DateTime.now();
  DateTime get _todayDateOnly => DateTime(_today.year, _today.month, _today.day);
  DateTime get _todayMonthOnly => DateTime(_today.year, _today.month);

  @override
  void initState() {
    super.initState();
    _scheduleFuture = NoticeManager().getNotices(boardId: "main_schedule");
    _loadViewPreference();
  }

  Future<void> _loadViewPreference() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool calendar = prefs.getBool(_prefCalendarView) ?? false;
      if (!mounted) return;
      setState(() {
        _calendarView = calendar;
        if (_calendarView) {
          _focusedMonth ??= _todayMonthOnly;
          _selectedDate ??= _todayDateOnly;
        }
      });
    } catch (_) {
      // ignore: if prefs fail, default remains list view
    }
  }

  Future<void> _setCalendarView(bool value) async {
    setState(() {
      _calendarView = value;
      if (_calendarView) {
        _focusedMonth ??= _todayMonthOnly;
        _selectedDate ??= _todayDateOnly;
      }
    });
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefCalendarView, value);
    } catch (_) {
      // ignore
    }
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("학사일정"),
        actions: [
          IconButton(
            tooltip: _calendarView ? "목록 보기" : "캘린더 보기",
            icon: Icon(
              _calendarView
                  ? Icons.view_list_rounded
                  : Icons.calendar_month_rounded,
            ),
            onPressed: () => _setCalendarView(!_calendarView),
          ),
        ],
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

            if (_calendarView) {
              return _CalendarView(
                items: items,
                focusedMonth: _focusedMonth,
                selectedDate: _selectedDate,
                onMonthChanged: (month) {
                  setState(() {
                    _focusedMonth = month;
                    _selectedDate = null;
                  });
                },
                onDateSelected: (date) {
                  setState(() => _selectedDate = date);
                },
              );
            }

            final Map<String, List<Map<String, dynamic>>> byMonth = {};
            for (final Map<String, dynamic> item in visible) {
              final String key = _yearMonthKey(item);
              byMonth.putIfAbsent(key, () => []).add(item);
            }
            final List<String> months = byMonth.keys.toList()
              ..sort((a, b) => _compareYearMonthKey(a, b));

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
                  _MonthHeader(yearMonth: month),
                  const SizedBox(height: 8),
                  ...byMonth[month]!.map(ScheduleTile.new),
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

  String _yearMonthKey(Map<String, dynamic> item) {
    final String raw = (item["start_date"] ?? item["date"] ?? "").toString();
    final RegExpMatch? m = RegExp(r"^(\d{4})-(\d{2})-\d{2}").firstMatch(raw);
    if (m != null) {
      return "${m.group(1)}-${m.group(2)}";
    }

    final String month = (item["month"] ?? _monthFromDate(item)).toString();
    final String year = (item["year"] ?? "").toString();
    if (year.isNotEmpty) {
      return "$year-${month.padLeft(2, "0")}";
    }

    return "0000-${month.padLeft(2, "0")}";
  }

  int _compareYearMonthKey(String a, String b) {
    final DateTime? da = _parseYearMonthKey(a);
    final DateTime? db = _parseYearMonthKey(b);
    if (da == null && db == null) return a.compareTo(b);
    if (da == null) return -1;
    if (db == null) return 1;
    return da.compareTo(db);
  }

  DateTime? _parseYearMonthKey(String key) {
    final RegExpMatch? m = RegExp(r"^(\d{4})-(\d{2})$").firstMatch(key);
    if (m == null) return null;
    final int? y = int.tryParse(m.group(1)!);
    final int? mo = int.tryParse(m.group(2)!);
    if (y == null || mo == null) return null;
    return DateTime(y, mo);
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.yearMonth});

  final String yearMonth;

  @override
  Widget build(BuildContext context) {
    final RegExpMatch? m =
        RegExp(r"^(\d{4})-(\d{2})$").firstMatch(yearMonth);
    final String label = m == null
        ? "${yearMonth.toString().padLeft(2, "0")}월"
        : "${m.group(1)}년 ${int.parse(m.group(2)!)}월";
    return Text(
      label,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: AppColors.primary,
      ),
    );
  }
}

class ScheduleTile extends StatelessWidget {
  const ScheduleTile(this.item, {super.key});

  final Map<String, dynamic> item;

  AcademicScheduleKind _kindOf() {
    final AcademicScheduleKind? fromTag =
        AcademicScheduleKind.tryParse(item["schedule_kind"]?.toString());
    return fromTag ?? AcademicScheduleClassifier.kindOf(item);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String title = (item["title"] ?? "").toString();
    final String start = (item["start_date"] ?? item["date"] ?? "").toString();
    final String end = (item["end_date"] ?? start).toString();
    final String url = (item["url"] ?? "").toString();
    final AcademicScheduleKind kind = _kindOf();
    final AcademicScheduleVisuals visuals = AcademicScheduleVisuals.of(
      context,
      kind,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surface,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
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
                    color: visuals.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    visuals.icon,
                    color: visuals.iconColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatRange(start, end),
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
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

class _CalendarView extends StatelessWidget {
  const _CalendarView({
    required this.items,
    required this.focusedMonth,
    required this.selectedDate,
    required this.onMonthChanged,
    required this.onDateSelected,
  });

  final List<Map<String, dynamic>> items;
  final DateTime? focusedMonth;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime?> onDateSelected;

  static DateTime? _parseDate(String raw) {
    final RegExpMatch? m =
        RegExp(r"^(\d{4})-(\d{2})-(\d{2})").firstMatch(raw);
    if (m == null) return null;
    final int? y = int.tryParse(m.group(1)!);
    final int? mo = int.tryParse(m.group(2)!);
    final int? d = int.tryParse(m.group(3)!);
    if (y == null || mo == null || d == null) return null;
    return DateTime(y, mo, d);
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  @override
  Widget build(BuildContext context) {
    final List<({DateTime start, DateTime end, Map<String, dynamic> item})>
        ranges = [];
    for (final Map<String, dynamic> item in items) {
      final DateTime? s =
          _parseDate((item["start_date"] ?? item["date"] ?? "").toString());
      if (s == null) continue;
      final DateTime e = _parseDate(
            (item["end_date"] ?? item["start_date"] ?? item["date"] ?? "")
                .toString(),
          ) ??
          s;
      ranges.add((start: s, end: e.isBefore(s) ? s : e, item: item));
    }

    DateTime focused = focusedMonth ??
        DateTime(DateTime.now().year, DateTime.now().month);
    focused = DateTime(focused.year, focused.month);

    final DateTime monthStart = focused;
    final DateTime monthEnd = DateTime(focused.year, focused.month + 1, 0);

    final List<Map<String, dynamic>> dayItems = selectedDate == null
        ? const []
        : ranges
            .where((r) =>
                !selectedDate!.isBefore(r.start) &&
                !selectedDate!.isAfter(r.end))
            .map((r) => r.item)
            .toList();

    final List<Map<String, dynamic>> monthItems = ranges
        .where((r) =>
            !r.end.isBefore(monthStart) && !r.start.isAfter(monthEnd))
        .map((r) => r.item)
        .toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _CalendarGrid(
          focusedMonth: focused,
          selectedDate: selectedDate,
          ranges: ranges,
          onPrev: () =>
              onMonthChanged(DateTime(focused.year, focused.month - 1)),
          onNext: () =>
              onMonthChanged(DateTime(focused.year, focused.month + 1)),
          onDateTap: (date) {
            if (selectedDate != null && _dateOnly(selectedDate!) == date) {
              onDateSelected(null);
            } else {
              onDateSelected(date);
            }
          },
        ),
        const SizedBox(height: 18),
        if (selectedDate != null) ...[
          Row(
            children: [
              Text(
                "${selectedDate!.year}년 "
                "${selectedDate!.month}월 ${selectedDate!.day}일",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              if (dayItems.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    "${dayItems.length}건",
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (dayItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  "선택한 날짜에 일정이 없습니다.",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            ...dayItems.map(ScheduleTile.new),
        ] else ...[
          Row(
            children: [
              Text(
                "${focused.year}년 ${focused.month}월 일정",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              if (monthItems.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    "${monthItems.length}건",
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (monthItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  "이 달에는 일정이 없습니다.",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            ...monthItems.map(ScheduleTile.new),
        ],
      ],
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.focusedMonth,
    required this.selectedDate,
    required this.ranges,
    required this.onPrev,
    required this.onNext,
    required this.onDateTap,
  });

  final DateTime focusedMonth;
  final DateTime? selectedDate;
  final List<({DateTime start, DateTime end, Map<String, dynamic> item})>
      ranges;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onDateTap;

  AcademicScheduleKind _kindOf(Map<String, dynamic> item) {
    final AcademicScheduleKind? fromTag =
        AcademicScheduleKind.tryParse(item["schedule_kind"]?.toString());
    return fromTag ?? AcademicScheduleClassifier.kindOf(item);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final DateTime first = focusedMonth;
    final int leadingBlanks = first.weekday % 7; // Sunday=0
    final int daysInMonth =
        DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final int totalCells =
        ((leadingBlanks + daysInMonth) / 7).ceil() * 7;
    final DateTime today = _CalendarView._dateOnly(DateTime.now());
    final DateTime? selDay =
        selectedDate == null ? null : _CalendarView._dateOnly(selectedDate!);

    const List<String> dayLabels = ["일", "월", "화", "수", "목", "금", "토"];

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: "이전 달",
              ),
              Expanded(
                child: Center(
                  child: Text(
                    "${focusedMonth.year}년 ${focusedMonth.month}월",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: "다음 달",
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: List<Widget>.generate(7, (i) {
              final Color color = i == 0
                  ? Colors.redAccent
                  : (i == 6 ? AppColors.primary : scheme.onSurfaceVariant);
              return Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      dayLabels[i],
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (context, index) {
              final int dayNum = index - leadingBlanks + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const SizedBox.shrink();
              }
              final DateTime date =
                  DateTime(focusedMonth.year, focusedMonth.month, dayNum);
              final List<({DateTime start, DateTime end, Map<String, dynamic> item})>
                  hits = ranges
                      .where((r) =>
                          !date.isBefore(r.start) && !date.isAfter(r.end))
                      .toList();
              final bool hasEvent = hits.isNotEmpty;
              final bool isSelected = selDay != null && selDay == date;
              final List<Map<String, dynamic>> hitItems =
                  hits.map((h) => h.item).toList();
              final List<AcademicScheduleKind> kinds = hitItems
                  .map(_kindOf)
                  .toList()
                ..sort((a, b) => AcademicScheduleVisuals.priority(a)
                    .compareTo(AcademicScheduleVisuals.priority(b)));

              final List<AcademicScheduleKind> uniqueKinds = <AcademicScheduleKind>[];
              for (final k in kinds) {
                if (!uniqueKinds.contains(k)) uniqueKinds.add(k);
                if (uniqueKinds.length >= 3) break;
              }

              final bool hasImportant =
                  uniqueKinds.any(AcademicScheduleVisuals.isImportant);
              final List<Color> dotColors = uniqueKinds.map((k) {
                if (isSelected) return Colors.white;
                return AcademicScheduleVisuals.of(context, k).dotColor;
              }).toList();
              final bool isToday = date == today;
              final int weekday = index % 7;
              final Color textColor = isSelected
                  ? Colors.white
                  : (weekday == 0
                      ? Colors.redAccent
                      : (weekday == 6
                          ? AppColors.primary
                          : scheme.onSurface));
              return InkWell(
                onTap: () => onDateTap(date),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : (hasEvent
                              ? AcademicScheduleVisuals.calendarDayBackground(
                                  context: context,
                                  hasEvent: hasEvent,
                                  hasImportant: hasImportant,
                                )
                              : Colors.transparent),
                      borderRadius: BorderRadius.circular(10),
                      border: isToday && !isSelected
                          ? Border.all(
                              color: AppColors.primary.withValues(alpha: 0.55),
                              width: 1.2,
                            )
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "$dayNum",
                          style: TextStyle(
                            color: textColor,
                            fontWeight: hasEvent || isSelected || isToday
                                ? FontWeight.w800
                                : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        if (hasEvent)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List<Widget>.generate(
                              dotColors.length.clamp(1, 3),
                              (i) => Padding(
                                padding: EdgeInsets.only(
                                    left: i == 0 ? 0 : 3),
                                child: Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: dotColors[i],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
