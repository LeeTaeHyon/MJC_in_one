import requests
import re
from bs4 import BeautifulSoup
from datetime import datetime
import firebase_admin
from firebase_admin import credentials, firestore, messaging
import os
import json

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
def send_fcm_notice(collection_name: str, rec: dict):
    board_name = "CTL 프로그램" if collection_name == "programs" else "CTL 공지사항"
    message = messaging.Message(
        data={
            "title": f"[{board_name}] 새 글 등록",
            "body": rec.get("title", ""),
            "url": rec.get("link", ""),
            "board": board_name
        },
        topic="all_notices",
    )
    try:
        response = messaging.send(message)
        print(f"  [FCM 발송 성공] {rec.get('title')}: {response}")
    except Exception as e:
        print(f"  [FCM 발송 실패]: {e}")

# ── 프로그램 크롤링 ─────────────────────────────────────────
def crawl_programs(page: int = 1) -> list[dict]:
    url = "https://ctl.mjc.ac.kr/ctl/stu/program_list.acl"
    data = {
        "MENU_SEQ": "",
        "CATEGORY_SEQ": "",
        "PRG_SEQ": "",
        "PRG_DV": "S",
        "start": str(page),
        "display": "10",
        "encoding": "utf-8"
    }
    headers = {"User-Agent": "Mozilla/5.0"}
    
    res = requests.post(url, data=data, headers=headers, timeout=10)
    res.encoding = 'utf-8'
    soup = BeautifulSoup(res.text, "html.parser")
    
    results = []
    # 데스크탑용 테이블 내 tbody tr 순회 (모바일용 div.m-info-table는 무시)
    table = soup.select_one("table.info-table tbody")
    if not table:
        return []
        
    rows = table.find_all("tr", recursive=False)
    for row in rows:
        tds = row.find_all("td", recursive=False)
        if len(tds) < 6:
            continue
            
        prog_no = tds[0].get_text(strip=True)
        category = tds[1].get_text(strip=True)
        title_tag = tds[2]
        title = title_tag.get_text(strip=True)
        
        # onclick에서 OPEN_PRG_SEQ 추출
        onclick_attr = title_tag.get("onclick", "")
        m = re.search(r"OPEN_PRG_SEQ=(\d+)", onclick_attr)
        prog_id = m.group(1) if m else prog_no
        
        reg_date_str = tds[3].get_text(strip=True)
        reg_count = tds[4].get_text(strip=True)
        status = tds[5].get_text(strip=True)
        
        link = f"https://ctl.mjc.ac.kr/ctl/stu/program_view_form.acl?OPEN_PRG_SEQ={prog_id}"
        
        # 상세페이지 방문해서 진행기간 가져오기
        op_period = ""
        try:
            r_detail = requests.get(link, headers=headers, timeout=10)
            r_detail.encoding = r_detail.apparent_encoding if r_detail.apparent_encoding else 'utf-8'
            s_detail = BeautifulSoup(r_detail.text, "html.parser")
            
            # 1. 텍스트 전체에서 '진행기간', '교육기간', '일시' 키워드 근처 데이터 추출
            all_text = s_detail.get_text(separator=" ", strip=True)
            
            # 정규식 설명: 키워드 뒤에 공백/콜론 무시하고 날짜+시간+물결표 조합을 최대한 긁어옴
            pattern = r"(?:진행기간|운영기간|교육기간|교육일시|일시)\s*[:]?\s*([\d\.\s\~\:\(가-힣\)]+)"
            matches = re.findall(pattern, all_text)
            
            for m in matches:
                clean_val = m.strip()
                # 너무 짧거나 reg_date와 똑같으면 무시
                if len(clean_val) > 10 and clean_val != reg_date_str:
                    # 다음 키워드가 섞여 들어오지 않게 앞부분만 슬라이싱 (보통 날짜 끝은 빈칸)
                    # 만약 다른 레이블(신청기간 등)이 섞이면 거기서 자름
                    for stop_word in ["신청기간", "대상", "모집", "장소"]:
                        if stop_word in clean_val:
                            clean_val = clean_val.split(stop_word)[0].strip()
                    op_period = clean_val
                    break
        except Exception:
            pass
        
        results.append({
            "id": prog_id,
            "no": prog_no,
            "category": category,
            "title": title,
            "reg_date": reg_date_str,
            "op_period": op_period,
            "reg_count": reg_count,
            "status": status,
            "link": link,
            "created_at": datetime.now().isoformat(),
        })
        
    return results

