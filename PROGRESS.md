# MJC in one — 구현 진행 요약

코드베이스(`app/lib`, `main.dart`, `pubspec.yaml`, `test/`, `tools/`) 기준으로 정리했습니다. 배포·운영 환경(Firebase 콘솔, 스토어 심사 등)은 제외됩니다.

---

## 완성됨

앱의 핵심 사용자 흐름 및 주요 편의 기능이 동작하는 수준으로 구현된 항목입니다.

- **앱 셸·내비게이션**  
  - 하단 탭 + FAB 확장 메뉴, `AnimatedSwitcher` 전환  
  - 스캐폴드 드로어 + 홈 전용 슬라이드 메뉴(엣지 제스처·스냅)  
  - 시스템 뒤로가기: 드로어·메뉴·탭 히스토리·종료 순 처리

- **홈 대시보드**  
  - Firestore 경로를 묶는 `NoticeManager`로 **최근 2주** 통합 피드(공지·학사·장학·역량·CTL 등)  
  - 당겨서 새로고침, 공지 카드·상세 웹뷰 이동, MPU 바로가기 등

- **메인 홈페이지 / CTL / MPU 화면**  
  - 탭별 공지·프로그램 목록, `NestedScrollView` + 당겨서 새로고침  
  - 항목 탭 시 `CommonWebViewScreen`으로 원문 URL 표시  
  - 목록 입장 애니메이션(`flutter_animate`) 등 UX 마감

- **학과 공지 (Community Notices)**
  - 학과별 특화 공지 피드 및 사용자 경험 개선
  - 학과 공지 상세 화면 및 브랜드 컬러 연동

- **캠퍼스 편의 기능 (통학·교통·캠퍼스 이동)**
  - **캠퍼스 맵**: `campus_map_screen.dart`를 통한 교내 건물 위치 및 세부 정보 제공
  - **학식 메뉴**: `foodcourt_menu_screen.dart`
  - **셔틀버스**: `shuttle_schedule.dart`를 통한 시간표 제공
  - **학사 일정**: `academic_schedule_screen.dart` 연동

- **계정 및 프로필 연동**
  - 로그인/로그아웃 흐름 구현 (`login_screen.dart`)
  - 마이페이지 및 프로필 설정 (`my_page_screen.dart`, `profile_setup_screen.dart`)
  - Firebase Auth 기반 계정 연동 및 데이터 관리 (`auth_service.dart`, `user_data_repository.dart`)

- **알림 및 딥링크**  
  - FCM 수신, 전체·키워드 필터, 출처 스위치 (MJC·CTL·MPU)
  - **푸시 탭 시 딥링크 이동**: 알림 탭 시 해당 공지 및 상세 화면으로 연결 (`deep_link_handler.dart`)
  - **강의 리마인더**: 로컬 푸시 기반 강의 시작 전 알림 (`lecture_reminder_settings_screen.dart`)
  - 알림 내역 저장 및 관리 기능

- **설정·정보 및 개발자 도구**  
  - 설정 화면(알림·키워드·계정 등), 개발자 메일 문의(`mailto` 및 앱 내 폼)
  - **공지 신고 기능**: `notice_report_screen.dart`
  - 오픈소스 라이선스 전용 화면

- **데이터 수집 및 크롤러 파이프라인**
  - Python 기반 크롤러(`test/`, `tools/` 등) 구현 완료
  - **GitHub Actions 연동**: 스케줄러 기반 자동화 크롤링 파이프라인 구축 완료 (Connection Timeout 이슈 등 안정화)
  - 손쉬운 수동 업로드를 위한 GUI 매니저 툴 구현

---

## 보완 필요

동작은 하나, 품질·플랫폼·유지보수 측에서 손보면 좋은 항목입니다.

- **웹 빌드**  
  - Firebase 미구성 시 웹에서는 푸시·Firestore 의존 기능이 제한되거나 비어 보일 수 있음.
- **로컬 알림 초기화**  
  - iOS 등 타 플랫폼 알림 설정 및 권한 최적화.
- **데이터 레이어 및 오프라인 대응**  
  - 실시간 갱신 및 캐시 정책(Cache-first 등) 고도화 필요.
- **날짜·통합 로직 보완**  
  - 특정 비표기 포맷의 날짜 파싱 안정성 추가 확보.
- **전역 하드코딩 속성 분리**  
  - 앱 이름·버전 문자열을 단일 소스(`package_info_plus` 등)로 완전 일원화.
- **도움말·온보딩**  
  - 첫 실행 가이드라인, 튜토리얼 또는 FAQ 페이지 추가 필요.
- **테스트 커버리지**  
  - 비즈니스 로직(Unit Test) 및 주요 화면 통합 테스트(Integration Test) 보강.

---

## 미완성(예정)

루트 `README.md`의 비전 대비 앱 코드에 아직 없거나, 추가 확장이 필요한 항목입니다.

- **앱 전역 검색 기능**
  - 전체 게시판 및 공지를 아우르는 통합 검색 시스템 (Firestore 색인 및 Algolia 등 연계 고려)
- **즐겨찾기(북마크) 기능**
  - 공지사항 개별 북마크 및 오프라인 보관함 기능
- **스토어 배포 최적화**
  - Play Store / App Store 배포용 에셋(스크린샷, CI 등) 정비 및 배포 파이프라인(CI/CD) 완전 자동화

---

*마지막 코드 기준 정리: 2026-06-06*
