"""
공지 본문 수집 + 요약 (휴리스틱 / LM Studio).

MJC `view.do` 페이지의 본문 컨테이너는 `#divMemo.memo` 입니다.
실측은 test 디렉터리에서 임시 inspection 스크립트로 확정했습니다.

LM Studio 요약 디버그 (stderr):
  PowerShell: `$env:LMSTUDIO_DEBUG = "1"`
  CMD: `set LMSTUDIO_DEBUG=1`

사용:
  body, summary, info = fetch_and_summarize(view_url)

`info` 는 진단용 메타입니다(error, byte_count 등).
"""

from __future__ import annotations

import json
import os
import re
import sys
import traceback
from datetime import datetime
from typing import Any

import requests
from bs4 import BeautifulSoup

SUMMARY_HEURISTIC_VERSION = "heuristic-v1"
SUMMARY_LMSTUDIO_VERSION = "lmstudio-v1"
SUMMARY_MANUAL_VERSION = "manual"


def _lmstudio_debug_enabled() -> bool:
    return os.environ.get("LMSTUDIO_DEBUG", "").strip().lower() in (
        "1",
        "true",
        "yes",
        "on",
    )


def _lm_log(msg: str) -> None:
    """LM Studio 관련 진단 로그 (환경변수 켰을 때만 stderr)."""
    if _lmstudio_debug_enabled():
        print(f"[notice_body/lmstudio] {msg}", file=sys.stderr)


_DEFAULT_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml",
    "Accept-Language": "ko,en;q=0.8",
}

# 본문 컨테이너 우선순위 (실측 기준)
_BODY_SELECTORS: tuple[str, ...] = (
    "#divMemo",
    ".memo",
    ".bbs_view .memo",
    ".board_view .memo",
)

# 본문 검색 fallback 시 제외할 컨테이너 (헤더/네비/스크립트성)
_EXCLUDE_TAGS: tuple[str, ...] = ("script", "style", "noscript", "iframe")

# 텍스트 본문 없이 이미지(포스터)만 있는 게시판 글 안내
_BODY_IMAGE_ONLY_PLACEHOLDER = (
    "이 게시글은 텍스트 본문 없이 안내 이미지(포스터)만 포함되어 있습니다. "
    "자세한 내용은 본문 확인에서 원문 페이지를 열어 이미지를 확인해 주세요."
)

# 정제 시 제거할 라인 키워드 (헤더/메뉴/푸터 잔재)
_NOISE_LINE_PATTERNS: tuple[re.Pattern[str], ...] = (
    re.compile(r"^\s*(이전\s*글|다음\s*글|목록)\s*$"),
    re.compile(r"^\s*첨부파일\s*:?$"),
    re.compile(r"^\s*조회수\s*\d+\s*$"),
)


# ────────────────────────────────────────────────────────────────────
#  본문 fetch
# ────────────────────────────────────────────────────────────────────

def fetch_mjc_view_body(
    view_url: str,
    *,
    timeout: float = 15.0,
    session: requests.Session | None = None,
) -> tuple[str, str | None]:
    """MJC view.do 본문 plain text 추출.

    Returns:
        (body_text, error_message)  — error 가 None 이면 성공.
    """
    if not view_url:
        return "", "empty_url"
    sess = session or requests
    try:
        res = sess.get(view_url, headers=_DEFAULT_HEADERS, timeout=timeout)
    except requests.RequestException as exc:  # 네트워크/타임아웃
        return "", f"http_error:{type(exc).__name__}"
    if res.status_code != 200:
        return "", f"status:{res.status_code}"

    # MJC 페이지는 charset 메타 기반 자동 추론이 잘 안 될 때가 있어 명시적으로 본다.
    res.encoding = res.apparent_encoding or "utf-8"
    soup = BeautifulSoup(res.text, "html.parser")

    node = None
    for sel in _BODY_SELECTORS:
        node = soup.select_one(sel)
        if node is not None:
            break

    if node is None:
        # fallback: 전체 본문에서 가장 큰 텍스트 컨테이너
        node = _largest_text_container(soup)

    if node is None:
        return "", "no_body_node"

    # 이미지 전용 글: 추출 텍스트는 비었지만 본문 영역에 <img> 가 있는 경우
    has_image = bool(node.find("img"))
    text = clean_body_text(node)
    if has_image and not text.strip():
        return _BODY_IMAGE_ONLY_PLACEHOLDER, None

    return text, None


def _largest_text_container(soup: BeautifulSoup) -> Any:
    best = None
    best_len = 0
    for el in soup.find_all(["div", "section", "article", "td"]):
        if not el or el.name is None:
            continue
        # 너무 깊은 컨테이너만 보지 않도록 직접 텍스트 길이 기준
        txt = el.get_text(" ", strip=True)
        if 200 < len(txt) < 6000 and len(txt) > best_len:
            best, best_len = el, len(txt)
    return best


