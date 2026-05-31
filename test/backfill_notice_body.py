"""
Firestore 의 MJC 공지에 본문(body) + 요약(summary) 백필.

기본 동작:
  - 본문이 없는 (`body` 미존재 또는 빈 문자열) 문서만 처리.
  - 휴리스틱 요약을 함께 저장.

옵션:
  --resummary-flagged   관리자 페이지에서 needs_resummary=true 로 마킹한 문서 재처리
  --reported-only       reports_count > 0 이고 status != resolved 인 문서만
  --use-gemini          Gemini Flash 로 요약 생성 (GEMINI_API_KEY 필요)
  --failure-log PATH    Gemini 요약 실패 문서만 JSON 한 줄씩 append (재시도 목록)
  --retry-failure-log PATH  위 로그를 읽어 해당 글만 다시 fetch+요약 (--board 로 필터 가능)
  --gemini-timeout-sec  Gemini HTTP read timeout (기본 120)
  --gemini-debug        Gemini 요약 호출 상세 로그 stderr 출력
  --force               이미 body 가 있어도 재 fetch + 요약
  --body-only           본문(body/body_html)만 fetch, summary 필드는 Firestore 에 그대로 둠
  --summary-only        HTTP fetch 없이 summary/summary_version 만 재생성 (--use-gemini 권장)
  --board               특정 보드만 처리
  --limit               처리 최대 건수 (테스트용)
  --start-after         ( --board 와 함께) Firestore 문서 ID 기준 이 ID 다음부터 처리
  --firestore-page-size Firestore 목록을 이만큼씩만 읽은 뒤 끊음 (기본 100).
                         AI 요약 등으로 문서 처리가 길면 stream() 대신 이 방식이 필요함 — 안 쓰면 504 DeadlineExceeded 가 날 수 있음.
  --throttle-ms         문서당 대기 ms (Gemini 429 시 8000~15000 권장, 기본 6000)

사용 예 (test 폴더에서):
  cd test
  python backfill_notice_body.py --dry-run --limit 5
  python backfill_notice_body.py
  set GEMINI_API_KEY=your_key_here
  python backfill_notice_body.py --use-gemini --resummary-flagged

  Gemini 요약 실패 원인 로그 (stderr):
    플래그: --gemini-debug
    또는 PowerShell: $env:GEMINI_DEBUG = "1"

  한 번에: Gemini + 실패 수집 + 504 방지(페이지 읽기) + 중단 시 이어하기 (PowerShell, test 폴더):
    python backfill_notice_body.py `
      --board main_notice --force --use-gemini `
      --failure-log gemini_failures.jsonl --firestore-page-size 100
    # limit 으로 끊었거나 중간에 끊기면 stderr 의 [이어하기] 가 알려주는 DOC_ID 로:
    python backfill_notice_body.py `
      --board main_notice --force --use-gemini `
      --failure-log gemini_failures.jsonl --firestore-page-size 100 `
      --start-after BD00xxxxxxxx

인증: 환경변수 FIREBASE_KEY (JSON 문자열) 또는 test/serviceAccountKey.json
"""

from __future__ import annotations

import argparse
from argparse import ArgumentDefaultsHelpFormatter, RawDescriptionHelpFormatter
import json
import os
import sys
import time
from datetime import datetime

import requests

from notice_body import (
    _BODY_IMAGE_ONLY_PLACEHOLDER,
    enrich_body_only,
    enrich_summary_only,
    enrich_with_body_and_summary,
)

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
    from google.cloud.firestore_v1 import FieldFilter
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
        cred = credentials.Certificate(
            os.path.join(_here, "serviceAccountKey.json")
        )
    firebase_admin.initialize_app(cred)
    return firestore.client()


class _HelpFormatter(ArgumentDefaultsHelpFormatter, RawDescriptionHelpFormatter):
    """기본값 표시 + epilog 줄바꿈 유지."""


