"""
Firestore에 저장된 공지에 ai_tags(v1) 백필.

  cd test
  python backfill_ai_tags.py --dry-run --limit 20
  python backfill_ai_tags.py
  python backfill_ai_tags.py --use-lmstudio

환경변수(선택):
  LMSTUDIO_BASE_URL=http://100.103.87.103:1234/
  LMSTUDIO_MODEL=qwen/qwen3.5-9b
  FIREBASE_KEY 또는 test/serviceAccountKey.json
"""

from __future__ import annotations

import argparse
from argparse import ArgumentDefaultsHelpFormatter, RawDescriptionHelpFormatter
import os
import sys
import time

# 같은 디렉터리 모듈
from notice_ai_tags import AI_TAG_VERSION, enrich_post_dict, lmstudio_refine_tags

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
except ImportError:
    print("pip install firebase-admin", file=sys.stderr)
    raise


def init_firebase():
    if firebase_admin._apps:
        return firestore.client()
    key_json = os.environ.get("FIREBASE_KEY")
    if key_json:
        import json

        cred = credentials.Certificate(json.loads(key_json))
    else:
        _here = os.path.dirname(os.path.abspath(__file__))
        cred = credentials.Certificate(
            os.path.join(_here, "serviceAccountKey.json")
        )
    firebase_admin.initialize_app(cred)
    return firestore.client()


def _mjc_boards() -> list[str]:
    return ["main_notice", "main_academic", "main_scholarship", "main_schedule"]


def backfill_mjc(
    db,
    *,
    board_filter: str | None,
    limit: int | None,
    dry_run: bool,
    force: bool,
    use_lmstudio: bool,
    lm_base: str,
    lm_model: str,
    sleep_s: float,
) -> int:
    updated = 0
    boards = _mjc_boards()
    if board_filter:
        boards = [b for b in boards if b == board_filter]
        if not boards:
            print(f"알 수 없는 board: {board_filter}", file=sys.stderr)
            return 0

    for board_id in boards:
        col = db.collection("notices").document(board_id).collection("posts")
        for doc in col.stream():
            if limit is not None and updated >= limit:
                return updated
            data = doc.to_dict() or {}
            if (
                not force
                and data.get("ai_tag_version") == AI_TAG_VERSION
                and data.get("ai_tags")
            ):
                continue
            post = dict(data)
            enrich_post_dict(post, board_id)
            tags = list(post.get("ai_tags") or [])
            ver = str(post.get("ai_tag_version") or AI_TAG_VERSION)
            title = str(data.get("title") or "")
            category = str(data.get("category") or "")
            extra = str(data.get("body") or "")
            if (
                use_lmstudio
                and lm_base
                and (tags == ["기타"] or not tags)
            ):
                refined = lmstudio_refine_tags(
                    base_url=lm_base,
                    model=lm_model,
                    board_id=board_id,
                    category=category,
                    title=title,
                    extra=extra,
                )
                if refined:
                    tags = refined
            print(f"[mjc/{board_id}] {doc.id} -> {tags}")
            if not dry_run:
                doc.reference.set(
                    {"ai_tags": tags, "ai_tag_version": ver}, merge=True
                )
            updated += 1
            if sleep_s > 0:
                time.sleep(sleep_s)
    return updated


def backfill_ctl(
    db,
    *,
    limit: int | None,
    dry_run: bool,
    force: bool,
    use_lmstudio: bool,
    lm_base: str,
    lm_model: str,
    sleep_s: float,
) -> int:
    updated = 0
    pairs = [("notices", "ctl_notice"), ("programs", "ctl_programs")]
    for sub, board_id in pairs:
        col = db.collection("ctl_data").document(sub).collection("items")
        for doc in col.stream():
            if limit is not None and updated >= limit:
                return updated
            data = doc.to_dict() or {}
            if (
                not force
                and data.get("ai_tag_version") == AI_TAG_VERSION
                and data.get("ai_tags")
            ):
                continue
            post = dict(data)
            enrich_post_dict(post, board_id)
            tags = list(post.get("ai_tags") or [])
            ver = str(post.get("ai_tag_version") or AI_TAG_VERSION)
            title = str(data.get("title") or "")
            category = str(data.get("category") or "")
            extra = ""
            if (
                use_lmstudio
                and lm_base
                and (tags == ["기타"] or not tags)
            ):
                refined = lmstudio_refine_tags(
                    base_url=lm_base,
                    model=lm_model,
                    board_id=board_id,
                    category=category,
                    title=title,
                    extra=extra,
                )
                if refined:
                    tags = refined
            print(f"[ctl/{sub}] {doc.id} -> {tags}")
            if not dry_run:
                doc.reference.set(
                    {"ai_tags": tags, "ai_tag_version": ver}, merge=True
                )
            updated += 1
            if sleep_s > 0:
                time.sleep(sleep_s)
    return updated


