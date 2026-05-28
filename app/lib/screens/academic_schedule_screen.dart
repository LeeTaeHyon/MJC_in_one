import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:mjc_in_one/features/academic_schedule/domain/academic_schedule_classifier.dart";
import "package:mjc_in_one/features/academic_schedule/domain/academic_schedule_kind.dart";
import "package:mjc_in_one/features/academic_schedule/presentation/academic_schedule_visuals.dart";
import "package:mjc_in_one/screens/common_webview_screen.dart";
import "package:mjc_in_one/services/notice_manager.dart";
import "package:mjc_in_one/theme/app_colors.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";

const Color _kScheduleSectionTitleLight = Color(0xFF374151);
const Color _kScheduleSectionTitleDark = Color(0xFFF5F5F5);

class AcademicScheduleScreen extends StatefulWidget {
  const AcademicScheduleScreen({super.key});

  @override
  State<AcademicScheduleScreen> createState() => _AcademicScheduleScreenState();
}

class _AcademicScheduleScreenState extends State<AcademicScheduleScreen> {
  late Future<List<Map<String, dynamic>>> _scheduleFuture;
  String? _selectedSemester;
  bool _calendarView = true;
  DateTime? _focusedMonth;
  DateTime? _selectedDate;

  static const String _prefCalendarView = "academic_schedule_calendar_view";

  DateTime get _today => DateTime.now();
  DateTime get _todayDateOnly => DateTime(_today.year, _today.month, _today.day);
  DateTime get _todayMonthOnly => DateTime(_today.year, _today.month);

  @override
  void initState() {
    super.initState();
    _focusedMonth = _todayMonthOnly;
    _selectedDate = _todayDateOnly;
    _scheduleFuture = NoticeManager().getNotices(boardId: "main_schedule");
    _loadViewPreference();
  }

  Future<void> _loadViewPreference() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool calendar = prefs.getBool(_prefCalendarView) ?? true;
      if (!mounted) return;
      setState(() {
        _calendarView = calendar;
        if (_calendarView) {
          _focusedMonth ??= _todayMonthOnly;
          _selectedDate ??= _todayDateOnly;
        }
      });
    } catch (_) {
      // ignore: if prefs fail, default remains calendar view
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
                  SegmentedButton<String>(
                    expandedInsets: EdgeInsets.zero,
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color sectionTitleColor =
        isDark ? _kScheduleSectionTitleDark : _kScheduleSectionTitleLight;
    final RegExpMatch? m =
        RegExp(r"^(\d{4})-(\d{2})$").firstMatch(yearMonth);
    final String label = m == null
        ? "${yearMonth.toString().padLeft(2, "0")}월"
        : "${m.group(1)}년 ${int.parse(m.group(2)!)}월";
    return Text(
      label,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: sectionTitleColor,
      ),
    );
  }
}

class ScheduleTile extends StatelessWidget {
  const ScheduleTile(this.item, {super.key});

  final Map<String, dynamic> item;

