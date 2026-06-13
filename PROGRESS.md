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

- **통합 검색 기능**
  - 게시판별 `GlobalNoticeSearchSheet`를 통한 전체 공지 검색 (MJC / CTL / MPU / 학과별)
  - 실시간 필터링, 출처별 칩 분류, 키워드 하이라이트 지원

- **즐겨찾기(북마크) · 핀(고정) 기능**
  - 공지 개별 즐겨찾기(⭐) 및 상단 고정(📌) 기능 — 모든 게시판에서 사용 가능
  - `UserDataRepository`를 통한 클라우드 동기화 및 디바이스간 유지
  - 북마크 추가/제거 시 커스텀 스낵바 피드백

- **AI 태그 분류**
  - 크롤링된 공지에 AI 기반 카테고리 태그 자동 부여 (Gemini Flash 활용)
  - 메인 공지 화면에서 AI 태그 칩 필터 바로 제공 (`MainNoticeAiTagChipBar`)
  - 공지 상세 화면에서 태그 표시

- **공지 필터 시스템**
  - 게시판별 스코프 필터 (출처·유형·키워드 포함/제외)
  - `NoticeFilterSheet`를 통한 사용자 지정 필터 설정
  - 설정 화면에서 전역 키워드 필터 관리

- **캠퍼스 편의 기능 (통학·교통·캠퍼스 이동)**
  - **캠퍼스 맵**: `campus_map_screen.dart`를 통한 교내 건물 위치 및 세부 정보 제공
  - **학식 메뉴**: `foodcourt_menu_screen.dart`
  - **셔틀버스**: `shuttle_schedule.dart`를 통한 시간표 제공
  - **학사 일정**: `academic_schedule_screen.dart` 연동

- **시간표 기능**
  - 학기별 시간표 등록·관리 (`timetable` feature 모듈)
  - 공식 시간표 엑셀 파싱, 수동 입력, 주간 그리드 뷰
  - 다음 강의 표시, 학점 계산, 슬롯 병합 등 유틸리티

- **계정 및 프로필 연동**
  - 로그인/로그아웃 흐름 구현 (`login_screen.dart`)
  - 마이페이지 및 프로필 설정 (`my_page_screen.dart`, `profile_setup_screen.dart`)
  - MPU 마이페이지 웹뷰 스크래핑을 통한 프로필 자동 가져오기 (`mpu_profile_import_screen.dart`)
  - Firebase Auth 기반 계정 연동 및 데이터 관리 (`auth_service.dart`, `user_data_repository.dart`)

- **알림 및 딥링크**  
  - FCM 수신, 전체·키워드 필터, 출처 스위치 (MJC·CTL·MPU)
  - **푸시 탭 시 딥링크 이동**: 알림 탭 시 해당 공지 및 상세 화면으로 연결 (`deep_link_handler.dart`)
  - **강의 리마인더**: 로컬 푸시 기반 강의 시작 전 알림 (`lecture_reminder_settings_screen.dart`)
  - 알림 내역 저장·관리 및 카테고리별 탭 분류
  - 포그라운드 메시지 수신 시 알림 내역 자동 갱신, 앱 복귀 시 리로드

- **디자인 시스템 및 UI 일관성**
  - `MjcSurfaceTokens` / `MjcComponentTokens` / `MjcTextTokens` 기반 커스텀 테마 시스템
  - 출처별 브랜드 컬러 (`sourceMjc`, `sourceCtl`, `sourceMpu`) 일관 적용
  - 커스텀 스낵바 (`showMjcSnackBar` / `showUniqueMjcSnackBar`) 앱 전체 통일
  - 커스텀 다이얼로그 (`showMjcDialog`) 통일
  - 라이트/다크 모드 전면 지원

- **설정·정보 및 개발자 도구**  
  - 설정 화면(알림·키워드·계정 등), 개발자 메일 문의(`mailto` 및 앱 내 폼)
  - **공지 신고 기능**: `notice_report_screen.dart`
  - 오픈소스 라이선스 전용 화면

- **데이터 수집 및 크롤러 파이프라인**
  - Python 기반 크롤러(`test/`, `tools/` 등) 구현 완료
  - **GitHub Actions 연동**: 스케줄러 기반 자동화 크롤링 파이프라인 구축 완료 (Connection Timeout 이슈 등 안정화)
  - **AI 태그 자동 분류**: 크롤링 시 Gemini Flash API를 통한 공지 카테고리 태깅 자동화
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
- **도움말·온보딩**  
  - 첫 실행 가이드라인, 튜토리얼 또는 FAQ 페이지 추가 필요.
- **테스트 커버리지**  
  - 비즈니스 로직(Unit Test) 및 주요 화면 통합 테스트(Integration Test) 보강.

---

## 미완성(예정)

루트 `README.md`의 비전 대비 앱 코드에 아직 없거나, 추가 확장이 필요한 항목입니다.

- **스토어 배포 최적화**
  - Play Store / App Store 배포용 에셋(스크린샷, CI 등) 정비 및 배포 파이프라인(CI/CD) 완전 자동화
- **오프라인 북마크 보관함**
  - 즐겨찾기한 공지의 본문 콘텐츠를 오프라인에서도 볼 수 있도록 로컬 캐싱
- **위젯 (홈 화면 위젯)**
  - Android/iOS 홈 화면 위젯으로 다음 강의·최신 공지 요약 표시

---

*마지막 코드 기준 정리: 2026-06-13*
