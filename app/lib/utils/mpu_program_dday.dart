import "package:flutter/material.dart";

import "package:mio_notice/theme/app_theme.dart";

/// Crawled HTML may use Unicode minus (U+2212) instead of ASCII hyphen in "D−n".
String normalizeMpuDdayScrape(String raw) {
  return raw
      .trim()
      .replaceAll("\u2212", "-")
      .replaceAll("\u2013", "-")
      .replaceAll("\u2014", "-");
}

/// Home dashboard MPU 줄과 동일: `D-<digits>` 형태만 숫자로 인정 (예: D-12).
int? parseMpuDDayStrict(dynamic v) {
  final String s = normalizeMpuDdayScrape((v ?? "").toString());
  final RegExpMatch? m =
      RegExp(r"^D-(\d+)$", caseSensitive: false).firstMatch(s);
  if (m == null) return null;
  return int.tryParse(m.group(1)!);
}

/// 신청·마감 등 문자열에서 마지막 날짜(가장 늦은 일)를 고릅니다.
DateTime? mpuLastCalendarDateInText(String raw) {
  final String s = raw.trim();
  if (s.isEmpty) return null;
  DateTime? last;
  void consider(int y, int mo, int d) {
    final DateTime cand = DateTime(y, mo, d);
    if (last == null || cand.isAfter(last!)) {
      last = cand;
    }
  }

  final RegExp reIso = RegExp(r"(\d{4})[.\-](\d{1,2})[.\-](\d{1,2})");
  for (final RegExpMatch m in reIso.allMatches(s)) {
    consider(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }

  final RegExp reKo =
      RegExp(r"(\d{4})년\s*(\d{1,2})월\s*(\d{1,2})일", caseSensitive: false);
  for (final RegExpMatch m in reKo.allMatches(s)) {
    consider(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }

  return last;
}

String mpuApplicationPeriodRaw(Map<String, dynamic> data) {
  return (data["reg_date"] ?? data["deadline"] ?? data["end_date"] ?? "")
      .toString();
}

DateTime? mpuApplicationDeadlineDate(Map<String, dynamic> data) {
  return mpuLastCalendarDateInText(mpuApplicationPeriodRaw(data));
}

int _calendarDaysUntil(DateTime endDay) {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime end =
      DateTime(endDay.year, endDay.month, endDay.day);
  return end.difference(today).inDays;
}

/// Firestore `D-n`이 있으면 그 [n], 없으면 신청 기간 문자열에서 마감일까지 일 수.
int? mpuEffectiveDaysUntilDeadline(Map<String, dynamic> data) {
  final int? strict = parseMpuDDayStrict(data["d_day"]);
  if (strict != null) {
    return strict;
  }
  final DateTime? deadline = mpuApplicationDeadlineDate(data);
  if (deadline == null) {
    return null;
  }
  return _calendarDaysUntil(deadline);
}

/// 홈 대시보드 MPU 마감 배지 두 번째 줄과 동일 규칙: 숫자, 없으면 `?`, 마감일 당일은 `DAY`.
String mpuDeadlineBadgeSecondLine(Map<String, dynamic> data) {
  final int? strict = parseMpuDDayStrict(data["d_day"]);
  if (strict != null) {
    return strict.toString();
  }
  final DateTime? deadline = mpuApplicationDeadlineDate(data);
  if (deadline == null) {
    return "?";
  }
  final int diff = _calendarDaysUntil(deadline);
  if (diff < 0) {
    return "!";
  }
  if (diff == 0) {
    return "DAY";
  }
  return diff.toString();
}

/// MPU 리스트 탭(진행 / 마감) 분류용.
bool mpuListingIsCompleted(Map<String, dynamic> data) {
  final String dd = normalizeMpuDdayScrape((data["d_day"] ?? "").toString());
  if (dd.contains("마감") || dd.contains("+") || dd == "D-0") {
    return true;
  }
  if (parseMpuDDayStrict(data["d_day"]) == 0) {
    return true;
  }
  final int? eff = mpuEffectiveDaysUntilDeadline(data);
  if (eff != null) {
    return eff < 0;
  }
  if (dd.toUpperCase() == "D-DAY") {
    return false;
  }
  return dd.isEmpty;
}

/// 정렬용: 작을수록(가까울수록) 마감이 임박. Firestore `D-n`과 일정 기반 일 수를 통일.
int mpuSortDValue(Map<String, dynamic> data) {
  final int? eff = mpuEffectiveDaysUntilDeadline(data);
  if (eff != null) {
    return -eff;
  }
  final String n = normalizeMpuDdayScrape((data["d_day"] ?? "").toString());
  if (n.contains("마감")) {
    return 9999;
  }
  if (n.toUpperCase() == "D-DAY") {
    return 0;
  }
  final RegExpMatch? match =
      RegExp(r"D([-+])(\d+)", caseSensitive: false).firstMatch(n);
  if (match != null) {
    final int val = int.parse(match.group(2)!);
    return match.group(1) == "-" ? -val : val;
  }
  if (n == "D-0") {
    return 0;
  }
  return 9999;
}

/// 홈 MPU 마감 카드에 항목을 넣을지: 배지를 그릴 수 있고 아직 마감 전인 일정.
bool mpuIncludeInHomeDeadlineList(Map<String, dynamic> data) {
  final int? eff = mpuEffectiveDaysUntilDeadline(data);
  return eff != null && eff >= 0;
}

/// 홈과 동일한 `D-` + 숫자/보조 텍스트 배지.
class MpuDeadlineHomeStyleBadge extends StatelessWidget {
  const MpuDeadlineHomeStyleBadge({
    super.key,
    required this.data,
    this.compactSecondLineFontSize,
  });

  final Map<String, dynamic> data;
  final double? compactSecondLineFontSize;

  @override
  Widget build(BuildContext context) {
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    final String second = mpuDeadlineBadgeSecondLine(data);
    final double secondSize = second == "DAY"
        ? (compactSecondLineFontSize ?? 11)
        : (compactSecondLineFontSize ?? 18);

    return SizedBox(
      width: 56,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.deadlineBadge,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "D-",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              second,
              style: TextStyle(
                color: Colors.white,
                fontSize: secondSize,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