  AcademicScheduleKind _kindOf() => AcademicScheduleClassifier.kindOf(item);

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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color sectionTitleColor =
        isDark ? _kScheduleSectionTitleDark : _kScheduleSectionTitleLight;

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
        _SwipeableCalendarGrid(
          focusedMonth: focused,
          selectedDate: selectedDate,
          ranges: ranges,
          onMonthChanged: onMonthChanged,
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: sectionTitleColor,
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: sectionTitleColor,
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

class _SwipeableCalendarGrid extends StatefulWidget {
  const _SwipeableCalendarGrid({
    required this.focusedMonth,
    required this.selectedDate,
    required this.ranges,
    required this.onMonthChanged,
    required this.onDateTap,
  });

  final DateTime focusedMonth;
  final DateTime? selectedDate;
  final List<({DateTime start, DateTime end, Map<String, dynamic> item})>
      ranges;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateTap;

  @override
  State<_SwipeableCalendarGrid> createState() => _SwipeableCalendarGridState();
}

class _SwipeableCalendarGridState extends State<_SwipeableCalendarGrid> {
  static const int _initialPage = 12000;
  static const Duration _pageAnimDuration = Duration(milliseconds: 280);
  static const Curve _pageAnimCurve = Curves.easeOutCubic;
  static const double _gridAspectRatio = 0.85;
  static const int _maxWeekRows = 6;

  late final PageController _pageController;
  late final DateTime _baseMonth;

  @override
  void initState() {
    super.initState();
    _baseMonth =
        DateTime(widget.focusedMonth.year, widget.focusedMonth.month);
    _pageController = PageController(initialPage: _initialPage);
  }

  @override
  void didUpdateWidget(covariant _SwipeableCalendarGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final DateTime oldMonth =
        DateTime(oldWidget.focusedMonth.year, oldWidget.focusedMonth.month);
    final DateTime nextMonth =
        DateTime(widget.focusedMonth.year, widget.focusedMonth.month);
    if (oldMonth == nextMonth) return;

    final int currentPage = _pageController.hasClients
        ? (_pageController.page?.round() ?? _initialPage)
        : _initialPage;
    final DateTime displayedMonth = _monthAt(currentPage);
    if (displayedMonth.year == nextMonth.year &&
        displayedMonth.month == nextMonth.month) {
      return;
    }

    final int targetPage = _initialPage + _monthOffset(nextMonth);
    if (_pageController.hasClients) {
      _pageController.jumpToPage(targetPage);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _monthOffset(DateTime month) {
    return (month.year - _baseMonth.year) * 12 +
        (month.month - _baseMonth.month);
  }

  DateTime _monthAt(int page) {
    return DateTime(_baseMonth.year, _baseMonth.month + (page - _initialPage));
  }

  double _pageHeight(double width) {
    const double weekdayRowHeight = 30;
    final double cellWidth = width / 7;
    final double cellHeight = cellWidth / _gridAspectRatio;
    return weekdayRowHeight + _maxWeekRows * cellHeight;
  }

  void _goToPreviousMonth() {
    _pageController.previousPage(
      duration: _pageAnimDuration,
      curve: _pageAnimCurve,
    );
  }

  void _goToNextMonth() {
    _pageController.nextPage(
      duration: _pageAnimDuration,
      curve: _pageAnimCurve,
    );
  }

  void _handlePageChanged(int page) {
    widget.onMonthChanged(_monthAt(page));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double pageHeight = _pageHeight(constraints.maxWidth);
          return Column(
            children: [
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _goToPreviousMonth,
                      icon: const Icon(Icons.chevron_left_rounded),
                      tooltip: "이전 달",
                    ),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, _) {
                          final double page = _pageController.hasClients
                              ? (_pageController.page ??
                                  _initialPage.toDouble())
                              : _initialPage.toDouble();
                          final DateTime month = _monthAt(page.round());
                          return Text(
                            "${month.year}년 ${month.month}월",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          );
                        },
                      ),
                    ),
                    IconButton(
                      onPressed: _goToNextMonth,
                      icon: const Icon(Icons.chevron_right_rounded),
                      tooltip: "다음 달",
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: pageHeight,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _handlePageChanged,
                  itemBuilder: (context, index) {
                    return _CalendarMonthPage(
                      focusedMonth: _monthAt(index),
                      selectedDate: widget.selectedDate,
                      ranges: widget.ranges,
                      onDateTap: widget.onDateTap,
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 4,
                children: [
                  for (final AcademicScheduleKind kind
                      in AcademicScheduleVisuals.calendarLegendKinds)
                    _CalendarDotLegend(
                      color: AcademicScheduleVisuals.of(context, kind).dotColor,
                      label: AcademicScheduleVisuals.legendLabel(kind),
                      textColor: scheme.onSurfaceVariant,
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CalendarMonthPage extends StatelessWidget {
  const _CalendarMonthPage({
    required this.focusedMonth,
    required this.selectedDate,
    required this.ranges,
    required this.onDateTap,
  });

  final DateTime focusedMonth;
  final DateTime? selectedDate;
  final List<({DateTime start, DateTime end, Map<String, dynamic> item})>
      ranges;
  final ValueChanged<DateTime> onDateTap;

  static const List<String> _dayLabels = ["일", "월", "화", "수", "목", "금", "토"];
  static const double _gridAspectRatio = 0.85;
  static const int _maxWeekRows = 6;

  AcademicScheduleKind _kindOf(Map<String, dynamic> item) =>
      AcademicScheduleClassifier.kindOf(item);

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final DateTime first = focusedMonth;
    final int leadingBlanks = first.weekday % 7; // Sunday=0
    final int daysInMonth =
        DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final int totalCells = _maxWeekRows * 7;
    final DateTime today = _CalendarView._dateOnly(DateTime.now());
    final DateTime? selDay =
        selectedDate == null ? null : _CalendarView._dateOnly(selectedDate!);

    return Column(
      children: [
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
                    _dayLabels[i],
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
        LayoutBuilder(
          builder: (context, constraints) {
            final double cellWidth = constraints.maxWidth / 7;
            final double cellHeight = cellWidth / _gridAspectRatio;
            return SizedBox(
              height: _maxWeekRows * cellHeight,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: totalCells,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: _gridAspectRatio,
                ),
                itemBuilder: (context, index) {
                  final int dayNum = index - leadingBlanks + 1;
                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return const SizedBox.shrink();
                  }
                  final DateTime date =
                      DateTime(focusedMonth.year, focusedMonth.month, dayNum);
                  final List<
                          ({
                            DateTime start,
                            DateTime end,
                            Map<String, dynamic> item
                          })>
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

                  final List<AcademicScheduleKind> uniqueKinds =
                      <AcademicScheduleKind>[];
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
                                  ? AcademicScheduleVisuals
                                      .calendarDayBackground(
                                      context: context,
                                      hasEvent: hasEvent,
                                      hasImportant: hasImportant,
                                    )
                                  : Colors.transparent),
                          borderRadius: BorderRadius.circular(10),
                          border: isToday && !isSelected
                              ? Border.all(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.55),
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
                                fontWeight:
                                    hasEvent || isSelected || isToday
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
            );
          },
        ),
      ],
    );
  }
}

class _CalendarDotLegend extends StatelessWidget {
  const _CalendarDotLegend({
    required this.color,
    required this.label,
    required this.textColor,
  });

  final Color color;
  final String label;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
