import "package:flutter/foundation.dart";

/// 개발·디자인 확인용 기능 **일괄** 스위치.
///
/// `false`면 아래 개별 `k*Enabled` 값과 관계없이 전부 비활성됩니다.
/// release 빌드에서는 항상 비활성입니다.
const bool kAppDevFeaturesEnabled = false;

/// 앱 전역 문의(피드백) FAB — [main.dart] `MaterialApp.builder`
const bool kGlobalInquiryFabEnabled = true;

/// 홈 강의 알림 카드 — 수업 없어도 샘플 카드 표시 (디자인 확인)
const bool kLectureReminderDesignPreview = true;

/// 맨 위로 FAB 중복 디버깅 — [scroll_fab_debug.dart]
const bool kScrollFabDebugEnabled = true;

/// 앱 첫 진입 시 테스트 빌드 안내 다이얼로그 — [main_navigation_screen.dart]
const bool kStartupTestBuildWarningEnabled = true;

/// 첫 진입 시 문의(피드백) FAB 포커스 오버레이 — [main_navigation_screen.dart]
const bool kStartupInquiryFocusOverlayEnabled = true;

/// 캠퍼스 약도 — 집에서 테스트용 가짜 GPS(모의 위치) — [campus_map_screen.dart]
const bool kCampusMapMockGpsEnabled = true;

/// 개발용 기능 on/off (마스터 + release 가드).
abstract final class AppDevFeatures {
  AppDevFeatures._();

  static bool get active => kAppDevFeaturesEnabled && !kReleaseMode;

  static bool get globalInquiryFab => active && kGlobalInquiryFabEnabled;

  static bool get lectureReminderDesignPreview =>
      active && kLectureReminderDesignPreview && kDebugMode;

  static bool get scrollFabDebug => active && kScrollFabDebugEnabled;

  /// 첫 실행 안내(테스트 빌드·문의 FAB) — dev 마스터와 무관, const만으로 on/off.
  static bool get startupTestBuildWarning => kStartupTestBuildWarningEnabled;

  static bool get startupInquiryFocusOverlay =>
      kStartupInquiryFocusOverlayEnabled;

  static bool get campusMapMockGps => active && kCampusMapMockGpsEnabled;
}
