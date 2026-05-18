"""
공지 본문 수집 + 요약 (휴리스틱 / Gemini Flash).

MJC `view.do` 페이지의 본문 컨테이너는 `#divMemo.memo` 입니다.
실측은 test 디렉터리에서 임시 inspection 스크립트로 확정했습니다.

Gemini 요약 디버그 (stderr):
  PowerShell: `$env:GEMINI_DEBUG = "1"`
  CMD: `set GEMINI_DEBUG=1`

사용:
  body, summary, info = fetch_and_summarize(view_url)

`info` 는 진단용 메타입니다(error, byte_count 등).
"""

from __future__ import annotations

import json
import os
import re
import sys
import time
import traceback
from datetime import datetime
from typing import Any
from urllib.parse import urljoin, urlparse

import requests
from bs4 import BeautifulSoup, Tag

SUMMARY_HEURISTIC_VERSION = "heuristic-v1"
# 구 백필 문서 호환용. 신규 요약은 [summary_version_for_model] 로 모델 ID 반영.
SUMMARY_GEMINI_VERSION = "gemini-flash-v1"


def summary_version_for_model(model_id: str) -> str:
    """Firestore ``summary_version`` — 실제 API 모델 ID 기반 (예: ``gemma-4-31b-it-v1``)."""
    mid = re.sub(r"[^a-z0-9._-]+", "", (model_id or "").strip().lower())
    if not mid:
        return SUMMARY_GEMINI_VERSION
    return f"{mid}-v1"
# 이전 LM Studio 백필 문서 호환용 (신규 요약에는 사용하지 않음)
SUMMARY_LMSTUDIO_VERSION = "lmstudio-v1"
SUMMARY_MANUAL_VERSION = "manual"

GEMINI_API_BASE = "https://generativelanguage.googleapis.com/v1beta"
DEFAULT_GEMINI_MODEL = "gemini-2.0-flash"


def _gemini_debug_enabled() -> bool:
    return os.environ.get("GEMINI_DEBUG", "").strip().lower() in (
        "1",
        "true",
        "yes",
        "on",
    )


def _gemini_log(msg: str) -> None:
    """Gemini 요약 진단 로그 (환경변수 켰을 때만 stderr)."""
    if _gemini_debug_enabled():
        print(f"[notice_body/gemini] {msg}", file=sys.stderr)


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

# body_html sanitize 시 제거할 태그
_HTML_STRIP_TAGS: tuple[str, ...] = (
    "script",
    "style",
    "noscript",
    "iframe",
    "object",
    "embed",
)

_BODY_HTML_MAX_CHARS = 200_000

# 레거시 문서·UI 호환용 (신규 fetch 에는 body 에 넣지 않음)
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

def body_text_for_ai(body: str) -> str:
    """요약·AI 입력용 plain text — placeholder·HTML 안내 문구 제외."""
    s = (body or "").strip()
    if not s or s == _BODY_IMAGE_ONLY_PLACEHOLDER:
        return ""
    return s


def _page_base_url(view_url: str) -> str:
    parsed = urlparse(view_url)
    if not parsed.scheme or not parsed.netloc:
        return "https://www.mjc.ac.kr"
    return f"{parsed.scheme}://{parsed.netloc}"


def _resolve_resource_url(base_url: str, raw: str) -> str:
    s = (raw or "").strip()
    if not s or s.startswith("#"):
        return s
    if s.lower().startswith(("javascript:", "data:", "vbscript:")):
        return ""
    if s.startswith("//"):
        scheme = urlparse(base_url).scheme or "https"
        return f"{scheme}:{s}"
    return urljoin(base_url, s)


def _clone_body_node(node: Tag) -> Tag | None:
    cloned = BeautifulSoup(str(node), "html.parser")
    return cloned.find()


