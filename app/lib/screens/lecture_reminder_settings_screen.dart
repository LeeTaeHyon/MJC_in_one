import "package:flutter/material.dart";
import "package:mjc_in_one/debug/app_debug_flags.dart";
import "package:mjc_in_one/features/timetable/models/timetable_models.dart";
import "package:mjc_in_one/features/timetable/services/timetable_storage_service.dart";
import "package:mjc_in_one/lecture_reminder_notification_prefs.dart";
import "package:mjc_in_one/services/lecture_reminder_notification_platform.dart";
import "package:mjc_in_one/services/lecture_reminder_notification_service.dart";
import "package:mjc_in_one/utils/mjc_snack_bar.dart";
import "package:permission_handler/permission_handler.dart";
import "dart:io" show Platform;

class LectureReminderSettingsScreen extends StatefulWidget {
  const LectureReminderSettingsScreen({super.key});

  @override
  State<LectureReminderSettingsScreen> createState() =>
      _LectureReminderSettingsScreenState();
}

class _LectureReminderSettingsScreenState
    extends State<LectureReminderSettingsScreen> {
  bool _exactEnabled = true;
  bool _m10Enabled = false;
  bool _m30Enabled = false;
  bool _m60Enabled = false;
  bool _firstOnlyEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final exact = await LectureReminderNotificationPrefs.isExactEnabled();
    final m10 = await LectureReminderNotificationPrefs.is10mEnabled();
    final m30 = await LectureReminderNotificationPrefs.is30mEnabled();
    final m60 = await LectureReminderNotificationPrefs.is60mEnabled();
    final firstOnly =
        await LectureReminderNotificationPrefs.isFirstClassOnlyEnabled();

    if (!mounted) return;
    setState(() {
      _exactEnabled = exact;
      _m10Enabled = m10;
      _m30Enabled = m30;
      _m60Enabled = m60;
      _firstOnlyEnabled = firstOnly;
    });
  }

  Future<void> _updateSetting(Future<void> Function(bool) saver, bool value,
      void Function(bool) updater) async {
    await saver(value);
    if (!mounted) return;
    setState(() {
      updater(value);
    });
    // 설정을 바꿀 때마다 스케줄을 즉시 갱신합니다.
    await LectureReminderNotificationService.instance.refreshNow();
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color accent =
        dark ? const Color(0xFFD1D5DB) : const Color(0xFF374151);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required Widget child}) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool light = Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Material(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: light
                ? const Color(0xFFEDEDED)
                : scheme.outline.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }

  Widget _hairlineDivider(BuildContext context) {
    final bool light = Theme.of(context).brightness == Brightness.light;
    return Divider(
      height: 1,
      thickness: 1,
      color: light
          ? const Color(0xFFEDEDED)
          : Theme.of(context).colorScheme.outline.withValues(alpha: 0.35),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFF5F7F9)
        : Theme.of(context).colorScheme.surfaceContainerLow;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text("강의 알림 상세 설정"),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          if (Platform.isAndroid) ...[
            _buildSectionHeader(
                context, "시스템 권한", Icons.settings_applications_outlined),
            _buildCard(
              context,
              child: ListTile(
                leading: const Icon(Icons.battery_alert_outlined),
                title: const Text("배터리 최적화 제외 설정 (권장)"),
                subtitle: const Text(
                    "앱을 완전히 종료해도 강의 알람이 제때 울리도록 백그라운드 배터리 제한을 해제합니다."),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final status =
                      await Permission.ignoreBatteryOptimizations.status;
                  if (status.isGranted) {
                    if (context.mounted) {
                      showUniqueMjcSnackBar(
                        context,
                        key: "battery_opt_already",
                        message: "이미 배터리 최적화 예외로 설정되어 있습니다.",
                      );
                    }
                  } else {
                    final result =
                        await Permission.ignoreBatteryOptimizations.request();
                    if (context.mounted) {
                      if (result.isGranted) {
                        showUniqueMjcSnackBar(
                          context,
                          key: "battery_opt_granted",
                          message: "배터리 최적화 예외 설정이 완료되었습니다.",
                        );
                      } else {
                        showUniqueMjcSnackBar(
                          context,
                          key: "battery_opt_denied",
                          message:
                              "예외 설정이 거부되었거나 기기에서 지원하지 않습니다. 설정 > 애플리케이션에서 수동으로 제한 없음을 선택해주세요.",
                        );
                      }
                    }
                  }
                },
              ),
            ),
          ],
          _buildSectionHeader(
              context, "사전 알림 설정", Icons.notifications_active_outlined),
          _buildCard(
            context,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("강의 10분 전 알림"),
                  value: _m10Enabled,
                  onChanged: (val) => _updateSetting(
                      LectureReminderNotificationPrefs.set10mEnabled,
                      val,
                      (v) => _m10Enabled = v),
                ),
                _hairlineDivider(context),
                SwitchListTile(
                  title: const Text("강의 30분 전 알림"),
                  value: _m30Enabled,
                  onChanged: (val) => _updateSetting(
                      LectureReminderNotificationPrefs.set30mEnabled,
                      val,
                      (v) => _m30Enabled = v),
                ),
                _hairlineDivider(context),
                SwitchListTile(
                  title: const Text("강의 60분 전 알림"),
                  value: _m60Enabled,
                  onChanged: (val) => _updateSetting(
                      LectureReminderNotificationPrefs.set60mEnabled,
                      val,
                      (v) => _m60Enabled = v),
                ),
              ],
            ),
          ),
          _buildSectionHeader(context, "기타 알림 설정", Icons.tune_rounded),
          _buildCard(
            context,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("정각(강의 시작) 알림"),
                  subtitle: const Text("수업이 시작되는 시간에 맞춰 알려줍니다."),
                  value: _exactEnabled,
                  onChanged: (val) => _updateSetting(
                      LectureReminderNotificationPrefs.setExactEnabled,
                      val,
                      (v) => _exactEnabled = v),
                ),
                _hairlineDivider(context),
                SwitchListTile(
                  title: const Text("첫 수업만 알림"),
                  subtitle: const Text(
                      "하루에 연강이 여러 개 있을 때, 가장 일찍 시작하는 첫 수업에만 알림을 울립니다."),
                  value: _firstOnlyEnabled,
                  onChanged: (val) => _updateSetting(
                      LectureReminderNotificationPrefs.setFirstClassOnlyEnabled,
                      val,
                      (v) => _firstOnlyEnabled = v),
                ),
              ],
            ),
          ),
          if (AppDevFeatures.lectureReminderTestButtons) ...[
            _buildSectionHeader(context, "디버그 도구", Icons.bug_report_outlined),
            _buildCard(
              context,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        showMjcSnackBar(context, message: "5초 뒤에 테스트 알림이 울립니다!");
                        await Future.delayed(const Duration(seconds: 5));
                        final flnp = LectureReminderNotificationService
                            .instance.notificationsPlugin;
                        await flnp.show(
                          99999,
                          "테스트 알림",
                          "강의 알림이 정상적으로 작동합니다.",
                          scheduledLectureReminderNotificationDetails(),
                        );
                      },
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text("단순 알림 팝업 띄우기 (5초 뒤)"),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final DateTime now = DateTime.now();
                        final int startMin = now.hour * 60 + now.minute + 2;
                        final ParsedCourseOffering dummy = ParsedCourseOffering(
                          offeringId: "test_dummy_001",
                          courseCategory: "전공필수",
                          department: "테스트학과",
                          courseName: "⏰ 알림 테스트용 가짜 강의",
                          section: "01",
                          professor: "제미나이",
                          gradeYear: "1",
                          completionType: "전필",
                          credits: "3",
                          rawTimetableText: "",
                          slots: [
                            TimetableSlot(
                              weekday: now.weekday,
                              startMinute: startMin,
                              endMinute: startMin + 60,
                              room: "테스트강의실",
                              courseName: "⏰ 알림 테스트용 가짜 강의",
                              offeringId: "test_dummy_001",
                              colorKey: "알림 테스트|01",
                            ),
                          ],
                        );

                        final existing =
                            await TimetableStorageService.loadEnrolled();
                        existing.removeWhere(
                            (e) => e.offeringId == "test_dummy_001");
                        existing.add(dummy);
                        await TimetableStorageService.saveEnrolled(existing);

                        // 설정 갱신 강제 호출
                        await LectureReminderNotificationService.instance
                            .refreshNow();

                        if (context.mounted) {
                          showMjcSnackBar(
                            context,
                            message: "시간표에 2분 뒤 시작하는 가짜 강의가 추가되고 알림이 예약되었습니다! 아무것도 하지 말고 2분만 기다려 보세요.",
                            duration: const Duration(seconds: 4),
                          );
                        }
                      },
                      icon: const Icon(Icons.schedule_outlined),
                      label: const Text("진짜 스케줄러 테스트 (가짜 강의 추가)"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final existing =
                            await TimetableStorageService.loadEnrolled();
                        existing.removeWhere(
                            (e) => e.offeringId == "test_dummy_001");
                        await TimetableStorageService.saveEnrolled(existing);

                        // 설정 갱신 강제 호출
                        await LectureReminderNotificationService.instance
                            .refreshNow();

                        if (context.mounted) {
                          showMjcSnackBar(context, message: "테스트용 가짜 강의가 삭제되었습니다!");
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text("가짜 강의 삭제하기"),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
