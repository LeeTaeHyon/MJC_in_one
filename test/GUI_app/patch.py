import sys, re

with open('gui_manager.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix CSS
css_fix = """
            QScrollArea {
                background-color: #0A0A0A;
                border: none;
            }
            QScrollArea > QWidget > QWidget {
                background-color: #0A0A0A;
            }
            QCheckBox, QRadioButton {
                background-color: transparent;
                color: #E6FFFFFF;
            }
"""
content = content.replace('QScrollBar:vertical {', css_fix + '\n            QScrollBar:vertical {')

# Add language to config
if '"language"' not in content:
    content = content.replace('"gemini_enabled": True,', '"language": "ko",\n            "gemini_enabled": True,')

# Add tr function
tr_func = """
    def tr(self, text):
        lang = self.config.get('language', 'ko')
        if lang == 'en':
            return text
        ko_dict = {
            'MJC Operations Console': 'MJC 운영 콘솔',
            '📡 Crawlers': '📡 크롤러',
            '🔄 Backfills': '🔄 백필(데이터 갱신)',
            '🔔 Notifications': '🔔 알림',
            '🧪 Diagnostics': '🧪 진단',
            '⚙️ Settings': '⚙️ 설정',
            '🟢 Firebase Admin Ready': '🟢 Firebase Admin 준비됨',
            '⚠️ Firebase SDK Missing': '⚠️ Firebase SDK 없음',
            '📄 Live Console Log': '📄 실시간 콘솔 로그',
            'Clear': '지우기',
            'Stop Execution': '실행 중지',
            'Status: Idle': '상태: 대기 중',
            '🔄 Refresh Firestore Stats': '🔄 Firestore 통계 새로고침',
            '📡 Crawlers & Presets': '📡 크롤러 및 프리셋',
            'Run individual data collectors or queue them sequentially using presets.': '개별 데이터 수집기를 실행하거나 프리셋을 사용하여 순차적으로 실행합니다.',
            'Operations Presets': '작업 프리셋',
            '🌅 Daily Incremental Crawl': '🌅 일일 증분 크롤링',
            '🔄 Run All Crawlers (Full)': '🔄 모든 크롤러 실행 (전체)',
            'Individual Crawlers': '개별 크롤러',
            'Execution Mode:': '실행 모드:',
            'Execute Crawler:': '크롤러 실행:',
            'MJC Crawler': 'MJC 크롤러',
            'MPU Crawler': 'MPU 크롤러',
            'CTL Crawler': 'CTL 크롤러',
            'Schedule Crawler': '학사일정 크롤러',
            'Firestore Live Status Panel': 'Firestore 실시간 상태 패널',
            '🔄 Backfills & Summarizers': '🔄 백필 및 요약기',
            'Reprocess stored Firestore documents to enrich them with AI tags, bodies, and summaries.': '저장된 Firestore 문서를 재처리하여 AI 태그, 본문 및 요약을 추가합니다.',
            'AI Tagging Backfill (backfill_ai_tags.py)': 'AI 태깅 백필 (backfill_ai_tags.py)',
            'Dry Run (Preview changes only, does not modify Firestore)': '테스트 실행 (변경 사항만 미리보기, Firestore 수정 안 함)',
            'Force Overwrite (Overwrite existing tags even if they exist)': '강제 덮어쓰기 (기존 태그가 있어도 덮어쓰기)',
            'Source Filters:': '소스 필터:',
            'Limit (Limit count):': '제한 (처리 개수):',
            "Use LM Studio (Refines tags using LM Studio when rules assign '기타')": "LM Studio 사용 (규칙이 '기타'로 지정할 때 LM Studio를 사용하여 태그 세분화)",
            '🚀 Run AI Tag Backfill': '🚀 AI 태그 백필 실행',
            'Notice Body & Summary Backfill (backfill_notice_body.py)': '공지사항 본문 및 요약 백필 (backfill_notice_body.py)',
            'Dry Run (Preview changes only)': '테스트 실행 (변경 사항만 미리보기)',
            'Force Fetch (Refetch body and regenerate summary even if present)': '강제 가져오기 (본문을 다시 가져오고 요약을 재생성)',
            'Use Gemini Flash (Generates summarization via Gemini, API key required)': 'Gemini Flash 사용 (Gemini를 통해 요약 생성, API 키 필요)',
            "Resummary Flagged Only (Process documents marked 'needs_resummary=true')": "재요약 플래그된 문서만 ('needs_resummary=true' 문서 처리)",
            'Reported Only (Process flagged reports that are open)': '신고된 문서만 (활성 상태인 신고된 문서 처리)',
            'Backfill Target Mode:': '백필 대상 모드:',
            'MJC Board Filter:': 'MJC 게시판 필터:',
            '🚀 Run Body/Summary Backfill': '🚀 본문/요약 백필 실행',
            '🔔 Push Notifications Console': '🔔 푸시 알림 콘솔',
            'Dispatch FCM push notifications directly to app users using your Firebase key credentials.': 'Firebase 키 자격 증명을 사용하여 앱 사용자에게 직접 FCM 푸시 알림을 발송합니다.',
            'FCM Direct Broadcast Sender': 'FCM 직접 브로드캐스트 발송기',
            'Push Title:': '푸시 제목:',
            'Push Body:': '푸시 본문:',
            'Broadcast Topic:': '브로드캐스트 주제(토픽):',
            'Custom Topic Target:': '사용자 지정 토픽 대상:',
            '🔔 Send Direct Push Notification': '🔔 직접 푸시 알림 보내기',
            '⚠️ Important Operating Rules': '⚠️ 중요 운영 규칙',
            'This action sends live broadcast alerts directly to all active app installations matching the designated topic subscription. Please verify the contents and title formatting prior to dispatch.': '이 작업은 지정된 주제(토픽) 구독과 일치하는 모든 활성 앱 설치 기기에 실시간 브로드캐스트 알림을 직접 보냅니다. 발송 전에 내용과 제목 형식을 확인하십시오.',
            'System Configurations': '시스템 구성',
            'General Settings': '일반 설정',
            'Language (Requires Restart):': '언어 (재시작 필요):',
            'Save Settings': '설정 저장'
        }
        return ko_dict.get(text, text)
"""

if "def tr(self, text):" not in content:
    content = content.replace('    def init_ui(self):', tr_func + '\n    def init_ui(self):')

# Replace strings with self.tr
# Find all string literals we defined in the dictionary and replace them with self.tr("...")
ko_dict_pattern = re.search(r'ko_dict = \{(.*?)\}', tr_func, re.DOTALL)
if ko_dict_pattern:
    pairs = ko_dict_pattern.group(1)
    for match in re.finditer(r'([\"\'])(.*?)\1\s*:', pairs):
        en_str = match.group(2)
        if en_str == "ko" or en_str == "en" or en_str == "language": continue
        
        escaped_en = re.escape(en_str)
        content = re.sub(f'([\"\']){escaped_en}\\1', f'self.tr("{en_str}")', content)

# Settings tab language dropdown
settings_addition = """
        self.lang_combo = QComboBox()
        self.lang_combo.addItems(["ko", "en"])
        self.lang_combo.setCurrentText(self.config.get("language", "ko"))
        gen_form.addRow(self.tr("Language (Requires Restart):"), self.lang_combo)
"""
if "self.lang_combo = QComboBox()" not in content:
    content = content.replace('        self.min_date = QLineEdit(self.config.get("min_post_date", "2026-01-01"))', settings_addition + '\n        self.min_date = QLineEdit(self.config.get("min_post_date", "2026-01-01"))')

# Update save config in settings
save_patch = """
        self.config["language"] = self.lang_combo.currentText()
        self.config["min_post_date"] = self.min_date.text()
"""
if 'self.config["language"] = self.lang_combo.currentText()' not in content:
    content = content.replace('        self.config["min_post_date"] = self.min_date.text()', save_patch)

with open('gui_manager.py', 'w', encoding='utf-8') as f:
    f.write(content)

print("Patch applied successfully.")
