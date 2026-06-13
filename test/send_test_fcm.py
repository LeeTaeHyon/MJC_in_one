import os
import firebase_admin
from firebase_admin import credentials, messaging

cred = credentials.Certificate('serviceAccountKey.json')
firebase_admin.initialize_app(cred)

# 1. 시스템 푸시 (notification 객체) + 비어있는 data 전송 시뮬레이션
# 크롤러가 이렇게 보냈을 때 앱 내 알림 화면에 안 뜨는 버그가 있었습니다.
message = messaging.Message(
    notification=messaging.Notification(
        title="[테스트] 시스템 푸시 공지",
        body="방금 수정한 코드가 잘 작동하는지 확인하는 알림입니다. 앱 내 기록에도 떠야 합니다!",
    ),
    topic="all_notices"  # 앱에서 구독하고 있는 기본 토픽
)

response = messaging.send(message)
print('Successfully sent test message:', response)
