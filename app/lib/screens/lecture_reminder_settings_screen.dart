import "package:flutter/material.dart";
import "package:mjc_in_one/lecture_reminder_notification_prefs.dart";
import "package:mjc_in_one/services/lecture_reminder_notification_platform.dart";
import "package:mjc_in_one/services/lecture_reminder_notification_service.dart";

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("강의 알림 상세 설정"),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "지정된 시간에 강의 시작을 알려주는 팝업 알림을 설정합니다. (스마트폰 알림창에 표시)",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text("정각(강의 시작) 알림"),
            subtitle: const Text("수업이 시작되는 시간에 맞춰 알려줍니다."),
            value: _exactEnabled,
            onChanged: (val) => _updateSetting(
                LectureReminderNotificationPrefs.setExactEnabled,
                val,
                (v) => _exactEnabled = v),
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text("강의 10분 전 알림"),
            value: _m10Enabled,
            onChanged: (val) => _updateSetting(
                LectureReminderNotificationPrefs.set10mEnabled,
                val,
                (v) => _m10Enabled = v),
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text("강의 30분 전 알림"),
            value: _m30Enabled,
            onChanged: (val) => _updateSetting(
                LectureReminderNotificationPrefs.set30mEnabled,
                val,
                (v) => _m30Enabled = v),
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text("강의 60분 전 알림"),
            value: _m60Enabled,
            onChanged: (val) => _updateSetting(
                LectureReminderNotificationPrefs.set60mEnabled,
                val,
                (v) => _m60Enabled = v),
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text("첫 수업만 알림"),
            subtitle: const Text("하루에 연강이 여러 개 있을 때, 가장 일찍 시작하는 첫 수업에만 알림을 울립니다."),
            value: _firstOnlyEnabled,
            onChanged: (val) => _updateSetting(
                LectureReminderNotificationPrefs.setFirstClassOnlyEnabled,
                val,
                (v) => _firstOnlyEnabled = v),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton.icon(
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("5초 뒤에 테스트 알림이 울립니다!")),
                );
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
              label: const Text("테스트 알림 보내기 (5초 뒤)"),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