def _should_process(
    data: dict,
    *,
    force: bool,
    resummary_flagged: bool,
    reported_only: bool,
    summary_only: bool = False,
    missing_ai_only: bool = False,
) -> bool:
    if reported_only:
        rc = int(data.get("reports_count") or 0)
        if rc <= 0:
            return False
    elif resummary_flagged:
        if not data.get("needs_resummary"):
            return False

    # AI 요약이 이미 되어 있으면 스킵
    if missing_ai_only:
        sv = str(data.get("summary_version") or "").strip()
        if sv.startswith("gemini"):
            return False
        
        # AI 요약이 없는데 summary_only 라면 기존 본문이 있어야 함
        if summary_only:
            body = data.get("body")
            body_html = data.get("body_html")
            return bool(str(body or "").strip() or str(body_html or "").strip())
        return True

    if reported_only or resummary_flagged:
        return True

    if summary_only:
        if force:
            return True
        summary = data.get("summary")
        if not isinstance(summary, str) or not summary.strip():
            return True
        return bool(data.get("needs_resummary"))
    if force:
        return True
    body = data.get("body")
    body_html = data.get("body_html")
    if isinstance(body, str) and body.strip() == _BODY_IMAGE_ONLY_PLACEHOLDER:
        return True
    if not isinstance(body_html, str) or not body_html.strip():
        return True
    return not isinstance(body, str) or not body.strip()