def clean_body_text(node: Any) -> str:
    """BeautifulSoup 노드 → 사람이 읽기 좋은 plain text."""
    if node is None:
        return ""
    # 스크립트/스타일 제거
    for tag in node.find_all(_EXCLUDE_TAGS):
        tag.decompose()

    # <br>, <p>, <li>, <tr> 를 줄바꿈으로 변환
    for br in node.find_all("br"):
        br.replace_with("\n")
    for tag_name in ("p", "div", "li", "tr"):
        for el in node.find_all(tag_name):
            el.append("\n")

    raw = node.get_text("", strip=False)
    return _normalize_text(raw)


def _normalize_text(raw: str) -> str:
    if not raw:
        return ""
    # 윈도우 개행 통일
    raw = raw.replace("\r\n", "\n").replace("\r", "\n")
    # 비가시 문자/HTML 엔티티 잔재 정리
    raw = raw.replace("\u00a0", " ").replace("\u200b", "").replace("\ufeff", "")
    # 줄별 정리 + 노이즈 라인 제거
    out_lines: list[str] = []
    for line in raw.split("\n"):
        s = re.sub(r"[ \t]+", " ", line).strip()
        if not s:
            out_lines.append("")
            continue
        if any(p.match(s) for p in _NOISE_LINE_PATTERNS):
            continue
        out_lines.append(s)
    # 연속 공백 줄 1개로 압축
    compact: list[str] = []
    blank = False
    for line in out_lines:
        if line == "":
            if not blank and compact:
                compact.append("")
            blank = True
        else:
            compact.append(line)
            blank = False
    return "\n".join(compact).strip()


# ────────────────────────────────────────────────────────────────────
#  요약
# ────────────────────────────────────────────────────────────────────

# 한국어 문장 종결 + 영문 문장 종결 + 줄바꿈
_SENT_SPLIT = re.compile(r"(?<=[.!?。…])\s+|\n+")


def heuristic_summary(body: str, *, max_chars: int = 220) -> str:
    """첫 의미 문장들을 합쳐 max_chars 이내로 자른 요약."""
    if not body:
        return ""
    text = body.strip()
    if len(text) <= max_chars:
        return text

    sentences = [s.strip() for s in _SENT_SPLIT.split(text) if s.strip()]
    if not sentences:
        return text[:max_chars].rstrip() + "…"

    out = ""
    for s in sentences:
        if not out:
            out = s
        else:
            candidate = f"{out} {s}"
            if len(candidate) > max_chars:
                break
            out = candidate
        if len(out) >= max_chars * 0.7:
            break

    if len(out) > max_chars:
        out = out[:max_chars].rstrip() + "…"
    return out.strip()


