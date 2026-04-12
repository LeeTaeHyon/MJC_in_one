#!/usr/bin/env python3
"""
MPU 핵심역량 출처 FCM 테스트.

  python send_fcm_test_mpu.py
  python send_fcm_test_mpu.py --keyword 역량
  python send_fcm_test_mpu.py --body "맞춤 제목 줄" --title "[MPU 핵심역량] 새 프로그램 등록"
"""
from __future__ import annotations

import argparse

from fcm_test_util import send_data_to_topic


def main() -> None:
    p = argparse.ArgumentParser(description="FCM 테스트 (source=mpu)")
    p.add_argument(
        "--body",
        default="[FCM 테스트] MPU 핵심역량 소스",
        help="본문 (키워드 알림 시 매칭 대상)",
    )
    p.add_argument(
        "--title",
        default="[MPU 핵심역량] 새 프로그램 등록",
        help="알림 제목",
    )
    p.add_argument(
        "--url",
        default="https://mpu.mjc.ac.kr",
        help="data url",
    )
    p.add_argument(
        "--keyword",
        default=None,
        help="body 뒤에 붙여 키워드 알림 테스트",
    )
    p.add_argument("--topic", default="all_notices", help="FCM 토픽")
    args = p.parse_args()

    body = args.body
    if args.keyword:
        body = f"{body} {args.keyword}".strip()

    data = {
        "title": args.title,
        "body": body,
        "url": args.url,
        "board": "MPU 프로그램",
        "source": "mpu",
    }
    mid = send_data_to_topic(data, topic=args.topic)
    print(f"[FCM 발송 성공] message_id={mid}")
    print(f"  title={args.title!r}\n  body={body!r}")


if __name__ == "__main__":
    main()
