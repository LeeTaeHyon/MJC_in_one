import "package:flutter/material.dart";

import "package:mjc_in_one/theme/app_theme.dart";

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
  final DateTime end = DateTime(endDay.year, endDay.month, endDay.day);
  return end.difference(today).inDays;
}

/// 신청 기간 문자열의 마감일(가장 늦은 날)까지 남은 달력 일 수. 파싱 불가 시 null.
int? mpuEffectiveDaysUntilDeadline(Map<String, dynamic> data) {
  final DateTime? deadline = mpuApplicationDeadlineDate(data);
  if (deadline == null) {
    return null;
  }
  return _calendarDaysUntil(deadline);
}

/// 마감/완료 탭: 신청 마감일 이후 경과 일 수 (당일=0).
int? mpuDaysElapsedSinceDeadline(Map<String, dynamic> data) {
  final DateTime? deadline = mpuApplicationDeadlineDate(data);
  if (deadline == null) {
    return null;
  }
  final int diff = _calendarDaysUntil(deadline);
  if (diff <= 0) {
    return -diff;
  }
  return null;
}

/// 홈 대시보드 MPU 마감 배지 두 번째 줄: 숫자, 없으면 `?`, 마감일 당일은 `DAY`.
/// [elapsed] true면 마감 후 경과 일 수(`D+` 배지용).
String mpuDeadlineBadgeSecondLine(
  Map<String, dynamic> data, {
  bool elapsed = false,
}) {
  if (elapsed) {
    final int? days = mpuDaysElapsedSinceDeadline(data);
    return days?.toString() ?? "?";
  }

  final int? eff = mpuEffectiveDaysUntilDeadline(data);
  if (eff == null) {
    return "?";
  }
  if (eff < 0) {
    return "!";
  }
  if (eff == 0) {
    return "DAY";
  }
  return eff.toString();
}

/// MPU 리스트 탭(진행 / 마감) 분류: 신청 마감일 기준.
bool mpuListingIsCompleted(Map<String, dynamic> data) {
  final int? eff = mpuEffectiveDaysUntilDeadline(data);
  if (eff != null) {
    return eff < 0;
  }
  return false;
}

/// 정렬용: 작을수록(가까울수록) 마감이 임박.
int mpuSortDValue(Map<String, dynamic> data) {
  final int? eff = mpuEffectiveDaysUntilDeadline(data);
  if (eff != null) {
    return -eff;
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
    this.elapsed = false,
  });

  final Map<String, dynamic> data;
  final double? compactSecondLineFontSize;
  /// true면 `D+`와 마감 후 경과 일 수(마감/완료 탭).
  final bool elapsed;

  @override
  Widget build(BuildContext context) {
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    final String second =
        mpuDeadlineBadgeSecondLine(data, elapsed: elapsed);
    final double secondSize = !elapsed && second == "DAY"
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
              elapsed ? "D+" : "D-",
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
