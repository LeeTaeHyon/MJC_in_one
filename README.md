# MJC in one

명지전문대학 재학생·통학생을 위한 **캠퍼스 공지·안내를 한곳에서 보는 모바일 앱** 프로젝트입니다. 
<br>메인 홈페이지(mjc.ac.kr), CTL(ctl.mjc.ac.kr), MPU 핵심역량(mpu.mjc.ac.kr) 등 **흩어진 공지·프로그램 정보**를 앱 안에서 모아 보고, **Firebase 푸시**로 새 글 알림을 받을 수 있도록 하는 것을 목표로 합니다.

## 프로젝트 개요

| 항목 | 내용 |
|------|------|
| **소속·맥락** | MJC AI-DEAS 등 교내 프로그램 지원 하에 진행 |
| **클라이언트** | Flutter (`app/`, 패키지명 `mio_notice`) |
| **백엔드·데이터** | Cloud Firestore에 적재된 공지 메타데이터, FCM 토픽(`all_notices` 등) |
| **수집·연동** | 학교 게시판 크롤링·동기화 스크립트 (`test/` 등), Firebase와 별도 파이프라인으로 운영 가능 |

## 저장소 구조

- **`app/`** — Flutter 앱 소스, Android/iOS/Web/Desktop 플랫폼 폴더 포함  
- **`test/`** — 크롤러·FCM 테스트 유틸·샘플 HTML 등 (앱 빌드와 독립)  
- **`PROGRESS.md`** — 구현 상태를 **완성됨 / 보완 필요 / 미완성(예정)** 으로 정리한 진행 노트 (코드 기준, 배포·운영 제외)

## 주요 기능 (현재 구현)

아래는 `PROGRESS.md`의 **완성됨** 범위를 요약한 것입니다.

- **내비게이션**: 하단 탭·FAB 메뉴, 스캐폴드 드로어·홈 슬라이드 메뉴, 시스템 뒤로가기 처리  
- **홈 대시보드**: Firestore 기반 **최근 2주** 통합 피드(공지·학사·장학·역량·CTL 등), 새로고침·웹뷰 상세  
- **메인 / CTL / MPU**: 탭별 목록·웹뷰, 당겨서 새로고침  
- **도서관**: `lib.mjc.ac.kr` 인앱 웹뷰, 공유·외부 브라우저  
- **알림**: FCM 수신, 전체·키워드 필터, 출처(MJC·CTL·MPU) 스위치, 로컬 알림·**알림 내역**(최대 50건)  
- **설정·정보**: 키워드 관리, 개발자 문의, 오픈소스 라이선스 화면  

## 로드맵·한계 (요약)

- **보완 예정**: 웹 빌드 시 Firebase 미구성 처리, iOS 로컬 알림 설정 보강, 미사용 `FirestoreService` 정리, 버전 문자열 단일화, 테스트 보강 등 — 자세한 항목은 `PROGRESS.md` **보완 필요** 참고  
- **미구현·예정**: 통학·교통 정보 연계, 스토어·CI 정비, 알림 탭 딥링크, 전역 검색·계정 등 — `PROGRESS.md` **미완성(예정)** 참고  

## 로컬에서 앱 실행하기

1. [Flutter](https://docs.flutter.dev/get-started/install) 설치 (SDK는 `app/pubspec.yaml`의 `environment.sdk`에 맞출 것). 저장소에 [FVM](https://fvm.app/) 설정(`.fvm/`, `.fvmrc`)이 있으면 FVM으로 버전 맞추면 됩니다.  
2. Firebase: 앱은 `firebase_options.dart`와(예: Android) `google-services.json` 등이 필요합니다. 저장소 정책에 따라 파일이 포함되지 않을 수 있으므로, [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup)로 `flutterfire configure` 등 **본인 프로젝트에 맞게 생성**합니다.  
3. 터미널에서:

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
