# 공통: 서비스 계정으로 FCM data 메시지를 토픽으로 발송합니다.
# 로컬: test/serviceAccountKey.json 또는 환경변수 FIREBASE_KEY (JSON 문자열)

import json
import os

import firebase_admin
from firebase_admin import credentials, messaging


def ensure_firebase_app() -> None:
    if firebase_admin._apps:
        return
    key_json = os.environ.get("FIREBASE_KEY")
    if key_json:
        cred = credentials.Certificate(json.loads(key_json))
    else:
        _here = os.path.dirname(os.path.abspath(__file__))
        cred = credentials.Certificate(os.path.join(_here, "serviceAccountKey.json"))
    firebase_admin.initialize_app(cred)


def send_data_to_topic(
    data: dict[str, str],
    *,
    topic: str = "all_notices",
) -> str:
    """data 값은 모두 str 이어야 함. message id 반환."""
    ensure_firebase_app()
    msg = messaging.Message(data=data, topic=topic)
    return messaging.send(msg)
