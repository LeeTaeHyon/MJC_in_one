import hashlib
import json
import os
import re
from datetime import datetime

import firebase_admin
import requests
from bs4 import BeautifulSoup
from firebase_admin import credentials, firestore, messaging

from notice_ai_tags import enrich_post_dict

BASE_URL = "https://www.mjc.ac.kr"
SCHEDULE_URL = f"{BASE_URL}/collegeService/schedule.do?menu_idx=104"
BOARD_ID = "main_schedule"
BOARD_NAME = "학사일정"
SEND_FCM = False
SCHEDULE_KIND_VERSION = "v2"
HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/123.0.0.0 Safari/537.36"
    ),
    # year/hakgi가 포함된 URL에서 404로 떨어지는 케이스가 있어
    # 브라우저에 가깝게 헤더를 맞춰준다.
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language": "ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7",
    "Accept-Encoding": "gzip, deflate, br",
    "Connection": "keep-alive",
    "Upgrade-Insecure-Requests": "1",
}


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


def _to_iso(date_text: str) -> str:
    return date_text.replace(".", "-")


def _stable_id(start_date: str, end_date: str, title: str) -> str:
    raw = f"{start_date}|{end_date}|{title}".encode("utf-8")
    return hashlib.md5(raw).hexdigest()[:12]


def _classify_schedule_kind(title: str) -> str:
    """
    학사일정 전용 kind 분류 (v2).
    - exam / registration / grades / scholarship / worship / general
    """
    t = (title or "").strip()
    if not t:
        return "general"

    # 우선순위: grades > exam > registration > scholarship > worship > general
    if re.search(
        r"(성적|강의\s*평가|강의평가|평가\s*입력|성적\s*입력|성적열람|성적\s*열람|"
        r"성적정정|정정\s*기간)",
        t,
    ):
        return "grades"
    if re.search(r"(시험|중간고사|기말고사|고사|재시험|추가시험|보강시험)", t):
        return "exam"
    if re.search(
        r"(수강신청|수강\s*정정|수강정정|수강\s*철회|수강철회|수강\s*변경|수강변경|"
        r"수강꾸러미|장바구니|예비\s*수강신청|재수강|분반\s*변경|폐강|증원)",
        t,
    ):
        return "registration"
    if re.search(
        r"(장학|장학금|국가장학|근로장학|학자금|대출|등록금|분납|납부|고지서|추가\s*등록)",
        t,
    ):
        return "scholarship"
    if re.search(r"(예배|채플|기도회|예식)", t):
        return "worship"
    return "general"


def send_fcm_notice(post: dict):
    message = messaging.Message(
        data={
            "title": f"[{BOARD_NAME}] 새 일정 등록",
            "body": post.get("title", ""),
            "url": post.get("url", ""),
            "board": BOARD_NAME,
            "source": "mjc",
        },
        topic="all_notices",
    )
    try:
        response = messaging.send(message)
        print(f"  [FCM 발송 성공] {post.get('title')}: {response}")
    except Exception as e:
        print(f"  [FCM 발송 실패]: {e}")


def _fetch_schedule_page(year: int, hakgi: int) -> str:
    # 페이지 JS는 location.href로 year/hakgi를 붙여 이동한다.
    # (POST submit도 주석 처리되어 있어, GET으로 맞추는 편이 안전)
    res = requests.get(
        f"{BASE_URL}/collegeService/schedule.do",
        params={
            "menu_idx": "104",
            "year": str(year),
            "hakgi": str(hakgi),
        },
        headers=HEADERS,
        timeout=10,
    )
    res.raise_for_status()
    return res.text


def _parse_schedule_html(html: str, *, semester_fallback: str = "") -> list[dict]:
    soup = BeautifulSoup(html, "html.parser")

    current_semester = semester_fallback or ""
    current_month = ""
    records: list[dict] = []

    for node in soup.find_all(["h2", "h3", "h4"]):
        text = node.get_text(" ", strip=True)
        if re.match(r"^\d{4}년\s+\d학기", text):
            current_semester = text
            continue
        month_match = re.match(r"^(\d{1,2})월", text)
        if month_match:
            current_month = month_match.group(1).zfill(2)
            continue

        date_match = re.match(
            r"^(\d{4}\.\d{2}\.\d{2})\s*~\s*(\d{4}\.\d{2}\.\d{2})$",
            text,
        )
        if not date_match:
            continue

        title_node = node.find_next_sibling()
        while title_node is not None and not title_node.get_text(strip=True):
            title_node = title_node.find_next_sibling()
        if title_node is None:
            continue

        title = title_node.get_text(" ", strip=True)
        if not title:
            continue

        start_date = _to_iso(date_match.group(1))
        end_date = _to_iso(date_match.group(2))
        records.append(
            {
                "id": _stable_id(start_date, end_date, title),
                "source": BOARD_ID,
                "category": BOARD_NAME,
                "title": title,
                "start_date": start_date,
                "end_date": end_date,
                "date": start_date,
                "url": SCHEDULE_URL,
                "semester": current_semester,
                "month": current_month,
                "created_at": datetime.now().isoformat(),
            }
        )

    records.sort(key=lambda item: (item["start_date"], item["title"]))
    return records


