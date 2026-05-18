import "package:flutter/material.dart";
import "package:mjc_in_one/services/app_config_service.dart";
import "package:mjc_in_one/services/shuttle_schedule.dart";
import "package:mjc_in_one/theme/app_colors.dart";
import "package:mjc_in_one/theme/app_theme.dart";
import "package:mjc_in_one/utils/live_clock.dart";

const TextStyle _kShuttleCardTitleStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w700,
  height: 1.2,
);

class ShuttleStatusCard extends StatefulWidget {
  const ShuttleStatusCard({super.key});

  @override
  State<ShuttleStatusCard> createState() => _ShuttleStatusCardState();
}

class _ShuttleStatusCardState extends State<ShuttleStatusCard> {
  late Future<List<ShuttleDeparture>> _departuresFuture;
  final ShuttleScheduleService _service = ShuttleScheduleService();

  @override
  void initState() {
    super.initState();
    LiveClock.instance.attach();
    _departuresFuture = _service.load();
  }

  @override
  void dispose() {
    LiveClock.instance.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return ListenableBuilder(
      listenable: LiveClock.instance.tick,
      builder: (BuildContext context, Widget? child) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: FutureBuilder<List<ShuttleDeparture>>(
            future: _departuresFuture,
            builder: (context, snapshot) {
              final List<ShuttleDeparture> departures =
                  snapshot.data ?? const [];
              final DateTime now = DateTime.now();
              final ShuttleStatus status =
                  _service.nextStatus(now, departures);
              final List<ShuttleDeparture> todays = departures
                  .where((d) => d.weekdays.contains(now.weekday))
                  .toList()
                ..sort(
                  (a, b) => _timeMinute(a).compareTo(_timeMinute(b)),
                );
              final _ShuttleCopy copy = _copyForStatus(status);
              return Material(
            color: scheme.surface,
            elevation: 1.5,
            shadowColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openRouteSheet(context, status, todays),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.directions_bus_filled_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "셔틀버스",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            snapshot.connectionState == ConnectionState.waiting
                                ? "시간표 불러오는 중"
                                : copy.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _kShuttleCardTitleStyle,
                          ),
                          if (copy.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              copy.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
                    ),
                  ],
                ),
              ),
            ),
              );
            },
          ),
        );
      },
    );
  }

  _ShuttleCopy _copyForStatus(ShuttleStatus status) {
    final ShuttleDeparture? departure = status.departure;
    switch (status.kind) {
      case ShuttleStatusKind.empty:
        return const _ShuttleCopy(
          "시간표 등록 후 표시",
          "shuttle.csv를 채워 주세요.",
        );
      case ShuttleStatusKind.noMoreToday:
        return const _ShuttleCopy("오늘 셔틀 없음", "");
      case ShuttleStatusKind.closed:
        return const _ShuttleCopy(
          "오늘 운행 종료",
          "6시부터 다음 안내",
        );
      case ShuttleStatusKind.morningFinished:
        return const _ShuttleCopy(
          "오후 15:00 학교 출발",
          "",
        );
      case ShuttleStatusKind.beforeDeparture:
        if (departure!.stopName == "학교" &&
            departure.departTime.hour == 8 &&
            departure.departTime.minute == 0) {
          return const _ShuttleCopy("8시 학교 출발 예정", "");
        }
        return _ShuttleCopy("${status.minutes}분 후 학교 출발", "");
      case ShuttleStatusKind.enRoute:
        return _ShuttleCopy(
          "${status.minutes}분 후 ${departure!.arriveStop} 도착",
          "${departure.stopName} ${_formatDepartTime(departure)} 출발",
        );
    }
  }

  String _formatDepartTime(ShuttleDeparture departure) {
    final String hour = departure.departTime.hour.toString().padLeft(2, "0");
    final String minute =
        departure.departTime.minute.toString().padLeft(2, "0");
    return "$hour:$minute";
  }

  int _timeMinute(ShuttleDeparture departure) {
    return departure.departTime.hour * 60 + departure.departTime.minute;
  }

  void _openRouteSheet(
    BuildContext context,
    ShuttleStatus status,
    List<ShuttleDeparture> todays,
  ) {
    // BottomSheet dismiss/route transitions can restore focus to an existing
    // text input elsewhere in the widget tree, which triggers the soft keyboard.
    // Force-unfocus on open and after the sheet closes.
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ShuttleRouteSheet(status: status, todays: todays);
      },
    ).whenComplete(() {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }
}