def backfill_mpu(
    db,
    *,
    limit: int | None,
    dry_run: bool,
    force: bool,
    use_lmstudio: bool,
    lm_base: str,
    lm_model: str,
    sleep_s: float,
) -> int:
    updated = 0
    board_id = "mpu_programs"
    col = db.collection("core_competencies").document("all").collection("programs")
    for doc in col.stream():
        if limit is not None and updated >= limit:
            return updated
        data = doc.to_dict() or {}
        if (
            not force
            and data.get("ai_tag_version") == AI_TAG_VERSION
            and data.get("ai_tags")
        ):
            continue
        post = dict(data)
        enrich_post_dict(post, board_id)
        tags = list(post.get("ai_tags") or [])
        ver = str(post.get("ai_tag_version") or AI_TAG_VERSION)
        title = str(data.get("title") or "")
        category = ""
        extra = ""
        if use_lmstudio and lm_base and (tags == ["기타"] or not tags):
            refined = lmstudio_refine_tags(
                base_url=lm_base,
                model=lm_model,
                board_id=board_id,
                category=category,
                title=title,
                extra=extra,
            )
            if refined:
                tags = refined
        print(f"[mpu] {doc.id} -> {tags}")
        if not dry_run:
            doc.reference.set(
                {"ai_tags": tags, "ai_tag_version": ver}, merge=True
            )
        updated += 1
        if sleep_s > 0:
            time.sleep(sleep_s)
    return updated


class _HelpFormatter(ArgumentDefaultsHelpFormatter, RawDescriptionHelpFormatter):
    """옵션 기본값 표시 + epilog 줄바꿈 유지."""


def main() -> None:
    ap = argparse.ArgumentParser(
        prog="backfill_ai_tags.py",
        description=(
            "Firestore 공지 문서에 ai_tags / ai_tag_version(v1)을 채웁니다. "
            "기본은 룰 기반(notice_ai_tags.py). 이미 v1 태그가 있으면 스킵합니다."
        ),
        formatter_class=_HelpFormatter,
        epilog="""
예시 (test 폴더에서 실행):
  cd test

  도움말 (표준 플래그만 동작: -help 아님):
    python backfill_ai_tags.py -h
    python backfill_ai_tags.py --help

  미리보기만 (Firestore 안 씀):
    python backfill_ai_tags.py --dry-run --limit 30

  전체 백필 (MJC+CTL+MPU):
    python backfill_ai_tags.py

  메인 공지 보드만:
    python backfill_ai_tags.py --source mjc --board main_notice

  룰 바꾼 뒤 전부 다시 쓰기:
    python backfill_ai_tags.py --force

  LM Studio 보정 (룰이 [기타]만 줄 때만 HTTP 호출):
    set LMSTUDIO_BASE_URL=http://127.0.0.1:1234
    python backfill_ai_tags.py --use-lmstudio --lmstudio-model qwen/qwen3.5-9b --limit 50

인증: 환경변수 FIREBASE_KEY(JSON 문자열) 또는 test/serviceAccountKey.json
""",
    )
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--force", action="store_true", help="이미 v1이어도 덮어씀")
    ap.add_argument("--limit", type=int, default=None, help="처리 최대 건수(테스트용)")
    ap.add_argument(
        "--source",
        choices=["all", "mjc", "ctl", "mpu"],
        default="all",
    )
    ap.add_argument(
        "--board",
        default=None,
        help="MJC만: main_notice, main_academic, main_scholarship, main_schedule",
    )
    ap.add_argument("--sleep", type=float, default=0.0, help="문서당 대기(초)")
    ap.add_argument(
        "--use-lmstudio",
        action="store_true",
        help="룰이 기타만 줄 때 LM Studio로 보정",
    )
    ap.add_argument(
        "--lmstudio-url",
        default=os.environ.get("LMSTUDIO_BASE_URL", ""),
    )
    ap.add_argument(
        "--lmstudio-model",
        default=os.environ.get("LMSTUDIO_MODEL", "qwen/qwen3.5-9b"),
    )
    args = ap.parse_args()

    db = init_firebase()
    total = 0
    lm_base = (args.lmstudio_url or "").strip().rstrip("/")

    if args.source in ("all", "mjc"):
        total += backfill_mjc(
            db,
            board_filter=args.board,
            limit=args.limit,
            dry_run=args.dry_run,
            force=args.force,
            use_lmstudio=args.use_lmstudio,
            lm_base=lm_base,
            lm_model=args.lmstudio_model,
            sleep_s=args.sleep,
        )
    if args.source in ("all", "ctl") and (args.limit is None or total < args.limit):
        rem = None if args.limit is None else max(0, args.limit - total)
        total += backfill_ctl(
            db,
            limit=rem,
            dry_run=args.dry_run,
            force=args.force,
            use_lmstudio=args.use_lmstudio,
            lm_base=lm_base,
            lm_model=args.lmstudio_model,
            sleep_s=args.sleep,
        )
    if args.source in ("all", "mpu") and (args.limit is None or total < args.limit):
        rem = None if args.limit is None else max(0, args.limit - total)
        total += backfill_mpu(
            db,
            limit=rem,
            dry_run=args.dry_run,
            force=args.force,
            use_lmstudio=args.use_lmstudio,
            lm_base=lm_base,
            lm_model=args.lmstudio_model,
            sleep_s=args.sleep,
        )

    print(f"완료: 처리 {total}건 (dry_run={args.dry_run})")


if __name__ == "__main__":
    main()