def _append_failure_jsonl(path: str, record: dict) -> None:
    """Gemini 요약 실패 건만 한 줄 JSON 으로 append (중단돼도 지금까지 기록 유지)."""
    abs_path = os.path.abspath(path)
    parent = os.path.dirname(abs_path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    line = json.dumps(record, ensure_ascii=False) + "\n"
    with open(abs_path, "a", encoding="utf-8") as f:
        f.write(line)
        f.flush()


def _persist_notice_body_update(
    *,
    board_id: str,
    doc_id: str,
    doc_ref,
    post: dict,
    original: dict,
    resummary_flagged: bool,
    dry_run: bool,
    failure_log_path: str | None,
    use_gemini: bool,
    body_only: bool = False,
    summary_only: bool = False,
) -> None:
    fail_reason = post.pop("_summarize_fail_reason", None)
    if failure_log_path and use_gemini and fail_reason:
        _append_failure_jsonl(
            failure_log_path,
            {
                "board_id": board_id,
                "post_id": doc_id,
                "reason": fail_reason,
                "title": (post.get("title") or "")[:200],
                "url": post.get("url") or "",
                "ts": datetime.now().isoformat(),
            },
        )

    mode = "summary-only" if summary_only else ("body-only" if body_only else "full")
    update: dict = {}

    if summary_only:
        update = {
            "summary": post.get("summary", ""),
            "summary_version": post.get("summary_version"),
            "summary_generated_at": post.get("summary_generated_at"),
        }
    elif body_only:
        update = {
            "body": post.get("body", ""),
            "body_html": post.get("body_html", ""),
            "body_fetched_at": post.get("body_fetched_at"),
        }
        if post.get("body_fetch_error") is not None:
            update["body_fetch_error"] = post["body_fetch_error"]
        new_title = post.get("title")
        if isinstance(new_title, str) and new_title != original.get("title"):
            update["title"] = new_title
    else:
        update = {
            "body": post.get("body", ""),
            "body_html": post.get("body_html", ""),
            "body_fetched_at": post.get("body_fetched_at"),
            "summary": post.get("summary", ""),
            "summary_version": post.get("summary_version"),
            "summary_generated_at": post.get("summary_generated_at"),
        }
        if post.get("body_fetch_error") is not None:
            update["body_fetch_error"] = post["body_fetch_error"]

    if resummary_flagged:
        update["needs_resummary"] = False

    body_len = len(post.get("body") or "")
    html_len = len(post.get("body_html") or "")
    summary_len = len(post.get("summary") or "")
    summary_version = update.get("summary_version", original.get("summary_version"))
    base_line = (
        f"[{board_id}] {doc_id} mode={mode} body={body_len}b html={html_len}b "
        f"summary={summary_len}b version={summary_version} "
        f"err={post.get('body_fetch_error')}"
    )
    if use_gemini and not body_only:
        base_line += f" gemini_fail={fail_reason!r}"
    print(base_line)
    if not dry_run:
        doc_ref.set(update, merge=True)


def _enrich_post(
    post: dict,
    *,
    session: requests.Session,
    body_only: bool,
    summary_only: bool,
    use_gemini: bool,
    gemini_api_key: str,
    gemini_model: str,
    gemini_timeout: float,
) -> None:
    if body_only:
        enrich_body_only(post, session=session)
    elif summary_only:
        enrich_summary_only(
            post,
            use_gemini=use_gemini,
            gemini_api_key=gemini_api_key,
            gemini_model=gemini_model,
            gemini_timeout=gemini_timeout,
        )
    else:
        enrich_with_body_and_summary(
            post,
            session=session,
            use_gemini=use_gemini,
            gemini_api_key=gemini_api_key,
            gemini_model=gemini_model,
            gemini_timeout=gemini_timeout,
        )


def _has_open_report_for(db, board_id: str, post_id: str) -> bool:
    """reported-only 모드에서, 같은 글에 open 신고가 실제로 있는지 빠른 체크."""
    snap = (
        db.collection("notice_reports")
        .where(filter=FieldFilter("board_id", "==", board_id))
        .where(filter=FieldFilter("post_id", "==", post_id))
        .where(filter=FieldFilter("status", "==", "open"))
        .limit(1)
        .get()
    )
    return bool(snap)


def backfill_one_board(
    db,
    board_id: str,
    *,
    force: bool,
    resummary_flagged: bool,
    reported_only: bool,
    use_gemini: bool,
    gemini_api_key: str,
    gemini_model: str,
    limit: int | None,
    throttle_s: float,
    dry_run: bool,
    session: requests.Session,
    start_after: str | None = None,
    failure_log_path: str | None = None,
    gemini_timeout: float = 120.0,
    firestore_page_size: int = 100,
    body_only: bool = False,
    summary_only: bool = False,
    missing_ai_only: bool = False,
) -> tuple[int, str | None]:
    """Returns (processed_count, last_processed_doc_id_if_any).

    Firestore ``stream()`` 은 한 번 연 연결을 유지하는데, 문서마다 Gemini/본문 fetch 가
    길어지면 gRPC 가 유휴 상태로 ``Deadline Exceeded`` 가 난다. 그래서 페이지 단위
    ``get()`` 으로만 읽는다.
    """
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
                return processed, last_id
            data = doc.to_dict() or {}
            if not _should_process(
                data,
                force=force,
                resummary_flagged=resummary_flagged,
                reported_only=reported_only,
                summary_only=summary_only,
                missing_ai_only=missing_ai_only,
            ):
                continue
            if reported_only and not _has_open_report_for(db, board_id, doc.id):
                continue

            original = dict(data)
            post = dict(data)
            if not post.get("url"):
                continue
            if summary_only and not (
                str(post.get("body") or "").strip()
                or str(post.get("body_html") or "").strip()
            ):
                print(
                    f"[스킵] {board_id}/{doc.id} 본문·body_html 없음 "
                    f"(--body-only 로 먼저 채우거나 --force 전체 모드 사용)",
                    file=sys.stderr,
                )
                continue
            _enrich_post(
                post,
                session=session,
                body_only=body_only,
                summary_only=summary_only,
                use_gemini=use_gemini,
                gemini_api_key=gemini_api_key,
                gemini_model=gemini_model,
                gemini_timeout=gemini_timeout,
            )

            _persist_notice_body_update(
                board_id=board_id,
                doc_id=doc.id,
                doc_ref=doc.reference,
                post=post,
                original=original,
                resummary_flagged=resummary_flagged,
                dry_run=dry_run,
                failure_log_path=failure_log_path,
                use_gemini=use_gemini,
                body_only=body_only,
                summary_only=summary_only,
            )

            processed += 1
            last_id = doc.id
            if throttle_s > 0:
                time.sleep(throttle_s)

        cursor_snap = batch[-1]

    return processed, last_id


def retry_from_failure_log(
    db,
    log_path: str,
    *,
    board_filter: str | None,
    use_gemini: bool,
    gemini_api_key: str,
    gemini_model: str,
    gemini_timeout: float,
    limit: int | None,
    throttle_s: float,
    dry_run: bool,
    session: requests.Session,
    failure_log_path: str | None,
    resummary_flagged: bool,
    body_only: bool = False,
    summary_only: bool = False,
) -> int:
    """--failure-log 로 쌓인 JSONL 만 순서대로 다시 처리."""
    abs_path = os.path.abspath(log_path)
    if not os.path.isfile(abs_path):
        print(f"[오류] 재시도 로그 파일이 없습니다: {abs_path}", file=sys.stderr)
        return 0

    processed = 0
    with open(abs_path, encoding="utf-8") as f:
        for line in f:
            if limit is not None and processed >= limit:
                break
            raw = line.strip()
            if not raw or raw.startswith("#"):
                continue
            try:
                entry = json.loads(raw)
            except json.JSONDecodeError as e:
                print(f"[경고] JSONL 파싱 실패, 건너뜀: {e}", file=sys.stderr)
                continue
            bid = (entry.get("board_id") or "").strip()
            pid = (entry.get("post_id") or "").strip()
            if not bid or not pid:
                continue
            if board_filter and bid != board_filter:
                continue

            doc_ref = (
                db.collection("notices").document(bid).collection("posts").document(pid)
            )
            snap = doc_ref.get()
            if not snap.exists:
                print(f"[경고] 문서 없음 스킵: {bid}/{pid}", file=sys.stderr)
                continue
            original = dict(snap.to_dict() or {})
            post = dict(original)
            if not post.get("url"):
                print(f"[경고] url 없음 스킵: {bid}/{pid}", file=sys.stderr)
                continue

            _enrich_post(
                post,
                session=session,
                body_only=body_only,
                summary_only=summary_only,
                use_gemini=use_gemini,
                gemini_api_key=gemini_api_key,
                gemini_model=gemini_model,
                gemini_timeout=gemini_timeout,
            )
            _persist_notice_body_update(
                board_id=bid,
                doc_id=pid,
                doc_ref=doc_ref,
                post=post,
                original=original,
                resummary_flagged=resummary_flagged,
                dry_run=dry_run,
                failure_log_path=failure_log_path,
                use_gemini=use_gemini,
                body_only=body_only,
                summary_only=summary_only,
            )
            processed += 1
            if throttle_s > 0:
                time.sleep(throttle_s)
    return processed


def main() -> None:
    ap = argparse.ArgumentParser(
        prog="backfill_notice_body.py",
        description=(
            "MJC 공지의 본문/요약 누락 문서를 채우거나, 신고/플래그된 문서를 재요약합니다."
        ),
        formatter_class=_HelpFormatter,
        epilog="""
예시 (test 폴더에서 실행):
  cd test

  미리보기:
    python backfill_notice_body.py --dry-run --limit 5

  본문 누락 문서 전체 채우기:
    python backfill_notice_body.py

  관리자 페이지에서 플래그한 글만 재요약:
    set GEMINI_API_KEY=your_key_here
    python backfill_notice_body.py --resummary-flagged --use-gemini

  열린 신고가 있는 글만 재요약:
    python backfill_notice_body.py --reported-only --use-gemini

  보드별로 20건씩 끊어서 Gemini 재생성 (이어하기):
    python backfill_notice_body.py --board main_notice --force --use-gemini --limit 20
    # stderr 에 나온 [이어하기] 줄 그대로 다음에 붙여 실행
    python backfill_notice_body.py --board main_notice --force --use-gemini --limit 20 --start-after BD00...

  Gemini 타임아웃 등 실패만 파일에 모았다가 나중에 재시도:
    python backfill_notice_body.py --board main_notice --force --use-gemini \\
      --failure-log gemini_failures.jsonl --firestore-page-size 100
    python backfill_notice_body.py --retry-failure-log gemini_failures.jsonl --use-gemini \\
      --failure-log gemini_failures_round2.jsonl

  body_html 만 채우고 기존 AI 요약 유지:
    python backfill_notice_body.py --body-only --board main_notice

  휴리스틱으로 덮인 요약만 Gemini 로 복구 (본문 fetch 없음):
    python backfill_notice_body.py --summary-only --force --use-gemini --board main_notice

  실패 로그 + 이어하기 한 세트 (PowerShell):
    python backfill_notice_body.py `
      --board main_notice --force --use-gemini `
      --failure-log gemini_failures.jsonl --firestore-page-size 100
    python backfill_notice_body.py `
      --board main_notice --force --use-gemini `
      --failure-log gemini_failures.jsonl --firestore-page-size 100 `
      --start-after BD00xxxxxxxx
    # --start-after 값은 직전 실행이 stderr 에 출력한 [이어하기] 줄의 DOC_ID 와 동일하게 넣으면 됨.
""",
    )
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--force", action="store_true", help="이미 body 있어도 재 fetch")
    ap.add_argument(
        "--body-only",
        action="store_true",
        help="view.do 본문(body/body_html)만 갱신. summary 필드는 Firestore 에 그대로 둠",
    )
    ap.add_argument(
        "--summary-only",
        action="store_true",
        help="HTTP fetch 없이 summary/summary_version 만 재생성 (기존 body 사용)",
    )
    ap.add_argument("--resummary-flagged", action="store_true")
    ap.add_argument("--reported-only", action="store_true")
    ap.add_argument(
        "--board",
        default=None,
        choices=list(_DEFAULT_BOARDS),
        help="특정 보드만 처리. 미지정 시 모든 본교 공지 보드.",
    )
    ap.add_argument("--limit", type=int, default=None)
    ap.add_argument(
        "--start-after",
        default=None,
        metavar="DOC_ID",
        help="문서 ID 순 이어하기: 이 ID 다음 문서부터 처리 (--board 필수)",
    )
    ap.add_argument(
        "--throttle-ms",
        type=int,
        default=int(
            os.environ.get(
                "GEMINI_THROTTLE_MS",
                os.environ.get("BODY_FETCH_THROTTLE_MS", "6000"),
            )
        ),
        help="문서 처리 후 대기(ms). Gemini 429 나오면 10000~15000 으로 올리세요.",
    )
    ap.add_argument(
        "--use-gemini",
        action="store_true",
        help="Gemini Flash 로 요약 생성 (GEMINI_API_KEY 필요)",
    )
    ap.add_argument(
        "--missing-ai-only",
        action="store_true",
        help="AI 요약이 생성되지 않았거나 Heuristic 요약만 있는 문서만 처리",
    )
    ap.add_argument(
        "--gemini-api-key",
        default=os.environ.get("GEMINI_API_KEY", ""),
        help="Gemini API 키 (미지정 시 GEMINI_API_KEY 환경변수)",
    )
    ap.add_argument(
        "--gemini-model",
        default=os.environ.get("GEMINI_MODEL", "gemini-2.0-flash"),
    )
    ap.add_argument(
        "--gemini-debug",
        action="store_true",
        help="GEMINI_DEBUG=1 과 동일: stderr 에 요약 API 디버그 로그 출력",
    )
    ap.add_argument(
        "--failure-log",
        default=None,
        metavar="PATH",
        help=(
            "Gemini 요약 실패 시 board_id/post_id/reason 등을 JSON 한 줄로 append "
            "(--use-gemini 일 때만 기록)"
        ),
    )
    ap.add_argument(
        "--retry-failure-log",
        default=None,
        metavar="PATH",
        help="이전에 --failure-log 로 저장한 JSONL 만 다시 처리 (--board 로 해당 보드만 필터)",
    )
    ap.add_argument(
        "--gemini-timeout-sec",
        type=float,
        default=float(os.environ.get("GEMINI_TIMEOUT_SEC", "120")),
        help="Gemini generateContent HTTP timeout 초",
    )
    ap.add_argument(
        "--firestore-page-size",
        type=int,
        default=int(os.environ.get("BACKFILL_FIRESTORE_PAGE_SIZE", "100")),
        metavar="N",
        help=(
            "Firestore 는 페이지당 N개 문서만 조회 후 연결을 닫음 "
            "(스트림 유지 시 장시간 AI 요약 처리 중 504 DeadlineExceeded 방지)"
        ),
    )
    args = ap.parse_args()

    if args.body_only and args.summary_only:
        print("--body-only 와 --summary-only 는 동시에 쓸 수 없습니다.", file=sys.stderr)
        sys.exit(1)
    if args.body_only and args.use_gemini:
        print(
            "[안내] --body-only 모드에서는 --use-gemini 가 무시됩니다 (요약 미갱신).",
            file=sys.stderr,
        )
    if args.summary_only and not args.use_gemini:
        print(
            "[안내] --summary-only 는 휴리스틱 요약만 생성합니다. "
            "Gemini 복구 시 --use-gemini 를 함께 지정하세요.",
            file=sys.stderr,
        )

    if args.gemini_debug:
        os.environ["GEMINI_DEBUG"] = "1"

    if args.retry_failure_log:
        if args.start_after:
            print(
                "[안내] --retry-failure-log 모드에서는 --start-after 가 적용되지 않습니다.",
                file=sys.stderr,
            )
    elif args.start_after and not args.board:
        print("--start-after 는 --board 와 함께 지정해야 합니다.", file=sys.stderr)
        sys.exit(1)

    boards = [args.board] if args.board else list(_DEFAULT_BOARDS)
    db = init_firebase()
    sess = requests.Session()
    gemini_api_key = (args.gemini_api_key or "").strip()
    if args.use_gemini:
        print(
            f"[안내] Gemini 백필: 문서당 {args.throttle_ms}ms 대기, "
            f"429 시 API 자동 재시도(GEMINI_MAX_RETRIES). "
            f"계속 429면 --throttle-ms 12000 --limit 10 으로 나눠 실행.",
            file=sys.stderr,
        )
    if args.use_gemini and not gemini_api_key:
        print(
            "--use-gemini 지정했지만 GEMINI_API_KEY 가 비어 있습니다.",
            file=sys.stderr,
        )
        sys.exit(1)

    throttle_s = max(0.0, args.throttle_ms / 1000.0)
    gemini_timeout = max(1.0, float(args.gemini_timeout_sec))
    failure_log = (args.failure_log or "").strip() or None
    fs_page = max(1, int(args.firestore_page_size))

    if args.retry_failure_log:
        bf = args.board if args.board else None
        total = retry_from_failure_log(
            db,
            args.retry_failure_log,
            board_filter=bf,
            use_gemini=args.use_gemini,
            gemini_api_key=gemini_api_key,
            gemini_model=args.gemini_model,
            gemini_timeout=gemini_timeout,
            limit=args.limit,
            throttle_s=throttle_s,
            dry_run=args.dry_run,
            session=sess,
            failure_log_path=failure_log,
            resummary_flagged=args.resummary_flagged,
            body_only=args.body_only,
            summary_only=args.summary_only,
        )
        print(f"완료: 재시도 로그에서 처리 {total}건 (dry_run={args.dry_run})")
        return

    total = 0
    remain = args.limit
    start_after = (args.start_after or "").strip() or None
    for b in boards:
        n, _last = backfill_one_board(
            db,
            b,
            force=args.force,
            resummary_flagged=args.resummary_flagged,
            reported_only=args.reported_only,
            use_gemini=args.use_gemini,
            gemini_api_key=gemini_api_key,
            gemini_model=args.gemini_model,
            limit=remain,
            throttle_s=throttle_s,
            dry_run=args.dry_run,
            session=sess,
            start_after=start_after if b == boards[0] else None,
            failure_log_path=failure_log,
            gemini_timeout=gemini_timeout,
            firestore_page_size=fs_page,
            body_only=args.body_only,
            summary_only=args.summary_only,
            missing_ai_only=args.missing_ai_only,
        )
        total += n
        # 여러 보드 순회 시 start-after 는 첫 보드에만 적용 (의도적)
        start_after = None
        if remain is not None:
            remain = max(0, remain - n)
            if remain == 0:
                break

    print(f"완료: 처리 {total}건 (dry_run={args.dry_run})")


if __name__ == "__main__":
    main()