def extract_body_html(node: Any, *, base_url: str) -> str:
    """본문 컨테이너 inner HTML — sanitize 후 앱 WebView 렌더용."""
    work = _clone_body_node(node) if isinstance(node, Tag) else None
    if work is None:
        return ""

    for tag_name in _HTML_STRIP_TAGS:
        for el in work.find_all(tag_name):
            el.decompose()

    for el in work.find_all(True):
        if not isinstance(el, Tag):
            continue
        for attr in list(el.attrs.keys()):
            low = attr.lower()
            if low.startswith("on"):
                del el.attrs[attr]
                continue
            if low not in ("href", "src", "srcset"):
                continue
            val = el.attrs.get(attr)
            if isinstance(val, list):
                parts = [
                    _resolve_resource_url(base_url, p)
                    for p in val
                    if isinstance(p, str) and p.strip()
                ]
                parts = [p for p in parts if p]
                if not parts:
                    del el.attrs[attr]
                elif low == "srcset":
                    el.attrs[attr] = ", ".join(
                        f"{p} 1x" if " " not in p else p for p in parts
                    )
                else:
                    el.attrs[attr] = parts[0]
            elif isinstance(val, str):
                resolved = _resolve_resource_url(base_url, val)
                if not resolved:
                    del el.attrs[attr]
                else:
                    el.attrs[attr] = resolved

    html = work.decode_contents().strip()
    if len(html) > _BODY_HTML_MAX_CHARS:
        html = html[:_BODY_HTML_MAX_CHARS]
    return html


def fetch_mjc_view_body(
    view_url: str,
    *,
    timeout: float = 15.0,
    session: requests.Session | None = None,
) -> tuple[str, str, str, str | None]:
    """MJC view.do 본문 plain text + sanitize HTML 추출.

    Returns:
        (body_text, body_html, view_title, error_message)  — error 가 None 이면 성공.
    """
    if not view_url:
        return "", "", "", "empty_url"
    sess = session or requests
    try:
        res = sess.get(view_url, headers=_DEFAULT_HEADERS, timeout=timeout)
    except requests.RequestException as exc:  # 네트워크/타임아웃
        return "", "", "", f"http_error:{type(exc).__name__}"
    if res.status_code != 200:
        return "", "", "", f"status:{res.status_code}"

    # MJC 페이지는 charset 메타 기반 자동 추론이 잘 안 될 때가 있어 명시적으로 본다.
    res.encoding = res.apparent_encoding or "utf-8"
    soup = BeautifulSoup(res.text, "html.parser")

    view_title = _extract_mjc_view_title(soup)

    node = None
    for sel in _BODY_SELECTORS:
        node = soup.select_one(sel)
        if node is not None:
            break

    if node is None:
        # fallback: 전체 본문에서 가장 큰 텍스트 컨테이너
        node = _largest_text_container(soup)

    if node is None:
        return "", "", view_title, "no_body_node"

    base_url = _page_base_url(view_url)
    body_html = extract_body_html(node, base_url=base_url)

    text_node = _clone_body_node(node)
    text = clean_body_text(text_node) if text_node is not None else ""

    # 이미지 전용: AI 요약용 body 는 비우고 body_html 만 유지
    if body_html and not text.strip() and node.find("img"):
        return "", body_html, view_title, None

    return text, body_html, view_title, None


def heuristic_summary_from_title(title: str, *, max_chars: int = 120) -> str:
    """본문 없을 때 제목만으로 짧은 카드용 요약."""
    t = (title or "").strip()
    if not t:
        return ""
    if len(t) <= max_chars:
        return t
    return t[: max_chars - 1].rstrip() + "…"


