import requests
import re
from bs4 import BeautifulSoup
from datetime import datetime
import firebase_admin
from firebase_admin import credentials, firestore, messaging
import os
import json
import hashlib

# ── Firebase 초기화 ──────────────────────────────────────────
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

# ── FCM 메시지 발송 (Data Payload) ──────────────────────────
def send_fcm_notice(prog: dict):
    message = messaging.Message(
        data={
            "title": "[MPU 핵심역량] 새 프로그램 등록",
            "body": prog.get("title", ""),
            "url": prog.get("image_url", ""),
            "board": "MPU 프로그램"
        },
        topic="all_notices",
    )
    try:
        response = messaging.send(message)
        print(f"  [FCM 발송 성공] {prog.get('title')}: {response}")
    except Exception as e:
        print(f"  [FCM 발송 실패]: {e}")

# ── 크롤링 ───────────────────────────────────────────────────
def crawl_programs() -> list[dict]:
    url = "https://mpu.mjc.ac.kr/Main/default.aspx"
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    }

    try:
        res = requests.get(url, headers=headers, timeout=10)
        res.encoding = 'utf-8'
        soup = BeautifulSoup(res.text, "html.parser")
    except Exception as e:
        print(f"Fetch failed: {e}")
        return []

    results = []
    
    # "전체" 탭 (tab1) 의 프로그램 목록
    tab1 = soup.select_one("#tab1")
    if not tab1:
        return []

    # 전체보기 썸네일(li.all-list) 제외
    items = tab1.select("li.ex_slide2_li:not(.all-list)")
    
    for item in items:
        # 프로그램 ID 또는 고유 식별자 생성용
        img_tag = item.select_one(".d-div img")
        img_src = img_tag["src"] if img_tag and img_tag.has_attr("src") else ""
        
        # 기본 배너가 아니면 프로그램 ID가 이미지명 맨 앞에 있을 확률이 높음 (예: 6243_005.jpg)
        prog_id = ""
        m = re.match(r".*/(\d+)_.*", img_src)
        if m:
            prog_id = m.group(1)

        d_day_tag = item.select_one(".d-day")
        d_day = d_day_tag.get_text(strip=True) if d_day_tag else ""

        h6_tags = item.select(".p-15 h6")
        title = h6_tags[0].get_text(strip=True) if len(h6_tags) > 0 else ""
        branch = h6_tags[1].get_text(strip=True) if len(h6_tags) > 1 else ""

        # 특성 태그 추출 (#의사소통능력 등)
        tags = []
        for span in item.select(".p-15 dl dd span"):
            tags.append(span.get_text(strip=True).replace("#", ""))

        cal_tags = item.select(".p-15 p")
        reg_date = ""
        edu_date = ""
        for tag in cal_tags:
            text = tag.get_text(strip=True)
            if text.startswith("신청 :"):
                reg_date = text.replace("신청 :", "").strip()
            elif text.startswith("교육 :"):
                edu_date = text.replace("교육 :", "").strip()
        
        if not title:
            continue

        # 강제로 ID 만들기: 없으면 제목+신청일 해시
        if not prog_id:
            raw_str = f"{title}_{reg_date}"
            prog_id = hashlib.md5(raw_str.encode("utf-8")).hexdigest()[:10]
            
        full_img_url = ""
        if img_src:
            full_img_url = "https://mpu.mjc.ac.kr" + img_src if img_src.startswith("/") else img_src

        results.append({
            "id": prog_id,
            "title": title,
            "branch": branch,
            "d_day": d_day,
            "tags": tags,
            "reg_date": reg_date,
            "edu_date": edu_date,
            "image_url": full_img_url,
            "created_at": datetime.now().isoformat(),
        })

    return results

# ── Firestore 저장 ───────────────────────────────────────────
def save_to_firestore(db, programs: list[dict]):
    if not programs:
        print("저장할 프로그램이 없습니다.")
        return

    main_doc_ref = db.collection("core_competencies").document("all")
    meta_ref = main_doc_ref.collection("meta").document("info")
    prog_col = main_doc_ref.collection("programs")
    
    # 기존 데이터들 중 현재 웹페이지에 없는 것은 마감/삭제로 간주할 수도 있지만
    # 여기서는 일단 업데이트(수정/추가)만 진행 (upsert)
    # 기존 저장된 항목들을 가져와서 새 글인지 비교 (FCM 알람용)
    existing_docs = prog_col.get()
    existing_ids = set([doc.id for doc in existing_docs])
    
    batch = db.batch()
    new_count = 0
    updated_count = 0

    # 각 프로그램을 순회
    for prog in programs:
        doc_ref = prog_col.document(prog["id"])
        
        # 새로운 프로그램이면 FCM 발송 (단, 최초 수집이 아닐 때만)
        if prog["id"] not in existing_ids:
            if existing_ids:
                send_fcm_notice(prog)
            new_count += 1
        # 여기서 기존 문서가 있는지 체크하는 것은 읽기 비용이 들지만
        # 새 글 알림 등을 위해 체크할 수도 있습니다.
        # 일단은 덮어쓰기 방식으로 처리
        batch.set(doc_ref, prog, merge=True)
        updated_count += 1

    batch.commit()
    
    # 메타 업데이트
    meta_ref.set({
        "updated_at": datetime.now().isoformat(),
        "total_active_count": len(programs)
    }, merge=True)

    print(f"[핵심역량 프로그램] 총 {updated_count}건 업데이트 완료")

# ── 메인 ─────────────────────────────────────────────────────
def main():
    db = init_firebase()
    print("[수집 시작] 핵심역량 프로그램")
    programs = crawl_programs()
    print(f"  > {len(programs)}개 찾음")
    save_to_firestore(db, programs)

if __name__ == "__main__":
    main()