# ── 공지사항 크롤링 ─────────────────────────────────────────
def crawl_notices(page: int = 1) -> list[dict]:
    url = "https://ctl.mjc.ac.kr/ctl/stu/program_notice_list.acl"
    data = {
        "MENU_DV": "ST",
        "MENU_SEQ": "",
        "SUB_MENU_SEQ": "",
        "SUB_MENU_SEQ2": "",
        "SCH_VAL": "",
        "start": str((page - 1) * 10 + 1), # 페이징이 start index 방식일 경우 유의 (보통 1, 11, 21...)
        "display": "10",
        "encoding": "utf-8"
    }
    headers = {"User-Agent": "Mozilla/5.0"}
    
    res = requests.post(url, data=data, headers=headers, timeout=10)
    res.encoding = 'utf-8'
    soup = BeautifulSoup(res.text, "html.parser")
    
    results = []
    # 데스크탑용 테이블
    table = soup.select_one("table.info-table tbody")
    if not table:
        return []
        
    rows = table.find_all("tr", recursive=False)
    for row in rows:
        tds = row.find_all("td", recursive=False)
        if len(tds) < 5:
            continue
            
        notice_no = tds[0].get_text(strip=True)
        title_tag = tds[1]
        title = title_tag.get_text(strip=True)
        
        # onclick에서 ARTL_SEQ_NO 추출
        onclick_attr = title_tag.get("onclick", "")
        m = re.search(r"ARTL_SEQ_NO=(\d+)", onclick_attr)
        notice_id = m.group(1) if m else notice_no
        
        author = tds[2].get_text(strip=True)
        date_str = tds[3].get_text(strip=True)
        views = tds[4].get_text(strip=True)
        
        link = f"https://ctl.mjc.ac.kr/ctl/stu/program_notice_view_form.acl?ARTL_SEQ_NO={notice_id}"
        
        results.append({
            "id": notice_id,
            "no": notice_no,
            "title": title,
            "author": author,
            "date": date_str,
            "views": views,
            "link": link,
            "created_at": datetime.now().isoformat(),
        })
        
    return results

# ── Firestore 저장 ───────────────────────────────────────────
def save_to_firestore(db, collection_name: str, records: list[dict]):
    if not records:
        print(f"[{collection_name}] 저장할 데이터가 없습니다.")
        return

    main_doc_ref = db.collection("ctl_data").document(collection_name)
    meta_ref = main_doc_ref.collection("meta").document("info")
    record_col = main_doc_ref.collection("items")
    
    batch = db.batch()
    new_count = 0
    updated_count = 0

    # 저장된 최신 id 조회 (증분 업데이트용)
    meta_doc = meta_ref.get()
    latest_id = meta_doc.to_dict().get("latest_id", "") if meta_doc.exists else ""

    has_found_latest = False
    for rec in records:
        if latest_id and rec["id"] == latest_id:
            has_found_latest = True
            
        # 첫 번째 페이지에서 기존의 latest_id를 만나기 전까지는 무조건 새 글
        if latest_id and not has_found_latest:
            send_fcm_notice(collection_name, rec)

        # DB에 최신 id와 같다면 증분 업데이트 일 때 스킵할 수 있음 
        # (여기선 단순 1페이지 전체 업데이트/덮어쓰기로 구현)
        doc_ref = record_col.document(rec["id"])
        batch.set(doc_ref, rec, merge=True)
        updated_count += 1

    batch.commit()
    
    # 메타 업데이트 (첫 번째 항목이 최신 항목이라고 가정)
    meta_ref.set({
        "latest_id": records[0]["id"] if records else latest_id,
        "updated_at": datetime.now().isoformat(),
        "total_active_count": len(records)
    }, merge=True)

    print(f"[{collection_name}] 총 {updated_count}건 업데이트 완료")

# ── 메인 ─────────────────────────────────────────────────────
def main():
    db = init_firebase()
    
    print("[수집 시작] CTL 프로그램 목록")
    programs = crawl_programs(page=1)
    save_to_firestore(db, "programs", programs)
    
    print("[수집 시작] CTL 공지사항")
    notices = crawl_notices(page=1)
    save_to_firestore(db, "notices", notices)

if __name__ == "__main__":
    main()
