import "dart:io" show Platform;

import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:gal/gal.dart";
import "package:geolocator/geolocator.dart";
import "package:mjc_in_one/services/lecture_reminder_notification_platform.dart";

enum MjcPermissionState {
  granted,
  denied,
  notDetermined,
  deniedForever,
  serviceDisabled,
  notSupported,
}

class MjcPermissionInfo {
  const MjcPermissionInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.state,
    this.androidOnly = false,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final MjcPermissionState state;
  final bool androidOnly;

  bool get isGranted => state == MjcPermissionState.granted;

  bool get canRequest =>
      state == MjcPermissionState.denied ||
      state == MjcPermissionState.notDetermined;

  bool get shouldOpenSettings =>
      state == MjcPermissionState.deniedForever ||
      state == MjcPermissionState.serviceDisabled;

  String get stateLabel => switch (state) {
        MjcPermissionState.granted => "허용됨",
        MjcPermissionState.denied => "거부됨",
        MjcPermissionState.notDetermined => "미설정",
        MjcPermissionState.deniedForever => "설정에서 변경 필요",
        MjcPermissionState.serviceDisabled => "기기 설정 필요",
        MjcPermissionState.notSupported => "지원 안 함",
      };
}

/// 앱 기능별 휴대폰 권한 상태 확인·요청.
abstract final class AppPermissionChecker {
  static final FlutterLocalNotificationsPlugin _flnp =
      FlutterLocalNotificationsPlugin();

  static Future<List<MjcPermissionInfo>> loadAll() async {
    if (kIsWeb) {
      return const <MjcPermissionInfo>[
        MjcPermissionInfo(
          id: "web",
          title: "모바일 앱 전용",
          description: "권한 확인은 Android·iOS 앱에서만 가능합니다.",
          icon: Icons.smartphone_outlined,
          state: MjcPermissionState.notSupported,
        ),
      ];
    }

    final List<MjcPermissionInfo> items = <MjcPermissionInfo>[
      await _checkNotification(),
      await _checkLocation(),
      await _checkPhotoSave(),
    ];

    if (Platform.isAndroid) {
      items.insert(1, await _checkExactAlarm());
    }

    return items;
  }

  static Future<MjcPermissionInfo> _checkNotification() async {
    MjcPermissionState state = MjcPermissionState.notDetermined;

    if (Platform.isAndroid) {
      await ensureLectureReminderNotificationChannel(_flnp);
      final bool granted =
          await checkLectureReminderNotificationGranted(_flnp);
      state = granted ? MjcPermissionState.granted : MjcPermissionState.denied;
    } else if (Platform.isIOS) {
      final NotificationSettings settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      state = switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional =>
          MjcPermissionState.granted,
        AuthorizationStatus.denied => MjcPermissionState.denied,
        AuthorizationStatus.notDetermined => MjcPermissionState.notDetermined,
      };
    }

    return MjcPermissionInfo(
      id: "notification",
      title: "알림",
      description: "공지 새글·강의 알림·키워드 알림을 받을 때 필요합니다.",
      icon: Icons.notifications_outlined,
      state: state,
    );
  }

  static Future<MjcPermissionInfo> _checkExactAlarm() async {
    await ensureLectureReminderNotificationChannel(_flnp);
    final bool granted = await checkLectureReminderExactAlarmGranted(_flnp);
    return MjcPermissionInfo(
      id: "exact_alarm",
      title: "정확한 알람",
      description: "강의 알림을 앱 밖에서도 1분마다 갱신할 때 필요합니다.",
      icon: Icons.alarm_outlined,
      state: granted ? MjcPermissionState.granted : MjcPermissionState.denied,
      androidOnly: true,
    );
  }

  static Future<MjcPermissionInfo> _checkLocation() async {
    MjcPermissionState state = MjcPermissionState.notDetermined;

    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return MjcPermissionInfo(
        id: "location",
        title: "위치",
        description: "캠퍼스 약도에서 현재 위치를 표시할 때 필요합니다.",
        icon: Icons.location_on_outlined,
        state: MjcPermissionState.serviceDisabled,
      );
    }

    final LocationPermission permission = await Geolocator.checkPermission();
    state = switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse =>
        MjcPermissionState.granted,
      LocationPermission.denied => MjcPermissionState.denied,
      LocationPermission.deniedForever => MjcPermissionState.deniedForever,
      LocationPermission.unableToDetermine => MjcPermissionState.notDetermined,
    };

    return MjcPermissionInfo(
      id: "location",
      title: "위치",
      description: "캠퍼스 약도에서 현재 위치를 표시할 때 필요합니다.",
      icon: Icons.location_on_outlined,
      state: state,
    );
  }

  static Future<MjcPermissionInfo> _checkPhotoSave() async {
    MjcPermissionState state = MjcPermissionState.notDetermined;

    try {
      final bool hasAccess = await Gal.hasAccess(toAlbum: true);
      state =
          hasAccess ? MjcPermissionState.granted : MjcPermissionState.denied;
    } catch (_) {
      state = MjcPermissionState.notSupported;
    }

    return MjcPermissionInfo(
      id: "photos",
      title: "사진 저장",
      description: "공지 이미지를 갤러리에 저장할 때 필요합니다.",
      icon: Icons.photo_library_outlined,
      state: state,
    );
  }

  static Future<void> request(String id) async {
    if (kIsWeb) return;

    switch (id) {
      case "notification":
        if (Platform.isAndroid) {
          await ensureLectureReminderNotificationChannel(_flnp);
          await _flnp
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission();
          return;
        }
        if (Platform.isIOS) {
          await FirebaseMessaging.instance.requestPermission();
          return;
        }
      case "exact_alarm":
        if (Platform.isAndroid) {
          await ensureLectureReminderNotificationChannel(_flnp);
          await _flnp
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestExactAlarmsPermission();
        }
      case "location":
        await Geolocator.requestPermission();
      case "photos":
        await Gal.requestAccess(toAlbum: true);
    }
  }

  static Future<void> openSystemSettings(String id) async {
    if (kIsWeb) return;

    if (id == "location") {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        return;
      }
    }

    await Geolocator.openAppSettings();
  }
}
