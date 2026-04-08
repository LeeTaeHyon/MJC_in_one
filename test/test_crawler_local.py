import requests
import re
from bs4 import BeautifulSoup
from datetime import datetime
import os

# crawler_mjc.py에서 필요한 설정과 함수만 가져오거나 복사합니다.
# 여기서는 간단한 테스트를 위해 핵심 로직만 별도로 실행해봅니다.

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

# 세션을 전역으로 사용하여 쿠키 및 연결 상태를 유지합니다.
session = requests.Session()
session.headers.update(HEADERS)

def crawl_detail(url: str) -> str:
    """게시글 상세 페이지에서 본문 내용을 추출합니다."""
    try:
        # 세션을 사용하여 상세 페이지 접속
        res = session.get(url, timeout=10)
        res.raise_for_status()
        
        # NetFunnel 등 대기 페이지가 걸리는지 확인
        if "NetFunnel" in res.text or "잠시만" in res.text:
            return "본문 수집 실패: NetFunnel 대기 페이지가 반환되었습니다."

        soup = BeautifulSoup(res.text, "html.parser")
        
        # 명지전문대 게시판의 본문 영역은 div.view_con 에 담겨 있습니다.
        content_div = soup.select_one("div.view_con")
        if content_div:
            text = content_div.get_text("\n", strip=True)
            return text if text else "본문 텍스트가 비어 있습니다. (이미지 위주 게시물일 수 있음)"
        
        # 실패 시 원인 파악을 위한 디버깅 메시지
        return f"본문 태그(.view_con)를 찾을 수 없습니다. (HTML 길이: {len(res.text)})"

    except Exception as e:
        return f"본문 크롤링 중 오류 발생: {e}"

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
    try:
        # 세션을 사용하여 리스트 요청
        res = session.post(BASE_URL + "/bbs/data/list.do", data=data, timeout=10)
        res.raise_for_status()
    except Exception as e:
        print(f"Error fetching data: {e}")
        return []

    soup = BeautifulSoup(res.text, "html.parser")

    results = []
    for row in soup.select("table tbody tr"):
        cols    = row.find_all("td")
        link_tag = row.find("a", href=True)
        if not cols or not link_tag:
            continue

        href = link_tag.get("href", "")
        # fn_view('ID1', 'ID2', ...) 형태에서 인자들을 추출 (알파벳, 숫자 뿐만 아니라 모든 문자 대응)
        m    = re.search(r"fn_view\s*\(\s*'([^']+)'\s*,\s*'([^']+)'", href)
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
        })

    return results

def main():
    import time
    print("\n" + "="*50)
    print("=== 명지전문대 공지사항 + 본문 크롤링 로컬 테스트 ===")
    print("="*50)
    
    for board in BOARDS:
        print(f"\n[{board['name']}] 목록 가져오는 중...")
        posts = crawl_page(board, page=1)
        
        if not posts:
            print("  글을 찾지 못했습니다.")
            continue
            
        print(f"  총 {len(posts)}개의 글을 가져왔습니다. 최신 2개의 본문을 확인합니다.")
        
        # 전체 리스트 중 상위 2개만 상세 내용 테스트
        for i, post in enumerate(posts[:2]):
            print(f"\n  {i+1}. [{post['date']}] {post['title']}")
            print(f"     URL: {post['url']}")
            
            # 본문 크롤링 실행
            print(f"     [본문 수집 중...]")
            content = crawl_detail(post['url'])
            
            # 본문 요약 (첫 150자)
            summary = content.replace("\n", " ")[:150]
            print(f"     [본문 요약]: {summary}...")
            
            # 서버 부하 방지를 위해 짧은 시간 대기
            time.sleep(0.5)

if __name__ == "__main__":
    main()
