import requests
import re
from bs4 import BeautifulSoup
from datetime import datetime
import firebase_admin
from firebase_admin import credentials, firestore
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
        cred = credentials.Certificate("serviceAccountKey.json")

    firebase_admin.initialize_app(cred)
    return firestore.client()

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

    # 저장된 최신 data_idx 조회
    meta_doc   = meta_ref.get()
    latest_id  = meta_doc.to_dict().get("latest_id", "") if meta_doc.exists else ""

    new_count = 0
    for post in posts:
        if post["data_idx"] == latest_id:
            break   # 이미 저장된 글부터는 스킵

        post["is_new"] = True
        post_col.document(post["data_idx"]).set(post)
        new_count += 1

    # meta 업데이트 (첫 번째 글이 최신)
    if new_count > 0 or not meta_doc.exists:
        meta_ref.set({
            "latest_id":  posts[0]["data_idx"],
            "updated_at": datetime.now().isoformat(),
            "board_name": board["name"],
        })
        print(f"  [{board['name']}] 새 글 {new_count}건 저장 완료")
    else:
        print(f"  [{board['name']}] 새 글 없음 (최신 유지)")

# ── 최초 전체 수집 ───────────────────────────────────────────
def full_crawl(db, board: dict, max_pages: int = 5):
    print(f"[전체 수집] {board['name']} 시작 (최대 {max_pages}페이지)")
    all_posts = []
    for page in range(1, max_pages + 1):
        posts = crawl_page(board, page)
        if not posts:
            break
        all_posts.extend(posts)
        print(f"  {page}페이지: {len(posts)}건")

    # 전체 저장 (latest_id 없을 때)
    post_col = db.collection("notices").document(board["id"]).collection("posts")
    meta_ref = db.collection("notices").document(board["id"]).collection("meta").document("info")

    batch = db.batch()
    for post in all_posts:
        batch.set(post_col.document(post["data_idx"]), post)
    batch.commit()

    if all_posts:
        meta_ref.set({
            "latest_id":  all_posts[0]["data_idx"],
            "updated_at": datetime.now().isoformat(),
            "board_name": board["name"],
        })

    print(f"  총 {len(all_posts)}건 저장 완료\n")

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