def _extract_mjc_view_title(soup: BeautifulSoup) -> str:
    """MJC view.do HTML에서 원본 제목 추출 (가능한 경우)."""
    if soup is None:
        return ""

    # 1) OG title (가장 신뢰도 높음)
    meta = soup.select_one('meta[property="og:title"]')
    if meta is not None:
        content = (meta.get("content") or "").strip()
        if content:
            return _normalize_view_title(content)

    # 2) 일반 <title>
    if soup.title and soup.title.string:
        t = soup.title.string.strip()
        if t:
            return _normalize_view_title(t)

    # 3) 화면 내 헤더 텍스트 후보들
    for sel in (
        ".view_tit",
        ".viewTit",
        ".bbs_view .tit",
        ".bbs_view .title",
        ".board_view .tit",
        ".board_view .title",
        "h3",
        "h4",
    ):
        node = soup.select_one(sel)
        if node is None:
            continue
        t = node.get_text(" ", strip=True)
        if t and len(t) >= 6:
            return _normalize_view_title(t)

    return ""


def _normalize_view_title(raw: str) -> str:
    """사이트 suffix 제거 등 최소 정규화."""
    s = (raw or "").strip().replace("\u00a0", " ")
    if not s:
        return ""

    # og:title 등에 breadcrumb 가 포함되는 경우가 있어 마지막 토큰만 남김
    # 예: "명지전문대학 > 공지사항: [혁신] ... 안내" → "[혁신] ... 안내"
    if " > " in s:
        s = s.split(" > ")[-1].strip()
    if ":" in s:
        # "공지사항: 제목" 형태면 제목만
        left, right = s.split(":", 1)
        if left.strip() and right.strip():
            s = right.strip()

    # <title>에서 자주 붙는 suffix 제거
    for sep in (" | ", " - ", " :: "):
        if sep in s:
            # 너무 공격적으로 자르지 않도록, 우측 토큰이 사이트명일 때만 제거
            left, right = s.rsplit(sep, 1)
            r = right.strip()
            if any(k in r for k in ("명지", "MJC", "mjc.ac.kr")) and left.strip():
                s = left.strip()
            break
    return s


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


def _summary_prompt(title: str, body: str) -> tuple[str, str]:
    """(system_instruction, user_text) for Gemini / legacy callers."""
    body_for_prompt = body[:6000]
    system = (
        "너는 대학 공지 요약기다. 한국어 격식체 ~합니다 로 끝내고 "
        "허위 정보를 만들지 않으며 JSON만 출력한다."
    )
    user = (
        f"제목: {title}\n"
        f"본문:\n{body_for_prompt}\n\n"
        "위 공지를 학생이 빠르게 핵심을 파악할 수 있도록 한국어로 2~3문장으로 요약하세요. "
        "신청 마감, 대상, 신청 방법, 참가 방법 등 학생에게 중요한 정보를 우선적으로 포함하세요. "
        '출력은 JSON 한 줄만: {"summary":"..."}\n'
        "설명, 마크다운 코드펜스, 다른 키, 줄바꿈 모두 금지."
    )
    return system, user


def _gemini_max_retries() -> int:
    raw = os.environ.get("GEMINI_MAX_RETRIES", "6").strip()
    try:
        return max(0, int(raw))
    except ValueError:
        return 6


def _retry_after_seconds(res: requests.Response, attempt: int) -> float:
    """429/503 시 대기 초. Retry-After 헤더 우선, 없으면 지수 백오프."""
    ra = (res.headers.get("Retry-After") or "").strip()
    if ra:
        try:
            return max(1.0, float(ra))
        except ValueError:
            pass
    return min(120.0, 2.0 * (2**attempt))


def _summary_from_parsed(parsed: Any) -> str | None:
    if isinstance(parsed, dict):
        summary = parsed.get("summary")
        if isinstance(summary, str) and summary.strip():
            return summary.strip()[:600]
    return None


