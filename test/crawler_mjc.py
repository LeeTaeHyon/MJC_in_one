import requests
import re
from bs4 import BeautifulSoup
from datetime import datetime
import firebase_admin
from firebase_admin import credentials, firestore, messaging
import os
import json

# ── Firebase 초기화 ──────────────────────────────────────────
# GitHub Actions에서는 환경변수로 주입
# 로컬에서는 serviceAccountKey.json 파일 사용
def init_firebase():
    if firebase_admin._apps:
        return firestore.client()

    key_json = os.environ.get("FIREBASE_KEY")
    if key_json:
        cred = credentials.Certificate(json.loads(key_json))
    else:
        _here = os.path.dirname(os.path.abspath(__file__))
        cred = credentials.Certificate(os.path.join(_here, "serviceAccountKey.json"))

    firebase_admin.initialize_app(cred)
    return firestore.client()

# ── FCM 메시지 발송 (Data Payload) ──────────────────────────
def send_fcm_notice(post: dict):
    message = messaging.Message(
        data={
            "title": f"[{post.get('category', '공지')}] 새 글 등록",
            "body": post.get("title", ""),
            "url": post.get("url", ""),
            "board": post.get("category", "")
        },
        topic="all_notices",
    )
    try:
        response = messaging.send(message)
        print(f"  [FCM 발송 성공] {post.get('title')}: {response}")
    except Exception as e:
        print(f"  [FCM 발송 실패]: {e}")

# ── 크롤링 대상 설정 ─────────────────────────────────────────
BOARDS = [
    {
        "id":          "main_notice",
        "name":        "공지사항",
        "menu_idx":    "66",
        "bbs_mst_idx": "BM0000000026",
    },
    {
        "id":          "main_academic",
        "name":        "학사공지",
        "menu_idx":    "169",
        "bbs_mst_idx": "BM0000000025",
    },
    {
        "id":          "main_scholarship",
        "name":        "장학공지",
        "menu_idx":    "208",
        "bbs_mst_idx": "BM0000000032",
    },
]

BASE_URL = "https://www.mjc.ac.kr"
HEADERS  = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}


def _parse_iso_date(date_str: str | None) -> datetime | None:
    if not date_str or not isinstance(date_str, str):
        return None
    m = re.match(r"^(\d{4}-\d{2}-\d{2})", date_str.strip())
    if not m:
        return None
    try:
        return datetime.strptime(m.group(1), "%Y-%m-%d")
    except ValueError:
        return None


def _min_post_date_cutoff() -> datetime | None:
    """환경변수 MIN_POST_DATE (YYYY-MM-DD). 비우면 필터 끔 → 전체 허용."""
    raw = os.environ.get("MIN_POST_DATE", "2026-01-01")
    if not raw.strip():
        return None
    try:
        return datetime.strptime(raw.strip(), "%Y-%m-%d")
    except ValueError:
        raise ValueError(
            f"MIN_POST_DATE must be YYYY-MM-DD or empty, got: {raw!r}"
        ) from None


def post_passes_min_date(post: dict) -> bool:
    cutoff = _min_post_date_cutoff()
    if cutoff is None:
        return True
    dt = _parse_iso_date(post.get("date"))
    if dt is None:
        return False
    return dt >= cutoff


def min_post_date_hint() -> str:
    """로그용: 기본 2026-01-01, MIN_POST_DATE 비우면 필터 끔."""
    c = _min_post_date_cutoff()
    if c is None:
        return "날짜 필터: 끔 (MIN_POST_DATE 빈 문자열)"
    return f"날짜 필터: {c.date()} 이상만 저장 (MIN_POST_DATE, 끄려면 빈 문자열)"


# ── 게시판 1페이지 크롤링 ────────────────────────────────────
def crawl_page(board: dict, page: int = 1) -> list[dict]:
    data = {
        "pageIndex":    str(page),
        "SC_KEY":       "",
        "SC_KEYWORD":   "",
        "bbs_mst_idx":  board["bbs_mst_idx"],
        "menu_idx":     board["menu_idx"],
        "tabCnt":       "",
        "per_menu_idx": "",
        "submenu_idx":  "",
        "data_idx":     "",
        "memberAuth":   "Y",
    }
    res = requests.post(BASE_URL + "/bbs/data/list.do", headers=HEADERS, data=data, timeout=10)
    soup = BeautifulSoup(res.text, "html.parser")

    results = []
    for row in soup.select("table tbody tr"):
        cols    = row.find_all("td")
        link_tag = row.find("a", href=True)
        if not cols or not link_tag:
            continue

        # data_idx 추출 (fn_view 패턴)
        href = link_tag.get("href", "")
        m    = re.search(r"fn_view\('(\w+)','(\w+)'", href)
        if not m:
            continue

        bbs_id   = m.group(1)
        data_id  = m.group(2)
        view_url = (
            f"{BASE_URL}/bbs/data/view.do"
            f"?menu_idx={board['menu_idx']}"
            f"&bbs_mst_idx={bbs_id}"
            f"&data_idx={data_id}"
        )

        # 날짜 추출
        date_text = ""
        for td in cols:
            text = td.get_text(strip=True)
            if re.match(r"\d{4}-\d{2}-\d{2}", text):
                date_text = text
                break

        title = link_tag.get_text(strip=True)
        if not title:
            continue

        results.append({
            "data_idx":  data_id,
            "source":    board["id"],
            "category":  board["name"],
            "title":     title,
            "url":       view_url,
            "date":      date_text,
            "is_new":    False,   # Firestore 저장 시 판단
            "created_at": datetime.now().isoformat(),
        })

    return results

