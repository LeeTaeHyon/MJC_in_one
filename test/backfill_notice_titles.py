"""
Firestore 의 MJC 공지 제목(title) 백필.

문제:
  - MJC 공지 리스트 페이지에서는 긴 제목이 "..." 또는 "…" 로 잘려서 노출됨.
  - 기존 크롤러가 리스트 텍스트를 그대로 저장해, Firestore 에도 잘린 제목이 남아있음.

해결:
  - title 이 "..." 또는 "…" 로 끝나는 문서만 대상으로,
    url(view.do) 상세 페이지에서 og:title / <title> / 화면 헤더 등을 통해
    원본 제목을 다시 파싱하여 title 필드를 업데이트한다.

사용 (test 폴더에서):
  cd test
  python backfill_notice_titles.py --dry-run --limit 10
  python backfill_notice_titles.py --board main_notice --limit 200 --throttle-ms 600
  python backfill_notice_titles.py

인증:
  - 환경변수 FIREBASE_KEY (JSON 문자열) 또는 test/serviceAccountKey.json
"""

from __future__ import annotations

import argparse
from argparse import ArgumentDefaultsHelpFormatter, RawDescriptionHelpFormatter
import os
import sys
import time
from datetime import datetime

import requests

from notice_body import fetch_mjc_view_body

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
except ImportError:  # pragma: no cover
    print("pip install firebase-admin google-cloud-firestore", file=sys.stderr)
    raise


_DEFAULT_BOARDS: tuple[str, ...] = (
    "main_notice",
    "main_academic",
    "main_scholarship",
)


def init_firebase():
    if firebase_admin._apps:
        return firestore.client()
    key_json = os.environ.get("FIREBASE_KEY")
    if key_json:
        import json

        cred = credentials.Certificate(json.loads(key_json))
    else:
        _here = os.path.dirname(os.path.abspath(__file__))
        cred = credentials.Certificate(os.path.join(_here, "serviceAccountKey.json"))
    firebase_admin.initialize_app(cred)
    return firestore.client()


class _HelpFormatter(ArgumentDefaultsHelpFormatter, RawDescriptionHelpFormatter):
    """기본값 표시 + epilog 줄바꿈 유지."""


def _is_truncated_title(title: str) -> bool:
    s = (title or "").strip()
    return s.endswith("...") or s.endswith("…")


def _backfill_one_board(
    db,
    board_id: str,
    *,
    limit: int | None,
    throttle_s: float,
    dry_run: bool,
    timeout: float,
    session: requests.Session,
    firestore_page_size: int,
    start_after: str | None,
) -> tuple[int, str | None]:
    col = db.collection("notices").document(board_id).collection("posts")
    cursor_snap = None
    if start_after:
        cursor = col.document(start_after).get()
        if cursor.exists:
            cursor_snap = cursor
        else:
            print(
                f"[경고] --start-after={start_after!r} 문서가 없습니다. "
                f"보드 {board_id} 처음부터 진행합니다.",
                file=sys.stderr,
            )

    processed = 0
    updated = 0
    last_id: str | None = None
    page_sz = max(1, int(firestore_page_size))

    while True:
        q = col.order_by("__name__")
        if cursor_snap is not None:
            q = q.start_after(cursor_snap)
        batch = q.limit(page_sz).get()
        if not batch:
            break

        for doc in batch:
            if limit is not None and processed >= limit:
                if last_id:
                    print(
                        f"[이어하기] --board {board_id} --start-after {last_id}",
                        file=sys.stderr,
                    )
                print(f"[{board_id}] processed={processed} updated={updated}")
                return processed, last_id

            data = doc.to_dict() or {}
            last_id = doc.id
            cursor_snap = doc

            title = str(data.get("title") or "").strip()
            if not _is_truncated_title(title):
                continue

            url = str(data.get("url") or "").strip()
            if not url:
                continue

            body, view_title, err = fetch_mjc_view_body(
                url,
                timeout=timeout,
                session=session,
            )
            _ = body  # unused (title만 필요)
            if err:
                print(f"[{board_id}] {doc.id} title_backfill_skip err={err} url={url}")
                processed += 1
                if throttle_s > 0:
                    time.sleep(throttle_s)
                continue

            vt = (view_title or "").strip()
            if not vt:
                print(f"[{board_id}] {doc.id} title_backfill_skip no_view_title url={url}")
                processed += 1
                if throttle_s > 0:
                    time.sleep(throttle_s)
                continue

            # 상세 제목도 ... 로 끝나면 의미 없음
            if _is_truncated_title(vt):
                print(f"[{board_id}] {doc.id} title_backfill_skip still_truncated vt={vt[:80]!r}")
                processed += 1
                if throttle_s > 0:
                    time.sleep(throttle_s)
                continue

            # 짧아지는 업데이트는 보통 suffix 제거/파싱 실패일 수 있어 방지
            if len(vt) <= len(title):
                print(
                    f"[{board_id}] {doc.id} title_backfill_skip not_longer "
                    f"old={title[:80]!r} new={vt[:80]!r}"
                )
                processed += 1
                if throttle_s > 0:
                    time.sleep(throttle_s)
                continue

            print(f"[{board_id}] {doc.id} title_update: {title[:60]!r} -> {vt[:60]!r}")
            if not dry_run:
                doc.reference.set(
                    {
                        "title": vt,
                        "title_backfilled_at": datetime.now().isoformat(),
                    },
                    merge=True,
                )
            updated += 1
            processed += 1
            if throttle_s > 0:
                time.sleep(throttle_s)

    print(f"[{board_id}] processed={processed} updated={updated}")
    return processed, last_id


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Firestore MJC 공지 제목(title) 백필",
        formatter_class=_HelpFormatter,
    )
    parser.add_argument(
        "--board",
        default="",
        help="특정 보드만 처리 (기본: main_notice/main_academic/main_scholarship 전체)",
    )
    parser.add_argument("--dry-run", action="store_true", help="실제 업데이트 없이 로그만 출력")
    parser.add_argument("--limit", type=int, default=0, help="처리 최대 건수 (0이면 무제한)")
    parser.add_argument(
        "--throttle-ms",
        type=int,
        default=600,
        help="문서당 대기(ms) (서버 부하 방지)",
    )
    parser.add_argument(
        "--fetch-timeout-sec",
        type=float,
        default=15.0,
        help="상세 페이지 fetch timeout",
    )
    parser.add_argument(
        "--firestore-page-size",
        type=int,
        default=100,
        help="Firestore 목록을 이만큼씩만 읽음 (DeadlineExceeded 방지)",
    )
    parser.add_argument(
        "--start-after",
        default="",
        help="(--board와 함께) Firestore 문서 ID 기준 이 ID 다음부터 처리",
    )
    args = parser.parse_args()

    board = (args.board or "").strip()
    boards = (board,) if board else _DEFAULT_BOARDS

    limit = int(args.limit) if int(args.limit) > 0 else None
    throttle_s = max(0.0, float(args.throttle_ms) / 1000.0)
    start_after = (args.start_after or "").strip() or None

    session = requests.Session()
    db = init_firebase()

    for b in boards:
        if start_after and board and b == board:
            sa = start_after
        else:
            sa = None
        _backfill_one_board(
            db,
            b,
            limit=limit,
            throttle_s=throttle_s,
            dry_run=bool(args.dry_run),
            timeout=float(args.fetch_timeout_sec),
            session=session,
            firestore_page_size=int(args.firestore_page_size),
            start_after=sa,
        )


if __name__ == "__main__":
    main()

