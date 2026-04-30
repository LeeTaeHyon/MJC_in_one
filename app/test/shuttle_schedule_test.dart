import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mio_notice/services/shuttle_schedule.dart";

void main() {
  final ShuttleScheduleService service = ShuttleScheduleService();
  final List<ShuttleDeparture> departures = [
    _departure("학교", 8, 0, "가좌역", 13),
    _departure("가좌역", 8, 13, "홍대역", 12),
    _departure("홍대역", 8, 25, "학교", 25),
    _departure("학교", 9, 0, "가좌역", 13),
    _departure("가좌역", 9, 13, "홍대역", 12),
    _departure("홍대역", 9, 25, "학교", 25),
    _departure("학교", 15, 0, "가좌역", 13),
    _departure("가좌역", 15, 13, "홍대역", 12),
    _departure("홍대역", 15, 25, "학교", 25),
    _departure("학교", 17, 55, "가좌역", 10),
    _departure("가좌역", 18, 5, "홍대역", 10),
    _departure("홍대역", 18, 15, "학교", 25),
  ];

  test("05:59부터 06:00 전까지는 셔틀 마감 상태다", () {
    final ShuttleStatus status = service.nextStatus(
      _mondayAt(5, 59),
      departures,
    );

    expect(status.kind, ShuttleStatusKind.closed);
  });

  test("06:00 이후 첫차 전에는 08:00 학교 출발을 안내한다", () {
    final ShuttleStatus status = service.nextStatus(
      _mondayAt(6, 0),
      departures,
    );

    expect(status.kind, ShuttleStatusKind.beforeDeparture);
    expect(status.departure?.stopName, "학교");
    expect(status.departure?.departTime, const TimeOfDay(hour: 8, minute: 0));
  });

  test("운행 중에는 현재 구간과 남은 도착 시간을 계산한다", () {
    final ShuttleStatus status = service.nextStatus(
      _mondayAt(8, 5),
      departures,
    );

    expect(status.kind, ShuttleStatusKind.enRoute);
    expect(status.departure?.stopName, "학교");
    expect(status.departure?.arriveStop, "가좌역");
    expect(status.minutes, 8);
    expect(status.progress, greaterThan(0));
  });

  test("학교 복귀 후 다음 회차 전에는 학교 출발 대기 상태다", () {
    final ShuttleStatus status = service.nextStatus(
      _mondayAt(8, 55),
      departures,
    );

    expect(status.kind, ShuttleStatusKind.beforeDeparture);
    expect(status.departure?.stopName, "학교");
    expect(status.minutes, 5);
  });

  test("09:50 이후 오후 첫차 전에는 오전 셔틀 마감 상태다", () {
    final ShuttleStatus status = service.nextStatus(
      _mondayAt(9, 50),
      departures,
    );

    expect(status.kind, ShuttleStatusKind.morningFinished);
    expect(status.departure?.departTime, const TimeOfDay(hour: 15, minute: 0));
  });

  test("14:30에도 오후 15:00 학교 출발을 안내한다", () {
    final ShuttleStatus status = service.nextStatus(
      _mondayAt(14, 30),
      departures,
    );

    expect(status.kind, ShuttleStatusKind.morningFinished);
    expect(status.minutes, 30);
  });

  test("18:39에는 마지막 복귀 구간 운행 중이다", () {
    final ShuttleStatus status = service.nextStatus(
      _mondayAt(18, 39),
      departures,
    );

    expect(status.kind, ShuttleStatusKind.enRoute);
    expect(status.departure?.stopName, "홍대역");
    expect(status.departure?.arriveStop, "학교");
    expect(status.minutes, 1);
  });

  test("18:40부터 익일 06:00 전까지는 셔틀 마감 상태다", () {
    final ShuttleStatus status = service.nextStatus(
      _mondayAt(18, 40),
      departures,
    );

    expect(status.kind, ShuttleStatusKind.closed);
  });

  test("익일 06:00 전에는 요일이 바뀌어도 셔틀 마감 상태다", () {
    final ShuttleStatus status = service.nextStatus(
      DateTime(2026, 5, 9, 5, 59),
      departures,
    );

    expect(status.kind, ShuttleStatusKind.closed);
  });
}

ShuttleDeparture _departure(
  String stopName,
  int hour,
  int minute,
  String arriveStop,
  int travelMin,
) {
  return ShuttleDeparture(
    stopName: stopName,
    departTime: TimeOfDay(hour: hour, minute: minute),
    weekdays: const {1, 2, 3, 4, 5},
    arriveStop: arriveStop,
    travelMin: travelMin,
  );
}

DateTime _mondayAt(int hour, int minute) {
  return DateTime(2026, 5, 4, hour, minute);
}
