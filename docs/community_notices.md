# 학과 공지 (community_notices)

비공식 학과 공지 게시판. 앱 **설정 > 실험실 > 학과 공지 (실험)** ON 시 공지 탭 「학과」에 표시됩니다.

## Firestore

- `community_notices/{deptSlug}/meta/info` — 게시판 메타
- `community_notices/{deptSlug}/posts/{postId}` — 글 (제목, 작성자, 본문, 이미지 URL 등)
- `config/department_slugs` — 표시명 → slug 매핑

## Storage (Blaze)

- 사진: `community_notices/{deptSlug}/{postId}/images/{0..2}.jpg` (최대 3장, JPEG 압축)
- 첨부: `community_notices/{deptSlug}/{postId}/attachments/{파일명}` (PDF·HWP·HWPX·ZIP, 최대 3개, 10MB)
- 구형: `.../image.jpg` (읽기 호환)
- 사진 규칙: 관리자, **512KB**, `image/*`
- 첨부 규칙: 관리자, **10MB**, 확장자·MIME 화이트리스트

## 배포

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

### Storage CORS (웹 관리자·이미지 표시)

웹에서 `statusCode: 0` 이미지 오류가 나면 버킷 CORS를 한 번 설정합니다.

```bash
# Google Cloud SDK (gsutil) 필요
gsutil cors set storage.cors.json gs://mjcinone.firebasestorage.app
```

`storage.cors.json`은 repo 루트에 있습니다. 앱은 웹에서 `WebHtmlElementStrategy.prefer`(HTML img)도 사용합니다.

인덱스 `posts` (`status` + `created_at`)가 **사용 설정됨**인지 콘솔에서 확인한 뒤 앱 테스트하세요.

## 시드 (선택)

```bash
cd tools/upload
python upload_department_slugs.py
python seed_community_boards.py
# dry-run: python seed_community_boards.py --dry-run
```

## 운영

- 카톡 캡처·개인정보 최소화
- 관리자 콘솔 **학과 공지** 탭에서 글·이미지 등록 (웹 `/#/admin`)
- 웹 이미지 업로드는 `putData` 경로 사용

### 저장 시 「권한 거부」가 나올 때

1. **Storage 규칙 배포** (사진 `images/` 경로 포함): `firebase deploy --only storage`
2. Firebase 콘솔 → **Storage** → cross-service rules용 **IAM 역할 허용** (Grant)
3. Firestore `admin/users` 문서 `uids` 배열에 **로그인한 계정 UID** 추가
4. 스낵바에 `firebase_storage/unauthorized` 인지 `cloud_firestore/...` 인지 확인
