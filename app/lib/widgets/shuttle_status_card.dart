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
                ],
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
        return const _ShuttleCopy("오늘 남은 셔틀버스가 없습니다.", "");
      case ShuttleStatusKind.beforeDeparture:
        return _ShuttleCopy(
          "${status.minutes}분 뒤 ${departure!.stopName}에서 출발",
          _formatDepartTime(departure),
        );
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
}

class _ShuttleCopy {
  const _ShuttleCopy(this.title, this.subtitle);

  final String title;
  final String subtitle;
}
