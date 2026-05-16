import "package:flutter/material.dart";
import "package:mjc_in_one/features/timetable/models/timetable_models.dart";
import "package:mjc_in_one/theme/app_theme.dart";

/// Schedule copy for bottom sheets: normal offerings, or remote+exam with optional parsed slots.
class TimetableOfferingScheduleTextBlock extends StatelessWidget {
  const TimetableOfferingScheduleTextBlock({super.key, required this.offering});

  final ParsedCourseOffering offering;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextStyle detailStyle = TextStyle(
      fontFamily: kPretendardFontFamily,
      fontSize: 13,
      height: 1.4,
      color: scheme.onSurfaceVariant,
    );
    final TextStyle labelStyle = TextStyle(
      fontFamily: kPretendardFontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    );

    if (!offering.isRemoteExamFaceToFaceOnly) {
      return Text(offering.scheduleSummary, style: detailStyle);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          "원격 강의(대면 시험). 시간표에는 강의명만 표시됩니다.",
          style: detailStyle,
        ),
        if (offering.slots.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Text("대면 시험 일정", style: labelStyle),
          const SizedBox(height: 4),
          Text(offering.scheduleSummary, style: detailStyle),
        ],
      ],
    );
  }
}
