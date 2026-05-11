import "package:flutter/material.dart";
import "package:mio_notice/features/timetable/models/timetable_models.dart";
import "package:mio_notice/features/timetable/services/timetable_slot_parser.dart";
import "package:mio_notice/theme/app_colors.dart";
import "package:mio_notice/theme/app_theme.dart";

/// Minimal form: one weekly slot per «직접 추가» offering.
Future<ParsedCourseOffering?> showTimetableManualEntrySheet(
  BuildContext context,
) {
  return showModalBottomSheet<ParsedCourseOffering>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext ctx) => const _TimetableManualEntryBody(),
  );
}

class _TimetableManualEntryBody extends StatefulWidget {
  const _TimetableManualEntryBody();

  @override
  State<_TimetableManualEntryBody> createState() =>
      _TimetableManualEntryBodyState();
}

class _TimetableManualEntryBodyState extends State<_TimetableManualEntryBody> {
  final TextEditingController _course = TextEditingController();
  final TextEditingController _room = TextEditingController();
  final TextEditingController _prof = TextEditingController();
  final TextEditingController _start = TextEditingController(text: "09:00");
  final TextEditingController _end = TextEditingController(text: "10:50");
  int _weekday = 1;

  @override
  void dispose() {
    _course.dispose();
    _room.dispose();
    _prof.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = _course.text.trim();
    final String room = _room.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("과목명을 입력해 주세요.")),
      );
      return;
    }
    final String line =
        "${_weekdayLabel()} ${_start.text.trim()} - ${_end.text.trim()} (${room.isEmpty ? "-" : room})";
    final String oid = TimetableSlotParser.stableOfferingId(
      department: "",
      courseName: name,
      section: "직접",
      professor: _prof.text.trim(),
    );
    final String ck = "$name|직접";
    final List<TimetableSlot> slots = TimetableSlotParser.parseTimetableCell(
      raw: line,
      courseName: name,
      offeringId: oid,
      colorKey: ck,
    );
    if (slots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("시간 형식을 확인해 주세요. (예: 화 13:00 - 13:50 ( 공716 ))"),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      ParsedCourseOffering(
        offeringId: oid,
        courseCategory: "",
        department: "",
        courseName: name,
        section: "직접",
        professor: _prof.text.trim(),
        gradeYear: "",
        completionType: "",
        credits: "",
        slots: slots,
        rawTimetableText: line,
      ),
    );
  }

  String _weekdayLabel() {
    return switch (_weekday) {
      1 => "월",
      2 => "화",
      3 => "수",
      4 => "목",
      5 => "금",
      6 => "토",
      _ => "월",
    };
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets pad = EdgeInsets.only(
      left: 20,
      right: 20,
      top: 8,
      bottom: MediaQuery.paddingOf(context).bottom + 20,
    );
    return Padding(
      padding: pad,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              "직접 추가",
              style: TextStyle(
                fontFamily: kPretendardFontFamily,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _course,
              decoration: const InputDecoration(labelText: "과목명"),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _prof,
              decoration: const InputDecoration(labelText: "교수명 (선택)"),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: "요일"),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _weekday,
                  isExpanded: true,
                  items: const <DropdownMenuItem<int>>[
                    DropdownMenuItem(value: 1, child: Text("월")),
                    DropdownMenuItem(value: 2, child: Text("화")),
                    DropdownMenuItem(value: 3, child: Text("수")),
                    DropdownMenuItem(value: 4, child: Text("목")),
                    DropdownMenuItem(value: 5, child: Text("금")),
                    DropdownMenuItem(value: 6, child: Text("토")),
                  ],
                  onChanged: (int? v) {
                    if (v != null) setState(() => _weekday = v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _start,
                    decoration: const InputDecoration(
                      labelText: "시작 (HH:mm)",
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _end,
                    decoration: const InputDecoration(
                      labelText: "종료 (HH:mm)",
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _room,
              decoration: const InputDecoration(labelText: "강의실"),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.timetableSlotOnColor,
              ),
              child: const Text("추가"),
            ),
          ],
        ),
      ),
    );
  }
}
