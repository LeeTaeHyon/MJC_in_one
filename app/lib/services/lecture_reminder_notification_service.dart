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

    // 2. 오늘의 남은 수업들 가져오기
    final List<ParsedCourseOffering> enrolled =
        await TimetableStorageService.loadEnrolled();
    final List<TimetableSlot> upcoming =
        TimetableNextLecture.upcomingSlotsToday(enrolled);
    if (upcoming.isEmpty) return;

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

    // 4. 알림 스케줄링
    final DateTime now = DateTime.now();
    for (int i = 0; i < upcoming.length; i++) {
      final TimetableSlot slot = upcoming[i];
      if (firstOnly && i > 0) {
        // 첫 수업만 알림인데, 두 번째 이후 수업이면 건너뜀
        break;
      }

      final DateTime classStart = DateTime(
        now.year,
        now.month,
        now.day,
        slot.startMinute ~/ 60,
        slot.startMinute % 60,
      );
      final String roomText =
          slot.room.trim().isEmpty ? "" : " · ${slot.room.trim()}";

      final int baseId = 91000 + slot.startMinute * 10;

      if (exactEnabled && classStart.isAfter(now)) {
        await _schedule(
          id: baseId,
          time: classStart,
          title: "수업 시작",
          body: "${slot.courseName} 수업이 시작되었습니다.$roomText",
        );
      }
      if (m10Enabled) {
        final DateTime t = classStart.subtract(const Duration(minutes: 10));
        if (t.isAfter(now)) {
          await _schedule(
            id: baseId + 1,
            time: t,
            title: "수업 시작 10분 전",
            body: "${slot.courseName} 수업이 10분 뒤 시작됩니다.$roomText",
          );
        }
      }
      if (m30Enabled) {
        final DateTime t = classStart.subtract(const Duration(minutes: 30));
        if (t.isAfter(now)) {
          await _schedule(
            id: baseId + 2,
            time: t,
            title: "수업 시작 30분 전",
            body: "${slot.courseName} 수업이 30분 뒤 시작됩니다.$roomText",
          );
        }
      }
      if (m60Enabled) {
        final DateTime t = classStart.subtract(const Duration(minutes: 60));
        if (t.isAfter(now)) {
          await _schedule(
            id: baseId + 3,
            time: t,
            title: "수업 시작 1시간 전",
            body: "${slot.courseName} 수업이 1시간 뒤 시작됩니다.$roomText",
          );
        }
      }
    }
  }

  Future<void> _schedule({
    required int id,
    required DateTime time,
    required String title,
    required String body,
  }) async {
    await _flnp.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(time, tz.local),
      scheduledLectureReminderNotificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
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
