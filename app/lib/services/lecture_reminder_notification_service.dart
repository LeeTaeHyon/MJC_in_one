import "dart:async";
import "dart:io" show Platform;

import "package:flutter/foundation.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:mjc_in_one/features/timetable/models/timetable_models.dart";
import "package:mjc_in_one/features/timetable/utils/timetable_next_lecture.dart";
import "package:mjc_in_one/lecture_reminder_notification_prefs.dart";
import "package:mjc_in_one/services/lecture_reminder_content.dart";
import "package:mjc_in_one/services/lecture_reminder_notification_platform.dart";
import "package:timezone/timezone.dart" as tz;

/// 홈 «강의 알림» 카드와 동일한 기준으로, 알림 패널에 다음 수업 안내를 유지합니다.
///
/// Android: 알림에 시스템 카운트다운(크로노미터)을 붙여 앱 없이도 남은 시간이 줄어듭니다.
/// iOS: 앱 실행 중 1분 타이머 + 백그라운드 예약 알림.
final class LectureReminderNotificationService {
  LectureReminderNotificationService._();

  static final LectureReminderNotificationService instance =
      LectureReminderNotificationService._();

  final FlutterLocalNotificationsPlugin _flnp =
      FlutterLocalNotificationsPlugin();

  Timer? _foregroundRefreshTimer;
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
    if (!Platform.isAndroid) {
      await ensureBackgroundUpdates();
    }
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

  /// iOS 백그라운드용 — Android는 크로노미터가 알아서 갱신합니다.
  Future<void> ensureBackgroundUpdates() async {
    if (!_supportedPlatform || Platform.isAndroid) return;
    if (!await LectureReminderNotificationPrefs.isEnabled()) return;
    await _scheduleIosBatchUpdates();
    _startForegroundRefreshTimer();
  }

  Future<void> refreshNow() async {
    if (!_supportedPlatform) return;
    if (!await LectureReminderNotificationPrefs.isEnabled()) {
      await stop();
      return;
    }
    await ensureInitialized();

    final LectureReminderPresentation? presentation =
        await buildLectureReminderPresentation();
    if (presentation == null) {
      await stop();
      return;
    }

    final TimetableSlot? slot = await resolveNextLectureSlot();
    final String? room = slot?.room.trim();

    await showLectureReminderNotification(
      _flnp,
      title: presentation.title,
      text: presentation.text,
      classStartEpochMs: presentation.classStartEpochMs,
      subText: room == null || room.isEmpty ? null : room,
    );

    if (Platform.isAndroid) {
      await _scheduleAndroidClassStartDismiss(presentation.classStartEpochMs);
      _stopForegroundRefreshTimer();
      return;
    }

    _startForegroundRefreshTimer();
  }

  Future<void> stop() async {
    _stopForegroundRefreshTimer();
    await _cancelIosScheduledBatch();
    await cancelLectureReminderClassStartSchedule(_flnp);
    if (_initialized) {
      await cancelLectureReminderNotification(_flnp);
    }
  }

  Future<void> _scheduleAndroidClassStartDismiss(int classStartEpochMs) async {
    await cancelLectureReminderClassStartSchedule(_flnp);

    final DateTime classStart =
        DateTime.fromMillisecondsSinceEpoch(classStartEpochMs);
    if (!classStart.isAfter(DateTime.now())) return;

    await _flnp.zonedSchedule(
      kLectureReminderClassStartScheduleId,
      "다음 수업",
      "곧 시작",
      tz.TZDateTime.from(classStart, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          kLectureReminderChannelId,
          kLectureReminderChannelName,
          channelDescription: kLectureReminderChannelDescription,
          importance: Importance.low,
          priority: Priority.low,
          autoCancel: true,
          tag: "mjc_lecture_reminder",
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _scheduleIosBatchUpdates() async {
    await _cancelIosScheduledBatch();

    final slot = await resolveNextLectureSlot();
    if (slot == null) return;

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final int nowMin = now.hour * 60 + now.minute;
    final int classStartMin = slot.startMinute;
    final int minutesLeft = classStartMin - nowMin;
    if (minutesLeft <= 0) return;

    final String title =
        "${slot.courseName} ${TimetableNextLecture.formatStartTimeHm(slot.startMinute)}";
    final int scheduleCount = minutesLeft.clamp(1, 120);

    for (int i = 1; i <= scheduleCount; i++) {
      final tz.TZDateTime when = now.add(Duration(minutes: i));
      final int untilMin = classStartMin - (when.hour * 60 + when.minute);
      if (untilMin < 0) break;

      final String body = TimetableNextLecture.formatRemainingKo(untilMin);
      final String text =
          slot.room.trim().isEmpty ? body : "$body · ${slot.room.trim()}";

      await _flnp.zonedSchedule(
        kLectureReminderClassStartScheduleId + i,
        title,
        text,
        when,
        lectureReminderNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> _cancelIosScheduledBatch() async {
    for (int id = kLectureReminderClassStartScheduleId + 1;
        id <= kLectureReminderClassStartScheduleId + 120;
        id++) {
      await _flnp.cancel(id);
    }
  }

  void _startForegroundRefreshTimer() {
    _stopForegroundRefreshTimer();
    _foregroundRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      refreshNow();
    });
  }

  void _stopForegroundRefreshTimer() {
    _foregroundRefreshTimer?.cancel();
    _foregroundRefreshTimer = null;
  }

  void dispose() {
    _stopForegroundRefreshTimer();
  }
}
