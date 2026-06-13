# MJC in one

명지전문대학 재학생·통학생을 위한 **캠퍼스 공지·안내를 한곳에서 보는 모바일 앱** 프로젝트입니다.  
메인 홈페이지(mjc.ac.kr), CTL(ctl.mjc.ac.kr), MPU 핵심역량(mpu.mjc.ac.kr) 등 **흩어진 공지·프로그램 정보**를 앱 안에서 모아 보고, **Firebase 푸시**로 새 글 알림을 받을 수 있도록 하는 것을 목표로 합니다.

## 프로젝트 개요

| 항목 | 내용 |
|------|------|
| **소속·맥락** | MJC AI-DEAS 등 교내 프로그램 지원 하에 진행 |
| **클라이언트** | Flutter (`app/`, 패키지명 `mio_notice`) |
| **백엔드·데이터** | Cloud Firestore에 적재된 공지 메타데이터, FCM 토픽(`all_notices` 등) |
| **수집·연동** | Python 기반 크롤러 + GitHub Actions 자동화, Gemini Flash API를 통한 AI 태그 분류 |

## 저장소 구조

- **`app/`** — Flutter 앱 소스, Android/iOS/Web/Desktop 플랫폼 폴더 포함  
- **`test/`** — 크롤러·FCM 테스트 유틸·샘플 HTML 등 (앱 빌드와 독립)  
- **`PROGRESS.md`** — 구현 상태를 **완성됨 / 보완 필요 / 미완성(예정)** 으로 정리한 진행 노트 (코드 기준, 배포·운영 제외)

## 주요 기능

### 📢 공지·정보 통합
- **홈 대시보드**: Firestore 기반 최근 2주 통합 피드 (공지·학사·장학·역량·CTL 등)
- **게시판별 공지 목록**: 메인 홈페이지 / CTL 교수학습센터 / MPU 핵심역량 / 학과 공지 탭별 구성
- **인앱 웹뷰**: 공지 원문을 앱 내에서 바로 열람
- **통합 검색**: 게시판별 전체 공지 검색 (실시간 필터링·키워드 하이라이트)

### 🤖 AI 기반 분류
- **AI 태그 자동 부여**: 크롤링 시 Gemini Flash API로 공지 카테고리 자동 태깅
- **AI 태그 필터**: 메인 공지 화면에서 칩 바를 통한 카테고리별 즉시 필터링
- AI 모델 발전 경로: 휴리스틱 규칙 → Gemma 로컬 → Gemini Flash API

### 📌 북마크 · 필터
- **즐겨찾기(⭐) / 상단 고정(📌)**: 모든 게시판에서 개별 공지 북마크 및 핀 가능, 클라우드 동기화
- **공지 필터**: 출처·유형·키워드 기반 포함/제외 필터, 게시판별 스코프 분리

### 📅 시간표 · 강의 알림
- **시간표 관리**: 공식 엑셀 파싱 / 수동 입력, 주간 그리드 뷰, 학점 계산
- **강의 리마인더**: 로컬 푸시 기반 강의 시작 전 알림

### 🏫 캠퍼스 라이프
- **캠퍼스 맵** · **셔틀버스 시간표** · **학식 메뉴** · **학사 일정**
- **도서관 웹뷰** 등 교내 편의 정보

### 🔔 알림 · 계정
- **FCM 푸시 알림**: 새 공지 실시간 수신, 출처별·키워드별 필터, 딥링크로 해당 공지 바로 이동
- **알림 내역**: 카테고리별 탭 분류, 포그라운드 수신 시 자동 갱신
- **Firebase Auth 로그인**: 마이페이지, MPU 프로필 자동 가져오기

### 🎨 디자인
- `MjcSurfaceTokens` 기반 커스텀 테마 시스템, 출처별 브랜드 컬러 일관 적용
- 커스텀 스낵바·다이얼로그 앱 전체 통일
- 라이트/다크 모드 전면 지원

## 로드맵·한계 (요약)

- **보완 예정**: 타 플랫폼 로컬 알림 권한 최적화, 오프라인 데이터 캐싱 고도화, 테스트 커버리지 보강 등 — `PROGRESS.md` **보완 필요** 참고  
- **미구현·예정**: 오프라인 북마크 보관함, 홈 화면 위젯, 스토어 배포 파이프라인(CI/CD) 자동화 등 — `PROGRESS.md` **미완성(예정)** 참고

## 로컬에서 앱 실행하기

1. [Flutter](https://docs.flutter.dev/get-started/install) 설치 (SDK는 `app/pubspec.yaml`의 `environment.sdk`에 맞출 것). 저장소에 [FVM](https://fvm.app/) 설정(`.fvm/`, `.fvmrc`)이 있으면 FVM으로 버전 맞추면 됩니다.  
2. Firebase: 앱은 `firebase_options.dart`와(예: Android) `google-services.json` 등이 필요합니다. 저장소 정책에 따라 파일이 포함되지 않을 수 있으므로, [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup)로 `flutterfire configure` 등 **본인 프로젝트에 맞게 생성**합니다.  
3. Firebase Auth 매직 링크 로그인을 쓰려면 Firebase Console에서 Email link(passwordless)를 켜고, Authorized domains에 `mjcinone.web.app`/`mjcinone.firebaseapp.com`을 확인한 뒤 Hosting의 `.well-known/assetlinks.json`에 Android 패키지 `com.myeongji.mio.mioNotice`와 디버그/릴리스 SHA-256을 등록합니다.
4. 터미널에서:

```bash
cd app
flutter pub get
flutter run
```

크롤러·Firestore 동기화는 `test/` 스크립트를 참고해 별도 환경에서 실행합니다.

## 문서 갱신

기능이 바뀌면 **`PROGRESS.md`를 먼저** 완성/보완/예정 섹션에 반영하고, 이 README의 요약 문단만 짧게 맞추면 됩니다.

---

*진행 상세·체크리스트: [PROGRESS.md](./PROGRESS.md)*
