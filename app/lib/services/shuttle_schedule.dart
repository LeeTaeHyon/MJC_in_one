import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:cp949_codec/cp949_codec.dart";

enum ShuttleStatusKind { empty, beforeDeparture, enRoute, noMoreToday }

class ShuttleDeparture {
  const ShuttleDeparture({
    required this.stopName,
    required this.departTime,
    required this.weekdays,
    this.arriveStop,
    this.travelMin,
  });

  final String stopName;
  final TimeOfDay departTime;
  final Set<int> weekdays;
  final String? arriveStop;
  final int? travelMin;

  DateTime departDateTime(DateTime day) {
    return DateTime(
      day.year,
      day.month,
      day.day,
      departTime.hour,
      departTime.minute,
    );
  }
}

class ShuttleStatus {
  const ShuttleStatus._({
    required this.kind,
    this.departure,
    this.minutes = 0,
  });

  factory ShuttleStatus.empty() =>
      const ShuttleStatus._(kind: ShuttleStatusKind.empty);

  factory ShuttleStatus.noMoreToday() =>
      const ShuttleStatus._(kind: ShuttleStatusKind.noMoreToday);

  factory ShuttleStatus.beforeDeparture(
    ShuttleDeparture departure,
    int minutes,
  ) {
    return ShuttleStatus._(
      kind: ShuttleStatusKind.beforeDeparture,
      departure: departure,
      minutes: minutes,
    );
  }

  factory ShuttleStatus.enRoute(ShuttleDeparture departure, int minutes) {
    return ShuttleStatus._(
      kind: ShuttleStatusKind.enRoute,
      departure: departure,
      minutes: minutes,
    );
  }

  final ShuttleStatusKind kind;
  final ShuttleDeparture? departure;
  final int minutes;
}

class ShuttleScheduleService {
  static const String assetPath = "assets/data/shuttle.csv";

  Future<List<ShuttleDeparture>> loadFromAsset() async {
    final ByteData data = await rootBundle.load(assetPath);
    final Uint8List bytes = data.buffer.asUint8List();

    // Flutter의 `loadString`은 UTF-8만 가정합니다. 실사용에서 엑셀 등으로
    // `ANSI(CP949)`로 저장되는 경우가 많아서 UTF-8 실패 시 CP949로 fallback 합니다.
    final String raw = _decodeText(bytes);
    final List<String> lines = raw
        .split(RegExp(r"\r?\n"))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length <= 1) return const [];

    final List<String> headers = _splitCsvLine(lines.first)
        .map((value) => value.trim().toLowerCase())
        .toList();
    final List<ShuttleDeparture> rows = [];
    for (final String line in lines.skip(1)) {
      final Map<String, String> row = _rowMap(headers, _splitCsvLine(line));
      final String stopName = (row["stop_name"] ?? "").trim();
      final TimeOfDay? time = _parseTime(row["depart_time"]);
      final Set<int> weekdays = _parseWeekdays(row["weekday"]);
      if (stopName.isEmpty || time == null || weekdays.isEmpty) continue;
      final String arriveStop = (row["arrive_stop"] ?? "").trim();
      rows.add(
        ShuttleDeparture(
          stopName: stopName,
          departTime: time,
          weekdays: weekdays,
          arriveStop: arriveStop.isEmpty ? null : arriveStop,
          travelMin: int.tryParse((row["travel_min"] ?? "").trim()),
        ),
      );
    }

    rows.sort((a, b) {
      final int aMin = a.departTime.hour * 60 + a.departTime.minute;
      final int bMin = b.departTime.hour * 60 + b.departTime.minute;
      return aMin.compareTo(bMin);
    });
    return rows;
  }

  String _decodeText(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return cp949.decode(bytes);
    }
  }

  ShuttleStatus nextStatus(DateTime now, List<ShuttleDeparture> departures) {
    final List<ShuttleDeparture> todays = departures
        .where((departure) => departure.weekdays.contains(now.weekday))
        .toList();
    if (departures.isEmpty) return ShuttleStatus.empty();
    if (todays.isEmpty) return ShuttleStatus.noMoreToday();

    for (final ShuttleDeparture departure in todays) {
      final DateTime departAt = departure.departDateTime(now);
      final int? travelMin = departure.travelMin;
      if (travelMin != null &&
          travelMin > 0 &&
          departure.arriveStop != null &&
          !now.isBefore(departAt)) {
        final DateTime arriveAt = departAt.add(Duration(minutes: travelMin));
        if (now.isBefore(arriveAt)) {
          return ShuttleStatus.enRoute(
            departure,
            _ceilMinutes(arriveAt.difference(now)),
          );
        }
      }
    }

    for (final ShuttleDeparture departure in todays) {
      final DateTime departAt = departure.departDateTime(now);
      if (now.isBefore(departAt)) {
        return ShuttleStatus.beforeDeparture(
          departure,
          _ceilMinutes(departAt.difference(now)),
        );
      }
    }

    return ShuttleStatus.noMoreToday();
  }

  Map<String, String> _rowMap(List<String> headers, List<String> values) {
    final Map<String, String> result = {};
    for (int i = 0; i < headers.length; i++) {
      result[headers[i]] = i < values.length ? values[i].trim() : "";
    }
    return result;
  }

  List<String> _splitCsvLine(String line) {
    final List<String> values = [];
    final StringBuffer current = StringBuffer();
    bool quoted = false;
    for (int i = 0; i < line.length; i++) {
      final String char = line[i];
      if (char == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (char == "," && !quoted) {
        values.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    values.add(current.toString());
    return values;
  }

  TimeOfDay? _parseTime(String? value) {
    final String raw = (value ?? "").trim();
    final RegExpMatch? match = RegExp(r"^(\d{1,2}):(\d{2})$").firstMatch(raw);
    if (match == null) return null;
    final int? hour = int.tryParse(match.group(1)!);
    final int? minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Set<int> _parseWeekdays(String? value) {
    final String raw = (value ?? "").trim();
    if (raw.isEmpty) return const {};
    if (raw == "*" || raw.toLowerCase() == "all") {
      return {1, 2, 3, 4, 5, 6, 7};
    }
    if (raw.contains("월") ||
        raw.contains("화") ||
        raw.contains("수") ||
        raw.contains("목") ||
        raw.contains("금") ||
        raw.contains("토") ||
        raw.contains("일")) {
      final Map<String, int> labels = {
        "월": 1,
        "화": 2,
        "수": 3,
        "목": 4,
        "금": 5,
        "토": 6,
        "일": 7,
      };
      return labels.entries
          .where((entry) => raw.contains(entry.key))
          .map((entry) => entry.value)
          .toSet();
    }
    final Set<int> result = {};
    for (final String part in raw.split(RegExp(r"[,\s/]+"))) {
      if (part.contains("-")) {
        final List<String> range = part.split("-");
        if (range.length == 2) {
          final int? start = int.tryParse(range[0]);
          final int? end = int.tryParse(range[1]);
          if (start != null && end != null && start <= end) {
            result.addAll(
              List<int>.generate(end - start + 1, (index) => start + index)
                  .where((day) => day >= 1 && day <= 7),
            );
          }
        }
      } else {
        final int? day = int.tryParse(part);
        if (day != null && day >= 1 && day <= 7) result.add(day);
      }
    }
    return result;
  }

  int _ceilMinutes(Duration duration) {
    final int seconds = duration.inSeconds;
    if (seconds <= 0) return 0;
    return (seconds / 60).ceil();
  }
}