def _parse_summary_json(content: str) -> tuple[str | None, str]:
    """모델 출력에서 summary 필드 추출 (Gemma 등 비준수 JSON 폴백 포함)."""
    text = content.strip()
    if not text:
        return None, "empty_content"
    if text.startswith("```"):
        text = re.sub(r"^```[a-zA-Z]*\n?", "", text)
        text = re.sub(r"\n?```$", "", text).strip()

    try:
        parsed = json.loads(text)
        summary = _summary_from_parsed(parsed)
        if summary:
            return summary, ""
    except json.JSONDecodeError:
        pass

    # {"summary":"..."} 가 앞뒤 설명과 섞인 경우
    obj_match = re.search(r"\{[\s\S]*\}", text)
    if obj_match:
        try:
            parsed = json.loads(obj_match.group(0))
            summary = _summary_from_parsed(parsed)
            if summary:
                return summary, ""
        except json.JSONDecodeError:
            pass

    field_match = re.search(
        r'"summary"\s*:\s*"((?:[^"\\]|\\.)*)"',
        text,
        flags=re.DOTALL,
    )
    if field_match:
        try:
            summary = json.loads(f'"{field_match.group(1)}"')
        except json.JSONDecodeError:
            summary = field_match.group(1)
        summary = str(summary).strip()
        if summary:
            return summary[:600], ""

    # JSON 대신 평문만 준 경우 (짧은 공지에서 Gemma가 자주 함)
    if "{" not in text and len(text) >= 8:
        _gemini_log(f"plain-text fallback len={len(text)} snip={text[:200]!r}")
        return text[:600], ""

    _gemini_log(f"json_decode 실패 snip={text[:500]!r}")
    return None, "json_decode"