def crawl_schedule(year: int | None = None, hakgi_list: list[int] | None = None) -> list[dict]:
    """
    MJC 학사일정은 학기(hakgi) 별로 페이지가 나뉘어 렌더링됨.
    기본 화면(대개 1학기)만 GET으로 긁으면 2학기(9~2월)가 누락될 수 있어
    year/hakgi를 POST로 각각 요청해서 합친다.
    """
    if year is None:
        year = datetime.now().year
    if hakgi_list is None:
        hakgi_list = [1, 2]

    all_records: list[dict] = []
    seen_ids: set[str] = set()

    for hakgi in hakgi_list:
        html = _fetch_schedule_page(year=year, hakgi=hakgi)
        semester_fallback = f"{year}년 {hakgi}학기"
        records = _parse_schedule_html(html, semester_fallback=semester_fallback)

        # 페이지에 학기 헤더가 없거나 파싱이 빗나간 경우 fallback 주입
        for r in records:
            if not r.get("semester"):
                r["semester"] = semester_fallback
            if r["semester"] and not re.match(r"^\d{4}년\s+\d학기", r["semester"]):
                r["semester"] = semester_fallback

            if r["id"] in seen_ids:
                continue
            seen_ids.add(r["id"])
            all_records.append(r)

    all_records.sort(key=lambda item: (item["start_date"], item["title"]))
    return all_records


def save_to_firestore(db, records: list[dict]):
    if not records:
        print("[학사일정] 저장할 데이터가 없습니다.")
        return

    board_ref = db.collection("notices").document(BOARD_ID)
    meta_ref = board_ref.collection("meta").document("info")
    post_col = board_ref.collection("posts")

    meta_doc = meta_ref.get()
    latest_id = meta_doc.to_dict().get("latest_id", "") if meta_doc.exists else ""
    known_ids = {doc.id for doc in post_col.stream()}

    batch = db.batch()
    new_posts: list[dict] = []
    for post in records:
        post["schedule_kind"] = _classify_schedule_kind(post.get("title", ""))
        post["schedule_kind_version"] = SCHEDULE_KIND_VERSION
        enrich_post_dict(post, BOARD_ID)
        batch.set(post_col.document(post["id"]), post, merge=True)
        if post["id"] not in known_ids:
            new_posts.append(post)
    batch.commit()

    latest_record = records[0]
    meta_ref.set(
        {
            "latest_id": latest_record["id"],
            "updated_at": datetime.now().isoformat(),
            "board_name": BOARD_NAME,
            "total_count": len(records),
        },
        merge=True,
    )

    if SEND_FCM and latest_id:
        for post in new_posts:
            send_fcm_notice(post)

    print(f"[학사일정] 총 {len(records)}건 저장 완료, 신규 {len(new_posts)}건")


def backfill_schedule_kind(db, *, limit: int | None = None, dry_run: bool = False) -> int:
    """
    기존 main_schedule 문서에 schedule_kind 필드를 채웁니다.
    - schedule_kind가 없는 문서만 대상으로 합니다.
    - merge 업데이트(부분 업데이트)로 안전하게 동작합니다.
    """
    post_col = (
        db.collection("notices")
        .document(BOARD_ID)
        .collection("posts")
    )

    updated = 0
    batch = db.batch()
    ops = 0

    for doc in post_col.stream():
        data = doc.to_dict() or {}
        if data.get("schedule_kind"):
            continue

        title = str(data.get("title") or "")
        kind = _classify_schedule_kind(title)
        payload = {
            "schedule_kind": kind,
            "schedule_kind_version": SCHEDULE_KIND_VERSION,
            "schedule_kind_backfilled_at": datetime.now().isoformat(),
        }

        updated += 1
        if not dry_run:
            batch.set(post_col.document(doc.id), payload, merge=True)
            ops += 1
            # Firestore batch write limit safety
            if ops >= 400:
                batch.commit()
                batch = db.batch()
                ops = 0

        if limit is not None and updated >= limit:
            break

    if not dry_run and ops > 0:
        batch.commit()

    print(f"[학사일정][backfill] schedule_kind 업데이트: {updated}건 (dry_run={dry_run})")
    return updated


def main():
    db = init_firebase()
    print("[수집 시작] 학사일정")
    save_to_firestore(db, crawl_schedule())
    if os.environ.get("SCHEDULE_KIND_BACKFILL", "").strip() in ("1", "true", "TRUE", "yes", "YES"):
        backfill_schedule_kind(db)


if __name__ == "__main__":
    main()