# ── Firestore 저장 (증분 업데이트) ──────────────────────────
def save_to_firestore(db, board: dict, posts: list[dict]):
    if not posts:
        return

    col_ref  = db.collection("notices").document(board["id"])
    meta_ref = col_ref.collection("meta").document("info")
    post_col = col_ref.collection("posts")

    # 저장된 최신 data_idx 조회 (목록 맨 위 글과 비교 — 날짜 필터와 무관하게 고정)
    meta_doc   = meta_ref.get()
    latest_id  = meta_doc.to_dict().get("latest_id", "") if meta_doc.exists else ""

    new_count = 0
    skipped_by_date = 0
    for post in posts:
        if post["data_idx"] == latest_id:
            break   # 이미 저장된 글부터는 스킵

        if not post_passes_min_date(post):
            skipped_by_date += 1
            continue

        post["is_new"] = True
        post_col.document(post["data_idx"]).set(post)
        
        # 기존 데이터가 존재하던 상태(latest_id 존재)에서 등록된 진짜 새 글일 때만 알람 발송 (초기화 폭탄 방지)
        if latest_id:
            send_fcm_notice(post)

        new_count += 1

    # 항상 실제 게시판 1페이지 맨 위 글로 갱신 (필터로 저장 안 해도 앵커는 따라감)
    meta_ref.set({
        "latest_id":  posts[0]["data_idx"],
        "updated_at": datetime.now().isoformat(),
        "board_name": board["name"],
    })
    cutoff = _min_post_date_cutoff()
    filter_note = ""
    if cutoff is not None:
        filter_note = f" (MIN_POST_DATE={cutoff.date()} 이후만 저장)"
    if skipped_by_date and cutoff is not None:
        filter_note += f", 날짜로 제외 {skipped_by_date}건"
    if new_count > 0:
        print(f"  [{board['name']}] 새 글 {new_count}건 저장 완료{filter_note}")
    else:
        print(f"  [{board['name']}] 새로 저장된 글 없음 (목록 앵커 갱신됨){filter_note}")

# ── 최초 전체 수집 ───────────────────────────────────────────
def full_crawl(db, board: dict, max_pages: int = 5):
    print(f"[전체 수집] {board['name']} 시작 (최대 {max_pages}페이지)")
    all_posts = []
    first_row_anchor: str | None = None
    for page in range(1, max_pages + 1):
        posts = crawl_page(board, page)
        if not posts:
            break
        if first_row_anchor is None:
            first_row_anchor = posts[0]["data_idx"]
        all_posts.extend(posts)
        print(f"  {page}페이지: {len(posts)}건")

    raw_total = len(all_posts)
    all_posts = [p for p in all_posts if post_passes_min_date(p)]
    cutoff = _min_post_date_cutoff()
    if cutoff is not None:
        print(
            f"  날짜 필터(MIN_POST_DATE={cutoff.date()}): "
            f"{raw_total}건 중 {len(all_posts)}건만 저장 대상"
        )

    # 전체 저장 (latest_id 없을 때)
    post_col = db.collection("notices").document(board["id"]).collection("posts")
    meta_ref = db.collection("notices").document(board["id"]).collection("meta").document("info")

    if all_posts:
        batch = db.batch()
        for post in all_posts:
            batch.set(post_col.document(post["data_idx"]), post)
        batch.commit()

    # 증분 크롤과 동일하게, 앵커는 사이트 1페이지 맨 위(필터 전) 기준
    if first_row_anchor is not None:
        meta_ref.set({
            "latest_id":  first_row_anchor,
            "updated_at": datetime.now().isoformat(),
            "board_name": board["name"],
        })

    print(f"  총 {len(all_posts)}건 저장 완료 (원본 목록 {raw_total}건)\n")

# ── 증분 업데이트 (GitHub Actions 30분 주기 실행) ────────────
def incremental_update(db, board: dict):
    print(f"[업데이트] {board['name']} 확인 중...")
    posts = crawl_page(board, page=1)
    save_to_firestore(db, board, posts)

# ── 메인 ────────────────────────────────────────────────────
def main():
    db   = init_firebase()
    mode = os.environ.get("CRAWL_MODE", "incremental")  # full / incremental

    for board in BOARDS:
        if mode == "full":
            full_crawl(db, board, max_pages=5)
        else:
            incremental_update(db, board)

if __name__ == "__main__":
    main()
