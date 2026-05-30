import "package:mjc_in_one/features/timetable/models/timetable_models.dart";

double parseCourseCredits(String raw) {
  final String s = raw.trim();
  if (s.isEmpty) return 0;
  final double? direct = double.tryParse(s);
  if (direct != null) return direct;
  final RegExpMatch? m = RegExp(r"(\d+(?:\.\d+)?)").firstMatch(s);
  if (m == null) return 0;
  return double.tryParse(m.group(1)!) ?? 0;
}

double totalCreditsFromOfferings(List<ParsedCourseOffering> offerings) {
  return offerings.fold(0.0, (double sum, ParsedCourseOffering o) {
    return sum + parseCourseCredits(o.credits);
  });
}

String formatTotalCreditsLabel(double total) {
  if (total == total.roundToDouble()) {
    return "${total.toInt()}학점";
  }
  return "${total.toStringAsFixed(1)}학점";
}

String totalCreditsLabelFromOfferings(List<ParsedCourseOffering> offerings) {
  return formatTotalCreditsLabel(totalCreditsFromOfferings(offerings));
}
