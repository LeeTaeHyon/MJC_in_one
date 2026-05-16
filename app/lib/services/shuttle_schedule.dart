import "dart:convert";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:cp949_codec/cp949_codec.dart";
import "package:shared_preferences/shared_preferences.dart";

enum ShuttleStatusKind {
  empty,
  beforeDeparture,
  enRoute,
  morningFinished,
  closed,
  noMoreToday,
}

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
    this.progress = 0,
  });

  factory ShuttleStatus.empty() =>
      const ShuttleStatus._(kind: ShuttleStatusKind.empty);

  factory ShuttleStatus.noMoreToday() =>
      const ShuttleStatus._(kind: ShuttleStatusKind.noMoreToday);

  factory ShuttleStatus.closed() =>
      const ShuttleStatus._(kind: ShuttleStatusKind.closed);

  factory ShuttleStatus.morningFinished(
    ShuttleDeparture departure,
    int minutes,
  ) {
    return ShuttleStatus._(
      kind: ShuttleStatusKind.morningFinished,
      departure: departure,
      minutes: minutes,
    );
  }

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

  factory ShuttleStatus.enRoute(
    ShuttleDeparture departure,
    int minutes,
    double progress,
  ) {
    return ShuttleStatus._(
      kind: ShuttleStatusKind.enRoute,
      departure: departure,
      minutes: minutes,
      progress: progress,
    );
  }

  final ShuttleStatusKind kind;
  final ShuttleDeparture? departure;
  final int minutes;
  final double progress;
}

class ShuttleScheduleService {
  static const String assetPath = "assets/data/shuttle.csv";
  static const int serviceOpenMinute = 6 * 60;
  static const int morningFinishedMinute = 9 * 60 + 50;
  static const int afternoonStartMinute = 15 * 60;
  static const int serviceClosedMinute = 18 * 60 + 40;

  static const String _cacheJsonKey = "shuttle_schedule_rows_json_v1";
  static const String _cacheAtKey = "shuttle_schedule_cached_at_ms_v1";
  static const Duration _cacheTtl = Duration(days: 1);

  Future<List<ShuttleDeparture>> load() async {
    final List<Map<String, dynamic>>? cached = await _tryLoadCache();
    if (cached != null) {
      final List<ShuttleDeparture> parsed = _parseRows(cached);
      if (parsed.isNotEmpty) return parsed;
    }

    try {
      final List<Map<String, dynamic>> remote = await _loadFromFirestore();
      if (remote.isNotEmpty) {
        await _saveCache(remote);
        final List<ShuttleDeparture> parsed = _parseRows(remote);
        if (parsed.isNotEmpty) return parsed;
      }
    } catch (_) {
      // Fall back to asset.
    }

    return loadFromAsset();
  }

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
      final String stopName = _normalizeStopName(row["stop_name"]);
      final TimeOfDay? time = _parseTime(row["depart_time"]);
      final Set<int> weekdays = _parseWeekdays(row["weekday"]);
      if (stopName.isEmpty || time == null || weekdays.isEmpty) continue;
      final String arriveStop = _normalizeStopName(row["arrive_stop"]);
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

  Future<List<Map<String, dynamic>>> _loadFromFirestore() async {
    final QuerySnapshot<Map<String, dynamic>> snap =
        await FirebaseFirestore.instance.collection("shuttle_schedule").get();
    return [
      for (final d in snap.docs)
        if (d.data().isNotEmpty) Map<String, dynamic>.from(d.data()),
    ];
  }

  List<ShuttleDeparture> _parseRows(List<Map<String, dynamic>> rows) {
    final List<ShuttleDeparture> out = [];
    for (final Map<String, dynamic> row in rows) {
      final String stopName = _normalizeStopName(row["stop_name"]?.toString());
      final TimeOfDay? time = _parseTime(row["depart_time"]?.toString());
      final Set<int> weekdays = _parseWeekdays(row["weekday"]?.toString());
      if (stopName.isEmpty || time == null || weekdays.isEmpty) continue;
      final String arriveStop =
          _normalizeStopName(row["arrive_stop"]?.toString());
      out.add(
        ShuttleDeparture(
          stopName: stopName,
          departTime: time,
          weekdays: weekdays,
          arriveStop: arriveStop.isEmpty ? null : arriveStop,
          travelMin: _toInt(row["travel_min"]),
        ),
      );
    }
    out.sort((a, b) => _timeMinute(a).compareTo(_timeMinute(b)));
    return out;
  }

  Future<List<Map<String, dynamic>>?> _tryLoadCache() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int cachedAt = prefs.getInt(_cacheAtKey) ?? 0;
    if (cachedAt <= 0) return null;
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (now - cachedAt > _cacheTtl.inMilliseconds) return null;
    final String raw = prefs.getString(_cacheJsonKey) ?? "";
    if (raw.trim().isEmpty) return null;
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List) return null;
    final List<Map<String, dynamic>> out = [];
    for (final item in decoded) {
      if (item is Map) out.add(Map<String, dynamic>.from(item));
    }
    return out;
  }

  Future<void> _saveCache(List<Map<String, dynamic>> rows) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheJsonKey, jsonEncode(rows));
    await prefs.setInt(_cacheAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  String _decodeText(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return cp949.decode(bytes);
    }
  }

  ShuttleStatus nextStatus(DateTime now, List<ShuttleDeparture> departures) {
    if (departures.isEmpty) return ShuttleStatus.empty();
    final int currentMinute = now.hour * 60 + now.minute;
    if (currentMinute < serviceOpenMinute ||
        currentMinute >= serviceClosedMinute) {
      return ShuttleStatus.closed();
    }

    final List<ShuttleDeparture> todays = departures
        .where((departure) => departure.weekdays.contains(now.weekday))
        .toList()
      ..sort((a, b) => _timeMinute(a).compareTo(_timeMinute(b)));
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
          final int elapsedSeconds = now.difference(departAt).inSeconds;
          final int travelSeconds = travelMin * 60;
          return ShuttleStatus.enRoute(
            departure,
            _ceilMinutes(arriveAt.difference(now)),
            (elapsedSeconds / travelSeconds).clamp(0, 1).toDouble(),
          );
        }
      }
    }

    if (currentMinute >= morningFinishedMinute &&
        currentMinute < afternoonStartMinute) {
      final ShuttleDeparture afternoonDeparture = todays.firstWhere(
        (departure) =>
            departure.stopName == "학교" &&
            _timeMinute(departure) >= afternoonStartMinute,
        orElse: () => todays.first,
      );
      return ShuttleStatus.morningFinished(
        afternoonDeparture,
        _ceilMinutes(afternoonDeparture.departDateTime(now).difference(now)),
      );
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

  int _timeMinute(ShuttleDeparture departure) {
    return departure.departTime.hour * 60 + departure.departTime.minute;
  }

  String _normalizeStopName(String? value) {
    final String raw = (value ?? "").trim();
    return switch (raw) {
      "명지대" => "가좌역",
      "홍대입구" => "홍대역",
      _ => raw,
    };
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

int? _toInt(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim());
}
