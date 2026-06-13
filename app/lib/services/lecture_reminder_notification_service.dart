import "dart:io" show Platform;

import "package:flutter/foundation.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:mjc_in_one/features/timetable/models/timetable_models.dart";
import "package:mjc_in_one/features/timetable/services/timetable_storage_service.dart";
import "package:mjc_in_one/features/timetable/utils/timetable_next_lecture.dart";
import "package:mjc_in_one/lecture_reminder_notification_prefs.dart";
import "package:mjc_in_one/services/lecture_reminder_notification_platform.dart";
import "package:timezone/timezone.dart" as tz;

/// 홈 «강의 알림» 카드와 별개로, 설정된 시간에 맞춰 푸시 알림을 스케줄링합니다.
final class LectureReminderNotificationService {
  LectureReminderNotificationService._();

  static final LectureReminderNotificationService instance =
      LectureReminderNotificationService._();

  final FlutterLocalNotificationsPlugin _flnp =
      FlutterLocalNotificationsPlugin();

  /// 알림·정확한 알람 권한 확인/요청은 이 인스턴스만 사용한다.
  FlutterLocalNotificationsPlugin get notificationsPlugin => _flnp;

  bool _initialized = false;

  bool get _supportedPlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> ensureInitialized() async {
    if (!_supportedPlatform || _initialized) return;
    await ensureLectureReminderNotificationChannel(_flnp);
    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    if (!_supportedPlatform) return true;
    await ensureInitialized();
    if (Platform.isAndroid) {
      return requestLectureReminderAndroidPermissions(_flnp);
    }
    return true;
  }

  Future<void> startIfEnabled() async {
    if (!_supportedPlatform) return;
    await ensureInitialized();
    if (!await LectureReminderNotificationPrefs.isEnabled()) {
      await stop();
      return;
    }
    await refreshNow();
  }

  Future<void> setEnabled(bool enabled) async {
    await LectureReminderNotificationPrefs.setEnabled(enabled);
    if (!_supportedPlatform) return;
    if (enabled) {
      await startIfEnabled();
      return;
    }
    await stop();
  }

  Future<void> refreshNow() async {
    if (!_supportedPlatform) return;
    await ensureInitialized();

    // 1. 기존에 예약된 모든 강의 알림 취소
    await _cancelAllScheduledReminders();

    if (!await LectureReminderNotificationPrefs.isEnabled()) return;

    // 2. 전체 시간표 가져오기
    final List<ParsedCourseOffering> enrolled =
        await TimetableStorageService.loadEnrolled();

    // 3. 설정값 확인
    final bool exactEnabled =
        await LectureReminderNotificationPrefs.isExactEnabled();
    final bool m10Enabled =
        await LectureReminderNotificationPrefs.is10mEnabled();
    final bool m30Enabled =
        await LectureReminderNotificationPrefs.is30mEnabled();
    final bool m60Enabled =
        await LectureReminderNotificationPrefs.is60mEnabled();
    final bool firstOnly =
        await LectureReminderNotificationPrefs.isFirstClassOnlyEnabled();

    // 4. 주간 스케줄링 (요일과 시간 기준 반복 알림)
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    debugPrint("[알림] 주간 반복 스케줄링 시작 (전체 요일 대상)");

    for (int wd = 1; wd <= 7; wd++) {
      final List<TimetableSlot> daySlots = TimetableNextLecture.allSlotsForWeekday(enrolled, wd);
      if (daySlots.isEmpty) continue;

      for (int i = 0; i < daySlots.length; i++) {
        final TimetableSlot slot = daySlots[i];
        if (firstOnly && i > 0) break;

        final int baseId = 91000 + (wd * 1000) + slot.startMinute;
        final String roomText =
            slot.room.trim().isEmpty ? "" : " · ${slot.room.trim()}";

        // 해당 요일/시간의 가장 가까운 미래의 시간표 시작 시간을 구합니다.
        tz.TZDateTime classStart = tz.TZDateTime(
          tz.local, now.year, now.month, now.day,
          slot.startMinute ~/ 60, slot.startMinute % 60,
        );
        while (classStart.weekday != wd || classStart.isBefore(now)) {
          classStart = classStart.add(const Duration(days: 1));
        }

        if (exactEnabled) {
          await _scheduleWeekly(
            id: baseId,
            alarmTime: classStart,
            title: "수업 시작",
            body: "${slot.courseName} 수업이 시작되었습니다.$roomText",
          );
        }
        if (m10Enabled) {
          tz.TZDateTime t = classStart.subtract(const Duration(minutes: 10));
          if (t.isBefore(now)) t = t.add(const Duration(days: 7));
          await _scheduleWeekly(
            id: baseId + 1,
            alarmTime: t,
            title: "수업 시작 10분 전",
            body: "${slot.courseName} 수업이 10분 뒤 시작됩니다.$roomText",
          );
        }
        if (m30Enabled) {
          tz.TZDateTime t = classStart.subtract(const Duration(minutes: 30));
          if (t.isBefore(now)) t = t.add(const Duration(days: 7));
          await _scheduleWeekly(
            id: baseId + 2,
            alarmTime: t,
            title: "수업 시작 30분 전",
            body: "${slot.courseName} 수업이 30분 뒤 시작됩니다.$roomText",
          );
        }
        if (m60Enabled) {
          tz.TZDateTime t = classStart.subtract(const Duration(minutes: 60));
          if (t.isBefore(now)) t = t.add(const Duration(days: 7));
          await _scheduleWeekly(
            id: baseId + 3,
            alarmTime: t,
            title: "수업 시작 1시간 전",
            body: "${slot.courseName} 수업이 1시간 뒤 시작됩니다.$roomText",
          );
        }
      }
    }
    debugPrint("[알림] refreshNow 완료 (주간 반복 알람)");
  }

  Future<void> _scheduleWeekly({
    required int id,
    required tz.TZDateTime alarmTime,
    required String title,
    required String body,
  }) async {
    try {
      await _flnp.zonedSchedule(
        id,
        title,
        body,
        alarmTime,
        scheduledLectureReminderNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
      debugPrint("[알림] ✅ 예약 성공 id=$id '$title' at $alarmTime");
    } catch (e) {
      debugPrint("[알림] ⚠️ 정확한 알람 예약 실패, 일반 알람으로 대체: $e");
      try {
        await _flnp.zonedSchedule(
          id,
          title,
          body,
          alarmTime,
          scheduledLectureReminderNotificationDetails(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
        debugPrint("[알림] ✅ 일반 알람 예약 성공 id=$id '$title' at $alarmTime");
      } catch (e2) {
        debugPrint("[알림] ❌ 알람 스케줄링 최종 실패: $e2");
      }
    }
  }

  Future<void> stop() async {
    if (_initialized) {
      await _cancelAllScheduledReminders();
    }
  }

  Future<void> _cancelAllScheduledReminders() async {
    // 기존에 있던 91001, 91002 고정 ID 취소
    await _flnp.cancel(91001);
    await _flnp.cancel(91002);
    // 새로 도입한 91000 ~ 99999 대역 취소
    final List<PendingNotificationRequest> pending =
        await _flnp.pendingNotificationRequests();
    for (final PendingNotificationRequest req in pending) {
      if (req.id >= 91000 && req.id < 99999) {
        await _flnp.cancel(req.id);
      }
    }
  }

  void dispose() {}
}
