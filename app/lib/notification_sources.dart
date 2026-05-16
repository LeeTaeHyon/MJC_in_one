import "package:mjc_in_one/services/app_config_service.dart";

/// FCM data `source` 값과 설정에 저장하는 출처 id (mjc / ctl / mpu).
const String kNotificationSourcesPrefKey = "notification_sources";

/// MPU 화면·푸시에서 공통으로 여는 포털 주소 (`mpu_screen` 카드 탭과 동일).
const String kMpuPortalWebUrl = "https://mpu.mjc.ac.kr/Main/default.aspx";

const List<String> kNotificationSourceIds = ["mjc", "ctl", "mpu"];

List<String> defaultNotificationSources() =>
    List<String>.from(kNotificationSourceIds);

Future<String> loadMpuPortalWebUrl() async {
  try {
    final String? url = await AppConfigService.loadLink("mpuPortalUrl");
    return url ?? kMpuPortalWebUrl;
  } catch (_) {
    return kMpuPortalWebUrl;
  }
}

/// 크롤러가 넣은 `source`가 없을 때 기존 페이로드로 추정 (구버전 FCM 호환).
String resolveNotificationSource(Map<String, dynamic> data) {
  final raw = data["source"]?.toString().trim();
  if (raw != null && raw.isNotEmpty && kNotificationSourceIds.contains(raw)) {
    return raw;
  }
  final board = (data["board"] ?? "").toString();
  final title = (data["title"] ?? "").toString();
  if (board.contains("CTL") || title.contains("CTL")) return "ctl";
  if (board.contains("MPU") || title.contains("MPU")) return "mpu";
  return "mjc";
}
