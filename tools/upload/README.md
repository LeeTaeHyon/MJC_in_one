# Firestore 업로드 도구

이 폴더는 로컬의 `assets/data/*` (JSON/CSV) 및 시간표 Excel(XLSX) 등을 읽어 Firestore로 업로드/동기화하기 위한 도구입니다.

## 준비물

- Python 3.11+ 권장
- Firebase Admin SDK용 **Service Account Key(JSON)**
  - 저장소에 커밋하지 마세요. 이 레포는 기본적으로 `serviceAccountKey.json`, `*.env` 를 `.gitignore`로 제외합니다.

## 설치

```bash
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
```

## 환경변수

`.env.example`을 참고해 `.env`를 만들고 값 설정:

- `FIREBASE_PROJECT_ID`: Firebase 프로젝트 id
- `GOOGLE_APPLICATION_CREDENTIALS`: 서비스 계정 키 JSON 경로

## 실행(예시)

각 스크립트는 공통적으로 다음을 목표로 합니다.

- `--dry-run`: 변경점만 출력하고 업로드는 수행하지 않음
- `--validate`: 스키마/필수 키 검증 후 실패 시 중단

예)

```bash
python upload_departments.py --from assets --validate --dry-run
```

## 한 번에 동기화

로컬 파일 수정 후 한 번에 반영하려면:

```powershell
python tools\upload\sync_from_local.py --validate
```

- 특정 데이터만: `--only campus,departments` 등
- 삭제 동기화(컬렉션형만): `--prune-missing`

