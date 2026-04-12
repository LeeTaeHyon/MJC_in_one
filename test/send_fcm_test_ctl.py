#!/usr/bin/env python3
"""
CTL 출처 FCM 테스트.

  python send_fcm_test_ctl.py
  python send_fcm_test_ctl.py --kind program --keyword 프로그램
  python send_fcm_test_ctl.py --title "[CTL 공지사항] 새 글 등록" --body "테스트"
"""
from __future__ import annotations

import argparse

from fcm_test_util import send_data_to_topic


def main() -> None:
    p = argparse.ArgumentParser(description="FCM 테스트 (source=ctl)")
    p.add_argument(
        "--kind",
        choices=("notice", "program"),
        default="notice",
        help="notice=CTL 공지사항, program=CTL 프로그램 (크롤러와 동일 구분)",
    )
    p.add_argument(
        "--body",
        default="[FCM 테스트] CTL 소스",
        help="본문 (키워드 알림 시 매칭 대상)",
    )
    p.add_argument(
        "--title",
        default=None,
        help="미지정 시 kind에 맞는 기본 제목",
    )
    p.add_argument(
        "--url",
        default="https://ctl.mjc.ac.kr",
        help="data url",
    )
    p.add_argument(
        "--keyword",
        default=None,
        help="body 뒤에 붙여 키워드 알림 테스트",
    )
    p.add_argument("--topic", default="all_notices", help="FCM 토픽")
    args = p.parse_args()

    board_name = "CTL 프로그램" if args.kind == "program" else "CTL 공지사항"
    body = args.body
    if args.keyword:
        body = f"{body} {args.keyword}".strip()

    title = args.title or f"[{board_name}] 새 글 등록"
    data = {
        "title": title,
        "body": body,
        "url": args.url,
        "board": board_name,
        "source": "ctl",
    }
    mid = send_data_to_topic(data, topic=args.topic)
    print(f"[FCM 발송 성공] message_id={mid}")
    print(f"  title={title!r}\n  body={body!r}")


if __name__ == "__main__":
    main()