def gemini_summarize(
    *,
    api_key: str,
    model: str,
    title: str,
    body: str,
    timeout: float = 120.0,
) -> tuple[str | None, str]:
    """Google Gemini Flash 로 한국어 2~3줄 요약 생성.

    Returns:
        (summary, fail_reason) — 성공 시 ``(text, "")``.
        API 키·본문이 비어 있으면 ``(None, "")``.
        HTTP 이후 실패 시 ``fail_reason`` (``timeout``, ``http_429``, ``json_decode`` 등).

    환경변수: ``GEMINI_API_KEY``, ``GEMINI_MODEL`` (기본 ``gemini-2.0-flash``).
    디버그: ``GEMINI_DEBUG=1``.
    """
    key = (api_key or os.environ.get("GEMINI_API_KEY") or "").strip()
    if not key:
        _gemini_log("skip: api_key 비어 있음")
        return None, ""
    if not body or not body.strip():
        _gemini_log("skip: body 비어 있음")
        return None, ""

    model_id = (
        (model or os.environ.get("GEMINI_MODEL") or DEFAULT_GEMINI_MODEL).strip()
    )
    generate_url = f"{GEMINI_API_BASE}/models/{model_id}:generateContent"
    system, user = _summary_prompt(title, body)
    _gemini_log(
        f"POST {generate_url} model={model_id!r} "
        f"title_len={len(title)} body_prompt_len={len(body[:6000])}"
    )

    res: requests.Response | None = None
    content = ""
    max_retries = _gemini_max_retries()
    try:
        payload = {
            "systemInstruction": {"parts": [{"text": system}]},
            "contents": [{"role": "user", "parts": [{"text": user}]}],
            "generationConfig": {
                "temperature": 0.2,
                "responseMimeType": "application/json",
                "responseSchema": {
                    "type": "object",
                    "properties": {
                        "summary": {"type": "string"},
                    },
                    "required": ["summary"],
                },
            },
        }
        data: dict[str, Any] | None = None
        for attempt in range(max_retries + 1):
            res = requests.post(
                generate_url,
                params={"key": key},
                json=payload,
                timeout=timeout,
            )
            _gemini_log(f"HTTP status={res.status_code} attempt={attempt + 1}")
            if res.status_code in (429, 503) and attempt < max_retries:
                wait_s = _retry_after_seconds(res, attempt)
                _gemini_log(
                    f"{res.status_code} rate limit/일시 오류 → {wait_s:.1f}s 대기 후 재시도 "
                    f"({attempt + 1}/{max_retries + 1}) snip={res.text[:300]!r}"
                )
                time.sleep(wait_s)
                continue
            if res.status_code >= 400:
                _gemini_log(f"응답 본문 스니펫: {res.text[:1500]!r}")
                return None, f"http_{res.status_code}"
            res.raise_for_status()
            data = res.json()
            break
        if data is None:
            return None, "http_429"
        if _gemini_debug_enabled():
            err_obj = data.get("error")
            if err_obj:
                _gemini_log(f"API error 필드: {err_obj!r}")
            if not data.get("candidates"):
                _gemini_log(
                    f"candidates 없음 keys={list(data.keys())} "
                    f"feedback={data.get('promptFeedback')!r} "
                    f"raw_snip={str(data)[:800]!r}"
                )

        candidates = data.get("candidates") or []
        if not candidates:
            return None, "no_candidates"

        finish = (candidates[0].get("finishReason") or "").strip()
        if finish and finish not in ("STOP", "MAX_TOKENS"):
            _gemini_log(f"finishReason={finish!r}")
            if finish in ("SAFETY", "RECITATION", "BLOCKLIST"):
                return None, f"blocked_{finish.lower()}"

        parts = (candidates[0].get("content") or {}).get("parts") or []
        content = "".join(
            p.get("text", "") for p in parts if isinstance(p, dict)
        ).strip()
        _gemini_log(f"model text_len={len(content)} snip={content[:400]!r}")

        summary, parse_err = _parse_summary_json(content)
        if summary:
            _gemini_log(f"성공 summary_len={len(summary)}")
            return summary, ""
        return None, parse_err or "parse_failed"

    except requests.Timeout as e:
        _gemini_log(f"Timeout: {e!r} (timeout={timeout}s)")
        return None, "timeout"
    except requests.RequestException as e:
        _gemini_log(f"RequestException: {e!r}")
        if res is not None and getattr(res, "text", None):
            _gemini_log(f"응답 스니펫: {res.text[:1500]!r}")
        return None, "request_error"
    except (KeyError, IndexError, TypeError) as e:
        _gemini_log(f"응답 구조 오류: {type(e).__name__}: {e}")
        if res is not None:
            try:
                _gemini_log(f"raw json snip: {str(res.json())[:1200]!r}")
            except Exception:
                _gemini_log(f"raw text snip: {res.text[:1200]!r}")
        return None, "response_shape"
    except Exception as e:
        _gemini_log(f"기타 예외: {type(e).__name__}: {e}\n{traceback.format_exc()}")
        return None, "unknown"


# ────────────────────────────────────────────────────────────────────
#  edit-in-place helper
# ────────────────────────────────────────────────────────────────────

def _maybe_fix_title_from_view(post: dict[str, Any], view_title: str) -> None:
    """리스트에서 잘린 제목이면 view.do 제목으로 교체."""
    list_title = str(post.get("title") or "").strip()
    if not view_title:
        return
    vt = view_title.strip()
    if list_title.endswith("...") or list_title.endswith("…"):
        if len(vt) > len(list_title) and not vt.endswith("...") and not vt.endswith("…"):
            post["title"] = vt