class _ShuttleCopy {
  const _ShuttleCopy(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

class _ShuttleRouteSheet extends StatelessWidget {
  const _ShuttleRouteSheet({
    required this.status,
    required this.todays,
  });

  final ShuttleStatus status;
  final List<ShuttleDeparture> todays;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final ShuttleDeparture? departure = status.departure;
    final _ShuttleTripTimes? trip = _ShuttleTripTimes.fromDeparture(
      departure,
      todays,
    );
    final Future<List<String>?> stopsFuture = AppConfigService.loadShuttleStops();
    const List<String> fallbackStops = <String>["학교", "가좌역", "홍대역", "학교"];
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_bus_filled_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "셔틀버스 노선도",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (status.kind == ShuttleStatusKind.enRoute &&
                departure != null &&
                departure.arriveStop != null)
              FutureBuilder<List<String>?>(
                future: stopsFuture,
                builder: (context, snapshot) {
                  final List<String> stops = (snapshot.data ?? fallbackStops)
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toList();
                  return _ShuttleRouteMap(
                    status: status,
                    trip: trip,
                    stops: stops.isEmpty ? fallbackStops : stops,
                  );
                },
              )
            else
              const _ShuttleWaitingNotice(),
            const SizedBox(height: 14),
            Text(
              "※ 시간표 기준 안내이므로 실제 도착 시간과 다를 수 있습니다.",
              style: TextStyle(
                fontSize: 12,
                height: 1.25,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShuttleWaitingNotice extends StatelessWidget {
  const _ShuttleWaitingNotice();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MjcSurfaceTokens tokens =
        Theme.of(context).extension<MjcSurfaceTokens>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: tokens.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.schedule_rounded,
            color: AppColors.primary,
            size: 34,
          ),
          const SizedBox(height: 10),
          const Text(
            "셔틀 출발 전입니다",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "버스가 이동 중일 때 노선도가 표시됩니다.",
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShuttleRouteMap extends StatelessWidget {
  const _ShuttleRouteMap({
    required this.status,
    required this.trip,
    required this.stops,
  });

  static const double _routeTop = 14;
  static const double _stopGap = 64;
  static const double _markerLeft = 18;

  /// Last stop is positioned at `top`; the row (dot + label) still extends
  /// downward, so the stack must be taller than the last `top` alone.
  static const double _stopRowExtent = 28;

  final ShuttleStatus status;
  final _ShuttleTripTimes? trip;
  final List<String> stops;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final ShuttleDeparture departure = status.departure!;
    final int segmentIndex = _segmentIndex(departure);
    final double busTop =
        _routeTop + ((segmentIndex + status.progress) * _stopGap);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "${departure.stopName}에서 ${departure.arriveStop}로 이동 중",
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "${status.minutes}분 뒤 ${departure.arriveStop} 도착 예정",
          style: TextStyle(
            fontSize: 13,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: _routeTop + _stopGap * (stops.length - 1) + _stopRowExtent,
          child: Stack(
            children: [
              Positioned(
                left: _markerLeft + 10,
                top: _routeTop + 8,
                bottom: _routeTop + 8,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              for (int i = 0; i < stops.length; i++)
                _RouteStop(
                  top: _routeTop + (i * _stopGap),
                  left: _markerLeft,
                  label: stops[i],
                  timeLabel: trip?.timeLabelForStop(stops[i], index: i),
                  active: i == segmentIndex || i == segmentIndex + 1,
                ),
              Positioned(
                left: _markerLeft - 7,
                top: busTop - 8,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.50 : 0.26,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.directions_bus_filled_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _segmentIndex(ShuttleDeparture departure) {
    for (int i = 0; i < stops.length - 1; i++) {
      if (stops[i] == departure.stopName &&
          stops[i + 1] == departure.arriveStop) {
        return i;
      }
    }
    return 0;
  }
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({
    required this.top,
    required this.left,
    required this.label,
    required this.timeLabel,
    required this.active,
  });

  final double top;
  final double left;
  final String label;
  final String? timeLabel;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Positioned(
      top: top,
      left: left,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 23,
            height: 23,
            decoration: BoxDecoration(
              color: active ? AppColors.primary : scheme.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: active ? 1 : 0.55),
                width: 2,
              ),
            ),
            child: active
                ? const Icon(
                    Icons.circle,
                    color: Colors.white,
                    size: 7,
                  )
                : null,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                color: active ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (timeLabel != null && timeLabel!.isNotEmpty)
            Text(
              timeLabel!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShuttleTripTimes {
  const _ShuttleTripTimes({
    required this.schoolDepart,
    required this.gajwaArrive,
    required this.hongdaeArrive,
    required this.schoolArrive,
  });

  final TimeOfDay schoolDepart;
  final TimeOfDay gajwaArrive;
  final TimeOfDay hongdaeArrive;
  final TimeOfDay schoolArrive;

  static _ShuttleTripTimes? fromDeparture(
    ShuttleDeparture? departure,
    List<ShuttleDeparture> todays,
  ) {
    if (departure == null) return null;
    if (todays.isEmpty) return null;

    ShuttleDeparture? current = departure;
    final Set<String> seen = {};

    ShuttleDeparture? prev;
    while (current != null) {
      final String key =
          "${current.stopName}|${current.arriveStop}|${_formatTime(current.departTime)}";
      if (!seen.add(key)) break;
      prev = _findPreviousLeg(current, todays);
      if (prev == null) break;
      current = prev;
      if (current.stopName == "학교") break;
    }

    ShuttleDeparture? start;
    if (current != null && current.stopName == "학교") {
      start = current;
    } else if (departure.stopName == "학교") {
      start = departure;
    }
    if (start == null) return null;

    final ShuttleDeparture leg1 = start;
    final ShuttleDeparture? leg2 = _findNextLeg(leg1, todays);
    final ShuttleDeparture? leg3 =
        leg2 == null ? null : _findNextLeg(leg2, todays);
    if (leg2 == null || leg3 == null) return null;

    final TimeOfDay schoolDepart = leg1.departTime;
    final TimeOfDay gajwaArrive = leg2.departTime;
    final TimeOfDay hongdaeArrive = leg3.departTime;
    final TimeOfDay? schoolArrive =
        _addMinutes(leg3.departTime, leg3.travelMin ?? 0);
    if (schoolArrive == null) return null;

    return _ShuttleTripTimes(
      schoolDepart: schoolDepart,
      gajwaArrive: gajwaArrive,
      hongdaeArrive: hongdaeArrive,
      schoolArrive: schoolArrive,
    );
  }

  String? timeLabelForStop(String stop, {required int index}) {
    final TimeOfDay? time = switch (stop) {
      "학교" when index == 0 => schoolDepart,
      "학교" when index != 0 => schoolArrive,
      "가좌역" => gajwaArrive,
      "홍대역" => hongdaeArrive,
      _ => null,
    };
    return time == null ? null : _formatTime(time);
  }

  static ShuttleDeparture? _findPreviousLeg(
    ShuttleDeparture current,
    List<ShuttleDeparture> todays,
  ) {
    final String currentStop = current.stopName;
    final int currentMinute = current.departTime.hour * 60 + current.departTime.minute;
    for (final d in todays) {
      if (d.arriveStop != currentStop) continue;
      final int travel = d.travelMin ?? 0;
      if (travel <= 0) continue;
      final int departMinute = d.departTime.hour * 60 + d.departTime.minute;
      if (departMinute + travel == currentMinute) return d;
    }
    return null;
  }

  static ShuttleDeparture? _findNextLeg(
    ShuttleDeparture current,
    List<ShuttleDeparture> todays,
  ) {
    final String? nextStop = current.arriveStop;
    final int travel = current.travelMin ?? 0;
    if (nextStop == null || travel <= 0) return null;
    final TimeOfDay? nextTime = _addMinutes(current.departTime, travel);
    if (nextTime == null) return null;
    for (final d in todays) {
      if (d.stopName != nextStop) continue;
      if (d.departTime.hour == nextTime.hour && d.departTime.minute == nextTime.minute) {
        return d;
      }
    }
    return null;
  }

  static TimeOfDay? _addMinutes(TimeOfDay base, int minutes) {
    if (minutes <= 0) return null;
    final int total = base.hour * 60 + base.minute + minutes;
    final int h = ((total ~/ 60) % 24);
    final int m = total % 60;
    return TimeOfDay(hour: h, minute: m);
  }

  static String _formatTime(TimeOfDay time) {
    final String hour = time.hour.toString().padLeft(2, "0");
    final String minute = time.minute.toString().padLeft(2, "0");
    return "$hour:$minute";
  }
}
