import "dart:async";

import "package:flutter/material.dart";
import "package:mio_notice/services/shuttle_schedule.dart";
import "package:mio_notice/theme/app_colors.dart";

class ShuttleStatusCard extends StatefulWidget {
  const ShuttleStatusCard({super.key});

  @override
  State<ShuttleStatusCard> createState() => _ShuttleStatusCardState();
}

class _ShuttleStatusCardState extends State<ShuttleStatusCard> {
  late Future<List<ShuttleDeparture>> _departuresFuture;
  final ShuttleScheduleService _service = ShuttleScheduleService();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _departuresFuture = _service.loadFromAsset();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: FutureBuilder<List<ShuttleDeparture>>(
        future: _departuresFuture,
        builder: (context, snapshot) {
          final List<ShuttleDeparture> departures = snapshot.data ?? const [];
          final ShuttleStatus status =
              _service.nextStatus(DateTime.now(), departures);
          final _ShuttleCopy copy = _copyForStatus(status);
          return Material(
            color: Colors.white,
            elevation: 1.5,
            shadowColor: Colors.black12,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openRouteSheet(context, status),
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
                          const Text(
                            "셔틀버스",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            snapshot.connectionState == ConnectionState.waiting
                                ? "시간표를 불러오는 중입니다."
                                : copy.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                          if (copy.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              copy.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: Colors.black38,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  _ShuttleCopy _copyForStatus(ShuttleStatus status) {
    final ShuttleDeparture? departure = status.departure;
    switch (status.kind) {
      case ShuttleStatusKind.empty:
        return const _ShuttleCopy(
          "셔틀버스 시간표 등록 후 표시됩니다.",
          "assets/data/shuttle.csv를 채워 주세요.",
        );
      case ShuttleStatusKind.noMoreToday:
        return const _ShuttleCopy("오늘 셔틀버스 운행이 없습니다.", "");
      case ShuttleStatusKind.closed:
        return const _ShuttleCopy(
          "셔틀버스 운행이 마감되었습니다.",
          "오전 6시 이후 다음 운행 안내가 표시됩니다.",
        );
      case ShuttleStatusKind.morningFinished:
        return const _ShuttleCopy(
          "오전 셔틀 마감, 오후 셔틀 15:00 학교 출발 예정",
          "",
        );
      case ShuttleStatusKind.beforeDeparture:
        if (departure!.stopName == "학교" &&
            departure.departTime.hour == 8 &&
            departure.departTime.minute == 0) {
          return const _ShuttleCopy("오전 8시에 학교에서 출발 예정", "");
        }
        return _ShuttleCopy("${status.minutes}분 후 학교에서 출발 예정", "");
      case ShuttleStatusKind.enRoute:
        return _ShuttleCopy(
          "${status.minutes}분 뒤 ${departure!.arriveStop} 도착",
          "${departure.stopName}에서 ${_formatDepartTime(departure)} 출발",
        );
    }
  }

  String _formatDepartTime(ShuttleDeparture departure) {
    final String hour = departure.departTime.hour.toString().padLeft(2, "0");
    final String minute =
        departure.departTime.minute.toString().padLeft(2, "0");
    return "$hour:$minute 출발";
  }

  void _openRouteSheet(BuildContext context, ShuttleStatus status) {
    // BottomSheet dismiss/route transitions can restore focus to an existing
    // text input elsewhere in the widget tree, which triggers the soft keyboard.
    // Force-unfocus on open and after the sheet closes.
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ShuttleRouteSheet(status: status);
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
  const _ShuttleRouteSheet({required this.status});

  final ShuttleStatus status;

  @override
  Widget build(BuildContext context) {
    final ShuttleDeparture? departure = status.departure;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
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
              _ShuttleRouteMap(status: status)
            else
              const _ShuttleWaitingNotice(),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.scaffoldMuted,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.schedule_rounded,
            color: AppColors.primary,
            size: 34,
          ),
          SizedBox(height: 10),
          Text(
            "셔틀 출발 전입니다",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "버스가 이동 중일 때 노선도가 표시됩니다.",
            style: TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShuttleRouteMap extends StatelessWidget {
  const _ShuttleRouteMap({required this.status});

  static const List<String> _stops = ["학교", "가좌역", "홍대역", "학교"];
  static const double _routeTop = 14;
  static const double _stopGap = 64;
  static const double _markerLeft = 18;
  /// Last stop is positioned at `top`; the row (dot + label) still extends
  /// downward, so the stack must be taller than the last `top` alone.
  static const double _stopRowExtent = 28;

  final ShuttleStatus status;

  @override
  Widget build(BuildContext context) {
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
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: _routeTop +
              _stopGap * (_stops.length - 1) +
              _stopRowExtent,
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
              for (int i = 0; i < _stops.length; i++)
                _RouteStop(
                  top: _routeTop + (i * _stopGap),
                  left: _markerLeft,
                  label: _stops[i],
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
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 3),
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
    for (int i = 0; i < _stops.length - 1; i++) {
      if (_stops[i] == departure.stopName &&
          _stops[i + 1] == departure.arriveStop) {
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
    required this.active,
  });

  final double top;
  final double left;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
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
              color: active ? AppColors.primary : Colors.white,
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
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: active ? FontWeight.w900 : FontWeight.w700,
              color: active ? Colors.black87 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
