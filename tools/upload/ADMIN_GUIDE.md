# 데이터 유지보수 가이드 (로컬 파일 → Firestore)

이 문서는 앱 업데이트 없이 데이터를 갱신하기 위해, **로컬 파일을 수정한 뒤 Firestore에 업로드**하는 절차를 정리합니다.

## 0) 사전 준비

- Firebase 프로젝트 id: `mjcinone`
- Service Account Key(JSON) 파일 준비 (절대 커밋 금지)

PowerShell 예시(1회성 세션 환경변수):

```powershell
$env:FIREBASE_PROJECT_ID='mjcinone'
$env:GOOGLE_APPLICATION_CREDENTIALS='C:\path\to\serviceAccountKey.json'
```

## 1) 캠퍼스맵 (건물/시설)

- **로컬 파일**: `app/assets/data/campus_buildings.json`
- **업로드 위치**: `config/campus_map` (단일 문서)

실행:

```powershell
python tools\upload\upload_campus.py --validate
```

## 2) 학과 목록

- **로컬 파일**: `app/assets/data/mjc_departments.json`
- **업로드 위치**: `config/departments` (단일 문서)

실행:

```powershell
python tools\upload\upload_departments.py --validate
```

## 3) 셔틀 시간표

- **로컬 파일**: `app/assets/data/shuttle.csv`
- **컬럼**: `stop_name,depart_time,weekday,arrive_stop,travel_min`
  - `depart_time`: `H:MM` 또는 `HH:MM` (예: `8:00`, `17:55`)
  - `weekday`: `월화수목금` 같은 한글 요일 문자열 또는 `*` / `all`
- **업로드 위치**: `shuttle_schedule/*` (문서 여러 개)

실행:

```powershell
python tools\upload\upload_shuttle.py --validate
```

## 4) 학식 메뉴

- **로컬 파일**: `app/assets/data/foodcourt.csv`
- **컬럼**: `shop,menu,price`
  - `price`: 숫자(원) (예: `4900`)
- **업로드 위치**: `foodcourt_menu/*` (문서 여러 개)

실행:

```powershell
python tools\upload\upload_foodcourt.py --validate
```

## 5) 반영 확인(앱)

앱은 다음 순서로 데이터를 읽습니다.

1. SharedPreferences TTL 캐시
2. Firestore
3. 실패 시 앱 번들(`assets/data/*`) fallback

즉, 업로드 직후에도 캐시가 남아있으면 화면 반영이 늦을 수 있습니다. (TTL: 캠퍼스맵/학과 7일, 셔틀/학식 1일)

즉시 확인이 필요하면:
- 앱 재시작
- (또는) 캐시 키 삭제(개발용) 기능을 추후 추가

