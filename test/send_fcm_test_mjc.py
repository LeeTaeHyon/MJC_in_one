#!/usr/bin/env python3
"""
본교(mjc) 출처 FCM 테스트.
앱은 전체 알림 모드이거나, 키워드 모드에서 title/body에 등록한 키워드가 포함될 때만 표시합니다.

  python send_fcm_test_mjc.py
  python send_fcm_test_mjc.py --keyword 장학
  python send_fcm_test_mjc.py --body "원하는 본문" --category 학사공지
"""
from __future__ import annotations

import argparse

from fcm_test_util import send_data_to_topic


def main() -> None:
    p = argparse.ArgumentParser(description="FCM 테스트 (source=mjc)")
    p.add_argument(
        "--category",
        default="공지",
        help="board 및 기본 제목에 쓰는 게시판명 (크롤러 category와 동일 역할)",
    )
    p.add_argument(
        "--body",
        default="[FCM 테스트] 메인 홈페이지(mjc) 소스",
        help="본문 (키워드 알림 시 이 문자열에 키워드가 있어야 함)",
    )
    p.add_argument(
        "--title",
        default=None,
        help="지정하면 제목 고정. 미지정 시 [{category}] 새 글 등록",
    )
    p.add_argument("--url", default="https://www.mjc.ac.kr", help="data url")
    p.add_argument(
        "--keyword",
        default=None,
        help="지정 시 body 뒤에 공백과 함께 붙임 (앱에 등록한 키워드와 맞춰 테스트)",
    )
    p.add_argument("--topic", default="all_notices", help="FCM 토픽")
    args = p.parse_args()

    body = args.body
    if args.keyword:
        body = f"{body} {args.keyword}".strip()

    title = args.title or f"[{args.category}] 새 글 등록"
    data = {
        "title": title,
        "body": body,
        "url": args.url,
        "board": args.category,
        "source": "mjc",
    }
    mid = send_data_to_topic(data, topic=args.topic)
    print(f"[FCM 발송 성공] message_id={mid}")
    print(f"  title={title!r}\n  body={body!r}")


if __name__ == "__main__":
    main()