def _assign_summary_fields(
    post: dict[str, Any],
    *,
    use_gemini: bool = False,
    gemini_api_key: str = "",
    gemini_model: str = "",
    gemini_timeout: float = 120.0,
) -> None:
    """Firestore 에 이미 있는 body/body_html 기준으로 summary 필드만 갱신."""
    now_iso = datetime.now().isoformat()
    ai_body = body_text_for_ai(str(post.get("body") or ""))
    body_html = str(post.get("body_html") or "")

    summary: str = ""
    summary_version = SUMMARY_HEURISTIC_VERSION
    post.pop("_summarize_fail_reason", None)

    title_for_summary = str(post.get("title") or "")
    if ai_body:
        api_key = (gemini_api_key or os.environ.get("GEMINI_API_KEY") or "").strip()
        if use_gemini and api_key:
            model_id = (
                gemini_model
                or os.environ.get("GEMINI_MODEL")
                or DEFAULT_GEMINI_MODEL
            ).strip()
            gm, gm_fail = gemini_summarize(
                api_key=api_key,
                model=model_id,
                title=title_for_summary,
                body=ai_body,
                timeout=gemini_timeout,
            )
            if gm:
                summary = gm
                summary_version = summary_version_for_model(model_id)
            else:
                if gm_fail:
                    post["_summarize_fail_reason"] = gm_fail
                if _gemini_debug_enabled():
                    tid = title_for_summary[:80]
                    r = post.get("_summarize_fail_reason") or "skip"
                    _gemini_log(
                        f"→ 휴리스틱 폴백 (Gemini 결과 없음) reason={r!r} title_snip={tid!r}"
                    )
        if not summary:
            summary = heuristic_summary(ai_body)
    elif body_html.strip() and title_for_summary.strip():
        summary = heuristic_summary_from_title(title_for_summary)
    post["summary"] = summary
    post["summary_version"] = summary_version
    post["summary_generated_at"] = now_iso
    post.setdefault("reports_count", 0)
    post.setdefault("needs_resummary", False)


def enrich_body_only(
    post: dict[str, Any],
    *,
    session: requests.Session | None = None,
    fetch_timeout: float = 15.0,
) -> None:
    """view.do 에서 body/body_html 만 fetch. summary 필드는 건드리지 않음."""
    url = str(post.get("url") or "")
    body_text, body_html, view_title, err = fetch_mjc_view_body(
        url,
        timeout=fetch_timeout,
        session=session,
    )
    now_iso = datetime.now().isoformat()

    post["body"] = body_text
    post["body_html"] = body_html
    post["body_fetched_at"] = now_iso
    if err:
        post["body_fetch_error"] = err
    elif "body_fetch_error" in post:
        post["body_fetch_error"] = None

    _maybe_fix_title_from_view(post, view_title)
    post.setdefault("reports_count", 0)
    post.setdefault("needs_resummary", False)


def enrich_summary_only(
    post: dict[str, Any],
    *,
    use_gemini: bool = False,
    gemini_api_key: str = "",
    gemini_model: str = "",
    gemini_timeout: float = 120.0,
) -> None:
    """HTTP fetch 없이 기존 body/body_html 로 summary 만 재생성."""
    _assign_summary_fields(
        post,
        use_gemini=use_gemini,
        gemini_api_key=gemini_api_key,
        gemini_model=gemini_model,
        gemini_timeout=gemini_timeout,
    )


def enrich_with_body_and_summary(
    post: dict[str, Any],
    *,
    session: requests.Session | None = None,
    fetch_timeout: float = 15.0,
    use_gemini: bool = False,
    gemini_api_key: str = "",
    gemini_model: str = "",
    gemini_timeout: float = 120.0,
) -> None:
    """post dict 에 body, summary, body_fetched_at 등을 채워넣음.

    크롤러/백필 양쪽에서 같이 쓸 수 있도록 in-place 패턴.
    """
    url = str(post.get("url") or "")
    body_text, body_html, view_title, err = fetch_mjc_view_body(
        url,
        timeout=fetch_timeout,
        session=session,
    )
    now_iso = datetime.now().isoformat()

    post["body"] = body_text
    post["body_html"] = body_html
    post["body_fetched_at"] = now_iso
    if err:
        post["body_fetch_error"] = err
    elif "body_fetch_error" in post:
        post["body_fetch_error"] = None

    _maybe_fix_title_from_view(post, view_title)
    _assign_summary_fields(
        post,
        use_gemini=use_gemini,
        gemini_api_key=gemini_api_key,
        gemini_model=gemini_model,
        gemini_timeout=gemini_timeout,
    )
