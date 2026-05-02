"""
공지 ai_tags(v1) — 룰 기반 분류.

태그(7): 학사/수업, 장학/등록금, 모집/신청, 행사/대회/특강, 취업/진로/창업,
        정책/지원사업/대외홍보, 기타
"""

from __future__ import annotations

import json
import os
import re
from typing import Any

AI_TAG_VERSION = "v1"

ALLOWED_TAGS: tuple[str, ...] = (
    "학사/수업",
    "장학/등록금",
    "모집/신청",
    "행사/대회/특강",
    "취업/진로/창업",
    "정책/지원사업/대외홍보",
    "기타",
)

# (tag, regex) — 점수 합산 후 상위 최대 2개(동점 시 정의 순서).
_SCORE_PATTERNS: tuple[tuple[str, re.Pattern[str]], ...] = (
    (
        "장학/등록금",
        re.compile(
            r"장학|국가장학|근로장학|학자금|대출|주거안정|기숙사|"
            r"장학생|장학금|외부장학|등록금|장학규정|푸른등대",
            re.I,
        ),
    ),
    (
        "학사/수업",
        re.compile(
            r"학점|강좌|강의|중간고사|기말|시험일정|시험\s*실시|강의평가|원격강좌|"
            r"K-MOOC|교양|본과정|개강|학위|입학식|학사운영|복학|휴학|제적|미등록|"
            r"Smart\s*Care|진단검사|학점인정|e-러닝|폐강|교과목|학기|수업|"
            r"학사일정|일정",
            re.I,
        ),
    ),
    (
        "모집/신청",
        re.compile(
            r"모집|선발|신청|참가자|멘토|기자단|운영진|공고|"
            r"참여\s*안내|지원\s*받|입사\s*신청",
            re.I,
        ),
    ),
    (
        "행사/대회/특강",
        re.compile(
            r"대회|경진|공모전|영화제|특강|워크숍|바자회|개최|캠페인|숏폼|"
            r"버스킹|나눔바자회|행사\s*안내",
            re.I,
        ),
    ),
    (
        "취업/진로/창업",
        re.compile(
            r"취업|진로|코칭|인턴|채용|창업|기업가|"
            r"글로벌\s*진로|창업신기술|창업유망",
            re.I,
        ),
    ),
    (
        "정책/지원사업/대외홍보",
        re.compile(
            r"지원사업|협조\s*요청|해외연수|배낭|월세|이사비|부동산|"
            r"데이터안심|구청|국토교통부|\[홍보\]|청소년센터|교육진흥원|"
            r"자치활동|SNS|서대문|마포|문래|유료\s*폰트|폰트\s*배포|"
            r"가이드|연수\s*장학생",
            re.I,
        ),
    ),
)


def _combined_text(
    board_id: str,
    category: str,
    title: str,
    extra: str = "",
) -> str:
    parts = [board_id, category, title, extra]
    return " ".join(p for p in parts if p).strip()


def classify_ai_tags(
    *,
    board_id: str = "",
    category: str = "",
    title: str = "",
    extra: str = "",
) -> tuple[list[str], str]:
    """룰 기반으로 1~2개 태그 + 버전 반환."""
    bid = (board_id or "").strip()
    cat = (category or "").strip()
    ttl = (title or "").strip()

    if bid == "main_academic" or cat == "학사공지":
        return (["학사/수업"], AI_TAG_VERSION)
    if bid == "main_scholarship" or cat == "장학공지":
        return (["장학/등록금"], AI_TAG_VERSION)
    if bid == "main_schedule" or cat == "학사일정":
        return (["학사/수업"], AI_TAG_VERSION)

    text = _combined_text(bid, cat, ttl, extra)
    if not text:
        return (["기타"], AI_TAG_VERSION)

    scores: dict[str, int] = {}
    for tag, pat in _SCORE_PATTERNS:
        if pat.search(text):
            scores[tag] = scores.get(tag, 0) + 1

    if not scores:
        return (["기타"], AI_TAG_VERSION)

    # 점수 내림차순, 동점이면 ALLOWED_TAGS 순서
    order = {t: i for i, t in enumerate(ALLOWED_TAGS)}
    ranked = sorted(scores.keys(), key=lambda t: (-scores[t], order.get(t, 99)))
    out = ranked[:2]
    return (out, AI_TAG_VERSION)


def enrich_post_dict(post: dict[str, Any], board_id: str) -> None:
    """post 딕셔너리에 ai_tags, ai_tag_version을 제자리로 넣습니다."""
    title = str(post.get("title") or "")
    category = str(post.get("category") or "")
    extra_bits: list[str] = []
    for key in ("branch", "status", "op_period", "tags"):
        v = post.get(key)
        if isinstance(v, list):
            extra_bits.extend(str(x) for x in v)
        elif v:
            extra_bits.append(str(v))
    extra = " ".join(extra_bits)
    tags, ver = classify_ai_tags(
        board_id=board_id,
        category=category,
        title=title,
        extra=extra,
    )
    post["ai_tags"] = tags
    post["ai_tag_version"] = ver


def lmstudio_refine_tags(
    *,
    base_url: str,
    model: str,
    board_id: str,
    category: str,
    title: str,
    extra: str = "",
    timeout: float = 120.0,
) -> list[str] | None:
    """
    LM Studio(OpenAI 호환)로 태그만 JSON으로 받습니다.
    환경변수 LMSTUDIO_BASE_URL 이 비어 있으면 None.
    실패/파싱 실패 시 None.
    """
    url = (base_url or os.environ.get("LMSTUDIO_BASE_URL") or "").strip().rstrip("/")
    if not url:
        return None
    chat_url = f"{url}/v1/chat/completions"
    allowed = ", ".join(f'"{t}"' for t in ALLOWED_TAGS if t != "기타")
    user = (
        f"board_id={board_id}\n"
        f"category={category}\n"
        f"title={title}\n"
        f"extra={extra}\n\n"
        f'반드시 아래 TAGS 중에서만 1~2개 고르세요: [{allowed}, "기타"]\n'
        '출력은 JSON 한 줄만: {"ai_tags":["태그1","태그2"],"ai_tag_version":"v1"}\n'
        "설명, 마크다운, 다른 키 금지."
    )
    try:
        import requests
    except ImportError:
        return None
    try:
        res = requests.post(
            chat_url,
            json={
                "model": model,
                "temperature": 0.1,
                "messages": [
                    {
                        "role": "system",
                        "content": "너는 대학 공지 분류기다. 지정된 태그만 사용하고 JSON만 출력한다.",
                    },
                    {"role": "user", "content": user},
                ],
            },
            timeout=timeout,
        )
        res.raise_for_status()
        data = res.json()
        content = (
            data.get("choices", [{}])[0]
            .get("message", {})
            .get("content", "")
            .strip()
        )
        # 코드펜스 제거
        if content.startswith("```"):
            content = re.sub(r"^```[a-zA-Z]*\n?", "", content)
            content = re.sub(r"\n?```$", "", content).strip()
        parsed = json.loads(content)
        raw_tags = parsed.get("ai_tags")
        if not isinstance(raw_tags, list):
            return None
        out: list[str] = []
        allowed_set = set(ALLOWED_TAGS)
        for x in raw_tags:
            s = str(x).strip()
            if s in allowed_set and s not in out:
                out.append(s)
        if not out:
            out = ["기타"]
        return out[:2]
    except Exception:
        return None
