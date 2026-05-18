import "package:flutter/material.dart";
import "package:mjc_in_one/features/timetable/models/timetable_models.dart";
import "package:mjc_in_one/features/timetable/utils/timetable_color_util.dart";
import "package:mjc_in_one/features/timetable/utils/timetable_slot_merge.dart";
import "package:mjc_in_one/theme/app_colors.dart";
import "package:mjc_in_one/theme/app_theme.dart";

/// Mon–Fri weekly grid with hour rows and colored class blocks.
class TimetableWeekGrid extends StatelessWidget {
  const TimetableWeekGrid({
    super.key,
    required this.slots,
    this.onSlotTap,
    this.professorByOfferingId = const <String, String>{},
    this.startHour = 8,
    this.endHour = 22,
    this.hourHeight = 44,
    this.timeColumnWidth = 34,
    this.headerHeight = 28,
    this.compact = false,
  });

  final List<TimetableSlot> slots;
  final void Function(TimetableSlot slot)? onSlotTap;
  /// [TimetableSlot.offeringId] → professor name for grid cell subtitle.
  final Map<String, String> professorByOfferingId;
  final int startHour;
  final int endHour;
  final double hourHeight;
  final double timeColumnWidth;
  final double headerHeight;
  final bool compact;

  static const List<String> _dayLabels = <String>["월", "화", "수", "목", "금"];

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    final int hourSpan = endHour - startHour;
    final double gridBodyHeight = hourSpan * hourHeight;

    final List<TimetableSlot> visible = TimetableSlotMerge.mergeAdjacent(
      slots.where((TimetableSlot s) => s.weekday >= 1 && s.weekday <= 5),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double totalW = constraints.maxWidth;
        final double dayAreaW = (totalW - timeColumnWidth).clamp(1, double.infinity);
        final double dayColW = dayAreaW / 5;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: headerHeight,
              child: Row(
                children: <Widget>[
                  SizedBox(width: timeColumnWidth),
                  for (int i = 0; i < 5; i++)
                    SizedBox(
                      width: dayColW,
                      child: Center(
                        child: Text(
                          _dayLabels[i],
                          style: TextStyle(
                            fontFamily: kPretendardFontFamily,
                            fontSize: compact ? 11 : 12,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: gridBodyHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: timeColumnWidth,
                    height: gridBodyHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        for (int h = startHour; h < endHour; h++)
                          Positioned(
                            top: (h - startHour) * hourHeight,
                            left: 0,
                            right: 2,
                            child: Text(
                              "$h",
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontFamily: kPretendardFontFamily,
                                fontSize: compact ? 10 : 11,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: dayAreaW,
                    height: gridBodyHeight,
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: <Widget>[
                        CustomPaint(
                          size: Size(dayAreaW, gridBodyHeight),
                          painter: _TimetableGridLinesPainter(
                            dayColumns: 5,
                            hourRows: hourSpan,
                            lineColor: tokens.hairline,
                          ),
                        ),
                        for (final TimetableSlot s in visible)
                          _slotBlock(
                            context: context,
                            slot: s,
                            dayColW: dayColW,
                            gridBodyHeight: gridBodyHeight,
                            compact: compact,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _slotBlock({
    required BuildContext context,
    required TimetableSlot slot,
    required double dayColW,
    required double gridBodyHeight,
    required bool compact,
  }) {
    final int startMin = startHour * 60;
    final int endMin = endHour * 60;
    final int spanMin = endMin - startMin;
    if (spanMin <= 0) return const SizedBox.shrink();

    double yOf(int minute) {
      final double t = ((minute - startMin) / spanMin).clamp(0.0, 1.0);
      return t * gridBodyHeight;
    }

    final double top = yOf(slot.startMinute);
    final double bottom = yOf(slot.endMinute);
    final double height = (bottom - top).clamp(6.0, gridBodyHeight);
    final int col = slot.weekday - 1;
    final double left = col * dayColW + 1;
    final double width = dayColW - 2;

    final Color bg = TimetableColorUtil.colorForCourseKey(slot.colorKey);
    final String professor =
        (professorByOfferingId[slot.offeringId] ?? "").trim();

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onSlotTap == null ? null : () => onSlotTap!(slot),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Flexible(
                  child: Text(
                    slot.courseName,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: kPretendardFontFamily,
                      fontSize: compact ? 9 : 10,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      color: AppColors.timetableSlotOnColor,
                    ),
                  ),
                ),
                if (professor.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 1),
                  Text(
                    professor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: kPretendardFontFamily,
                      fontSize: compact ? 7 : 8,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                      color: AppColors.timetableSlotOnColor
                          .withValues(alpha: 0.95),
                    ),
                  ),
                ],
                if (slot.room.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 1),
                  Text(
                    slot.room,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: kPretendardFontFamily,
                      fontSize: compact ? 8 : 9,
                      fontWeight: FontWeight.w500,
                      color: AppColors.timetableSlotOnColor
                          .withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimetableGridLinesPainter extends CustomPainter {
  _TimetableGridLinesPainter({
    required this.dayColumns,
    required this.hourRows,
    required this.lineColor,
  });

  final int dayColumns;
  final int hourRows;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;

    final double dayW = size.width / dayColumns;
    for (int i = 0; i <= dayColumns; i++) {
      final double x = i * dayW;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    final double hourH = size.height / hourRows;
    for (int i = 0; i <= hourRows; i++) {
      final double y = i * hourH;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TimetableGridLinesPainter oldDelegate) {
    return oldDelegate.dayColumns != dayColumns ||
        oldDelegate.hourRows != hourRows ||
        oldDelegate.lineColor != lineColor;
  }
}