def lmstudio_summarize(
    *,
    base_url: str,
    model: str,
    title: str,
    body: str,
    timeout: float = 120.0,
) -> tuple[str | None, str]:
    """LM Studio (OpenAI 호환) 로 한국어 2~3줄 요약 생성.

    Returns:
        (summary, fail_reason) — 성공 시 ``(text, "")``.
        호출 자체를 건너뛴 경우(URL 없음·본문 빈 값)는 ``(None, "")``.
        HTTP 요청 이후 실패 시 ``fail_reason`` 에 짧은 태그
        (``timeout``, ``http_404``, ``json_decode`` 등)가 들어가 재시도 목록에 넣기 좋음.

    디버그: ``LMSTUDIO_DEBUG=1`` 이면 stderr에 요청/응답 스니펫과 예외를 출력합니다.
    """
    url = (base_url or os.environ.get("LMSTUDIO_BASE_URL") or "").strip().rstrip("/")
    if not url:
        _lm_log("skip: base_url 비어 있음")
        return None, ""
    if not body or not body.strip():
        _lm_log("skip: body 비어 있음")
        return None, ""

    chat_url = f"{url}/v1/chat/completions"

    # 본문 너무 길면 토큰 절약 위해 6000자에서 자름
    body_for_prompt = body[:6000]
    user = (
        f"제목: {title}\n"
        f"본문:\n{body_for_prompt}\n\n"
        "위 공지를 학생이 빠르게 핵심을 파악할 수 있도록 한국어로 2~3문장으로 요약하세요. "
        "신청 마감, 대상, 신청 방법, 참가 방법 등 학생에게 중요한 정보를 우선적으로 포함하세요. "
        '출력은 JSON 한 줄만: {"summary":"..."}\n'
        "설명, 마크다운 코드펜스, 다른 키, 줄바꿈 모두 금지."
    )
    _lm_log(f"POST {chat_url} model={model!r} title_len={len(title)} body_prompt_len={len(body_for_prompt)}")

    res: requests.Response | None = None
    content = ""
    try:
        res = requests.post(
            chat_url,
            json={
                "model": model,
                "temperature": 0.2,
                "messages": [
                    {
                        "role": "system",
                        "content": (
                            "너는 대학 공지 요약기다. 한국어 격식체 ~합니다 로 끝내고 "
                            "허위 정보를 만들지 않으며 JSON만 출력한다."
                        ),
                    },
                    {"role": "user", "content": user},
                ],
            },
            timeout=timeout,
        )
        _lm_log(f"HTTP status={res.status_code}")
        if res.status_code >= 400:
            _lm_log(f"응답 본문 스니펫: {res.text[:1500]!r}")
            return None, f"http_{res.status_code}"

        res.raise_for_status()
        data = res.json()
        if _lmstudio_debug_enabled():
            err_obj = data.get("error")
            if err_obj:
                _lm_log(f"API error 필드: {err_obj!r}")
            choices = data.get("choices")
            if not choices:
                _lm_log(f"choices 없음 data_keys={list(data.keys())} raw_snip={str(data)[:800]!r}")

        content = (
            data.get("choices", [{}])[0]
            .get("message", {})
            .get("content", "")
            .strip()
        )
        _lm_log(f"assistant content_len={len(content)} snip={content[:400]!r}")

        if content.startswith("```"):
            content = re.sub(r"^```[a-zA-Z]*\n?", "", content)
            content = re.sub(r"\n?```$", "", content).strip()
            _lm_log(f"코드펜스 제거 후 len={len(content)} snip={content[:400]!r}")

        parsed = json.loads(content)
        summary = parsed.get("summary")
        if not isinstance(summary, str):
            _lm_log(f"summary 타입 오류: {type(summary)!r} parsed_keys={list(parsed.keys()) if isinstance(parsed, dict) else 'n/a'}")
            return None, "bad_summary_type"
        summary = summary.strip()
        if not summary:
            _lm_log("summary 빈 문자열")
            return None, "empty_summary"
        _lm_log(f"성공 summary_len={len(summary)}")
        return summary[:600], ""

    except requests.Timeout as e:
        _lm_log(f"Timeout: {e!r} (timeout={timeout}s) — 서버가 응답하지 않거나 모델 로딩 중일 수 있음")
        return None, "timeout"
    except requests.RequestException as e:
        _lm_log(f"RequestException: {e!r}")
        if res is not None and getattr(res, "text", None):
            _lm_log(f"응답 스니펫: {res.text[:1500]!r}")
        return None, "request_error"
    except json.JSONDecodeError as e:
        _lm_log(f"JSONDecodeError: {e!r}")
        if content.strip():
            _lm_log(f"assistant 출력 JSON 파싱 실패 snip: {content[:1200]!r}")
        elif res is not None:
            _lm_log(f"HTTP 응답 JSON 파싱 실패 snip: {res.text[:1500]!r}")
        return None, "json_decode"
    except (KeyError, IndexError, TypeError) as e:
        _lm_log(f"응답 구조 오류: {type(e).__name__}: {e}")
        if res is not None:
            try:
                _lm_log(f"raw json snip: {str(res.json())[:1200]!r}")
            except Exception:
                _lm_log(f"raw text snip: {res.text[:1200]!r}")
        return None, "response_shape"
    except Exception as e:
        _lm_log(f"기타 예외: {type(e).__name__}: {e}\n{traceback.format_exc()}")
        return None, "unknown"


# ────────────────────────────────────────────────────────────────────
#  edit-in-place helper
# ────────────────────────────────────────────────────────────────────

def enrich_with_body_and_summary(
    post: dict[str, Any],
    *,
    session: requests.Session | None = None,
    fetch_timeout: float = 15.0,
    use_lmstudio: bool = False,
    lm_base: str = "",
    lm_model: str = "",
    lm_timeout: float = 120.0,
) -> None:
    """post dict 에 body, summary, body_fetched_at 등을 채워넣음.

    크롤러/백필 양쪽에서 같이 쓸 수 있도록 in-place 패턴.
    """
    url = str(post.get("url") or "")
    body, err = fetch_mjc_view_body(url, timeout=fetch_timeout, session=session)
    now_iso = datetime.now().isoformat()

    post["body"] = body
    post["body_fetched_at"] = now_iso
    if err:
        post["body_fetch_error"] = err
    elif "body_fetch_error" in post:
        # 이전에 실패한 적이 있는 문서가 이번에 성공하면 명시적으로 비움
        post["body_fetch_error"] = None

    summary: str = ""
    summary_version = SUMMARY_HEURISTIC_VERSION
    post.pop("_lm_summarize_fail_reason", None)
    if body:
        if use_lmstudio and lm_base:
            lm, lm_fail = lmstudio_summarize(
                base_url=lm_base,
                model=lm_model,
                title=str(post.get("title") or ""),
                body=body,
                timeout=lm_timeout,
            )
            if lm:
                summary = lm
                summary_version = SUMMARY_LMSTUDIO_VERSION
            else:
                if lm_fail:
                    post["_lm_summarize_fail_reason"] = lm_fail
                if _lmstudio_debug_enabled():
                    tid = str(post.get("title") or "")[:80]
                    r = post.get("_lm_summarize_fail_reason") or "skip"
                    _lm_log(
                        f"→ 휴리스틱 폴백 (LM 결과 없음) reason={r!r} title_snip={tid!r}"
                    )
        if not summary:
            summary = heuristic_summary(body)
    post["summary"] = summary
    post["summary_version"] = summary_version
    post["summary_generated_at"] = now_iso
    # 신고/플래그 카운터 기본값 (Firestore 기존 문서에 없으면 신설)
    post.setdefault("reports_count", 0)
    post.setdefault("needs_resummary", False)
