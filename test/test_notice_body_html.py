"""notice_body body_html / AI 입력 분리 단위 테스트."""

from __future__ import annotations

from bs4 import BeautifulSoup

from notice_body import (
    _BODY_IMAGE_ONLY_PLACEHOLDER,
    body_text_for_ai,
    clean_body_text,
    enrich_body_only,
    enrich_summary_only,
    extract_body_html,
    fetch_mjc_view_body,
)


def test_extract_body_html_strips_script_and_resolves_img_src():
    soup = BeautifulSoup(
        '<motion><img src="/upload/poster.jpg"/><script>alert(1)</script></motion>',
        "html.parser",
    )
    node = soup.find("motion")
    html = extract_body_html(node, base_url="https://www.mjc.ac.kr")
    assert "script" not in html.lower()
    assert 'src="https://www.mjc.ac.kr/upload/poster.jpg"' in html
    assert "<img" in html


def test_image_only_body_empty_html_kept(monkeypatch):
    html_page = """
    <html><head><title>테스트 공지</title></head>
    <body><motion id="divMemo" class="memo"><img src="/upload/poster.jpg"/></motion></body></html>
  """

    class FakeRes:
        status_code = 200
        encoding = "utf-8"
        apparent_encoding = "utf-8"
        text = html_page

    def _fake_get(url, **kwargs):
        return FakeRes()

    monkeypatch.setattr("notice_body.requests.get", _fake_get)

    body, body_html, _title, err = fetch_mjc_view_body(
        "https://www.mjc.ac.kr/notice/view.do?idx=1"
    )
    assert err is None
    assert body == ""
    assert "<img" in body_html
    assert _BODY_IMAGE_ONLY_PLACEHOLDER not in body


def test_body_text_for_ai_strips_placeholder():
    assert body_text_for_ai(_BODY_IMAGE_ONLY_PLACEHOLDER) == ""
    assert body_text_for_ai("  실제 본문  ") == "실제 본문"


def test_clean_body_text_plain():
    soup = BeautifulSoup("<p>안녕하세요.</p><p>두 번째 문단.</p>", "html.parser")
    text = clean_body_text(soup)
    assert "안녕하세요" in text
    assert "두 번째" in text


def test_enrich_body_only_preserves_summary(monkeypatch):
    html_page = """
    <html><body><div id="motion" class="memo"><img src="/upload/poster.jpg"/></div></body></html>
    """

    class FakeRes:
        status_code = 200
        encoding = "utf-8"
        apparent_encoding = "utf-8"
        text = html_page

    monkeypatch.setattr("notice_body.requests.get", lambda *a, **k: FakeRes())

    post = {
        "url": "https://www.mjc.ac.kr/notice/view.do?idx=1",
        "summary": "기존 AI 요약",
        "summary_version": "gemini-2.0-flash-v1",
    }
    enrich_body_only(post)
    assert post["summary"] == "기존 AI 요약"
    assert post["summary_version"] == "gemini-2.0-flash-v1"
    assert "<img" in post["body_html"]


def test_enrich_summary_only_uses_existing_body():
    post = {
        "title": "테스트 공지",
        "body": "첫 문단입니다. " * 20,
        "body_html": "",
        "summary": "",
        "summary_version": "",
    }
    enrich_summary_only(post)
    assert post["summary"]
    assert post["summary_version"] == "heuristic-v1"
