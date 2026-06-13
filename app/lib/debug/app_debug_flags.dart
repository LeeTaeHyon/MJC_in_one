import "package:flutter/foundation.dart";

/// 개발·디자인 확인용 기능 **일괄** 스위치.
///
/// `false`면 아래 개별 `k*Enabled` 값과 관계없이 전부 비활성됩니다.
/// release 빌드에서는 항상 비활성입니다.
const bool kAppDevFeaturesEnabled = true;

/// 앱 전역 문의(피드백) FAB — [main.dart] `MaterialApp.builder`
const bool kGlobalInquiryFabEnabled = false;

/// 홈 강의 알림 카드 — 수업 없어도 샘플 카드 표시 (디자인 확인)
const bool kLectureReminderDesignPreview = false;

/// 맨 위로 FAB 중복 디버깅 — [scroll_fab_debug.dart]
const bool kScrollFabDebugEnabled = false;

/// 앱 첫 진입 시 테스트 빌드 안내 다이얼로그 — [main_navigation_screen.dart]
const bool kStartupTestBuildWarningEnabled = false;

/// 첫 진입 시 문의(피드백) FAB 포커스 오버레이 — [main_navigation_screen.dart]
const bool kStartupInquiryFocusOverlayEnabled = false;

/// 문의 화면 상단 개발 로그(Test Build) — [inquiry_screen.dart]
const bool kInquiryDevLogSectionEnabled = false;

/// 캠퍼스 약도 — 집에서 테스트용 가짜 GPS(모의 위치) — [campus_map_screen.dart]
const bool kCampusMapMockGpsEnabled = false;

/// 강의 알림 설정 화면 — 알림 스케줄러 디버그/테스트 버튼들 활성화
const bool kLectureReminderTestButtonsEnabled = true;

/// 개발용 기능 on/off (마스터 + release 가드).
abstract final class AppDevFeatures {
  AppDevFeatures._();

  static bool get active => kAppDevFeaturesEnabled && !kReleaseMode;

  static bool get globalInquiryFab => active && kGlobalInquiryFabEnabled;

  static bool get lectureReminderDesignPreview =>
      active && kLectureReminderDesignPreview && kDebugMode;

  static bool get scrollFabDebug => active && kScrollFabDebugEnabled;

  static bool get startupTestBuildWarning =>
      active && kStartupTestBuildWarningEnabled;

  static bool get startupInquiryFocusOverlay =>
      active && kStartupInquiryFocusOverlayEnabled;

  static bool get inquiryDevLogSection =>
      active && kInquiryDevLogSectionEnabled;

  static bool get campusMapMockGps => active && kCampusMapMockGpsEnabled;

  static bool get lectureReminderTestButtons =>
      active && kLectureReminderTestButtonsEnabled;
}
