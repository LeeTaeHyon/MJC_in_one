import os
import sys
import json
import subprocess
import threading
import traceback
from datetime import datetime

# Prevent pythonw crashes by providing dummy stdout/stderr
if sys.stdout is None:
    sys.stdout = open(os.devnull, "w")
if sys.stderr is None:
    sys.stderr = open(os.devnull, "w")

from PySide6.QtCore import Qt, QSize, QThread, Signal, Slot
from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QPushButton, QLineEdit, QCheckBox, QComboBox, QTextEdit,
    QStackedWidget, QFileDialog, QFormLayout, QScrollArea, QFrame,
    QPlainTextEdit, QMessageBox, QGroupBox, QSplitter, QGridLayout
)
from PySide6.QtGui import QColor, QFont, QTextCursor

# Resolution of paths
APP_DIR = os.path.dirname(os.path.abspath(__file__))
TEST_DIR = os.path.dirname(APP_DIR)

# Global variables for Firebase support
FIREBASE_AVAILABLE = False
firebase_admin = None
credentials = None
firestore = None
messaging = None

try:
    import firebase_admin
    from firebase_admin import credentials, firestore, messaging
    FIREBASE_AVAILABLE = True
except ImportError:
    FIREBASE_AVAILABLE = False


class ScriptWorker(QThread):
    log_signal = Signal(str)
    finished_signal = Signal(bool)
    
    def __init__(self, scripts_info: list[tuple[str, list[str]]], env: dict, cwd: str):
        super().__init__()
        self.scripts_info = scripts_info  # list of (script_path, args)
        self.env = env
        self.cwd = cwd
        self.process = None
        self.is_killed = False

    def run(self):
        for script_path, args in self.scripts_info:
            if self.is_killed:
                break
            
            script_name = os.path.basename(script_path)
            self.log_signal.emit(f"\n========================================\n")
            self.log_signal.emit(f"🚀 Running: {script_name} {' '.join(args)}\n")
            self.log_signal.emit(f"========================================\n\n")
            
            # Use the same python interpreter that is running the GUI
            python_bin = sys.executable
            
            cmd = [python_bin, script_path] + args
            
            # Set PYTHONUNBUFFERED=1 to ensure live stdout streaming
            proc_env = os.environ.copy()
            proc_env.update(self.env)
            proc_env["PYTHONUNBUFFERED"] = "1"
            
            try:
                self.process = subprocess.Popen(
                    cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    cwd=self.cwd,
                    env=proc_env,
                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
                )
                
                # Stream logs in real-time
                while True:
                    line = self.process.stdout.readline()
                    if not line and self.process.poll() is not None:
                        break
                    if line:
                        self.log_signal.emit(line)
                
                rc = self.process.wait()
                if rc == 0:
                    self.log_signal.emit(f"\n✅ Completed: {script_name}\n")
                else:
                    if self.is_killed:
                        self.log_signal.emit(f"\n⏹️ Stopped by user: {script_name}\n")
                    else:
                        self.log_signal.emit(f"\n❌ Failed with return code {rc}: {script_name}\n")
                        self.finished_signal.emit(False)
                        return
                        
            except Exception as e:
                self.log_signal.emit(f"\n❌ Error executing script {script_name}: {str(e)}\n")
                self.finished_signal.emit(False)
                return
                
        if not self.is_killed:
            self.finished_signal.emit(True)

    def terminate_process(self):
        self.is_killed = True
        if self.process:
            self.process.terminate()
            try:
                self.process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.process.kill()


class FcmSendWorker(QThread):
    success_signal = Signal(str)
    error_signal = Signal(str)

    def __init__(self, service_account_path: str, title: str, body: str, topic: str):
        super().__init__()
        self.service_account_path = service_account_path
        self.title = title
        self.body = body
        self.topic = topic

    def run(self):
        if not FIREBASE_AVAILABLE:
            self.error_signal.emit("firebase-admin SDK is not installed or available.")
            return

        try:
            # Initialize Firebase Admin SDK if not already initialized
            if not firebase_admin._apps:
                cred = credentials.Certificate(self.service_account_path)
                firebase_admin.initialize_app(cred)
            
            message = messaging.Message(
                data={
                    "title": self.title,
                    "body": self.body,
                    "url": "https://www.mjc.ac.kr",
                    "board": "GUI Direct Push",
                    "source": "gui",
                },
                topic=self.topic,
            )
            
            response = messaging.send(message)
            self.success_signal.emit(f"Notification sent successfully! ID: {response}")
        except Exception as e:
            err_msg = traceback.format_exc()
            self.error_signal.emit(f"Error sending FCM: {str(e)}\n\n{err_msg}")


class StatsWorker(QThread):
    stats_loaded_signal = Signal(dict)
    error_signal = Signal(str)

    def __init__(self, service_account_path: str):
        super().__init__()
        self.service_account_path = service_account_path

    def run(self):
        if not FIREBASE_AVAILABLE:
            self.error_signal.emit("Firebase library not installed.")
            return

        try:
            # Initialize Firebase Admin if needed
            if not firebase_admin._apps:
                cred = credentials.Certificate(self.service_account_path)
                firebase_admin.initialize_app(cred)

            db = firestore.client()
            stats = {}

            # 1. MJC Boards: notices/main_notice, notices/main_academic, notices/main_scholarship
            mjc_boards = {
                "main_notice": "MJC 공지사항",
                "main_academic": "MJC 학사공지",
                "main_scholarship": "MJC 장학공지"
            }
            for board_id, label in mjc_boards.items():
                col_ref = db.collection("notices").document(board_id)
                
                # Fetch count
                try:
                    count = col_ref.collection("posts").count().get()[0][0].value
                except Exception:
                    # Fallback if count aggregation fails
                    count = len(col_ref.collection("posts").limit(500).get())

                # Fetch latest update time
                meta_doc = col_ref.collection("meta").document("info").get()
                updated_at = "N/A"
                if meta_doc.exists:
                    updated_at = meta_doc.to_dict().get("updated_at", "N/A")
                    # Make timestamp look pretty
                    if updated_at != "N/A" and "T" in updated_at:
                        updated_at = updated_at.split(".")[0].replace("T", " ")

                stats[board_id] = {"label": label, "count": count, "updated_at": updated_at}

            # 2. MPU Programs: core_competencies/all/programs
            mpu_col = db.collection("core_competencies").document("all")
            try:
                mpu_count = mpu_col.collection("programs").count().get()[0][0].value
            except Exception:
                mpu_count = len(mpu_col.collection("programs").limit(500).get())
            
            mpu_meta = mpu_col.collection("meta").document("info").get()
            mpu_updated_at = "N/A"
            if mpu_meta.exists:
                mpu_updated_at = mpu_meta.to_dict().get("updated_at", "N/A")
                if mpu_updated_at != "N/A" and "T" in mpu_updated_at:
                    mpu_updated_at = mpu_updated_at.split(".")[0].replace("T", " ")
            
            stats["mpu"] = {"label": "MPU 핵심역량 프로그램", "count": mpu_count, "updated_at": mpu_updated_at}

            # 3. CTL: ctl_data/programs (CTL 프로그램) & ctl_data/notices (CTL 공지)
            ctl_types = {
                "programs": "CTL 프로그램",
                "notices": "CTL 공지사항"
            }
            for ctl_id, label in ctl_types.items():
                ctl_doc = db.collection("ctl_data").document(ctl_id)
                try:
                    ctl_count = ctl_doc.collection("items").count().get()[0][0].value
                except Exception:
                    ctl_count = len(ctl_doc.collection("items").limit(500).get())
                
                ctl_meta = ctl_doc.collection("meta").document("info").get()
                ctl_updated_at = "N/A"
                if ctl_meta.exists:
                    ctl_updated_at = ctl_meta.to_dict().get("updated_at", "N/A")
                    if ctl_updated_at != "N/A" and "T" in ctl_updated_at:
                        ctl_updated_at = ctl_updated_at.split(".")[0].replace("T", " ")
                
                stats[f"ctl_{ctl_id}"] = {"label": label, "count": ctl_count, "updated_at": ctl_updated_at}

            self.stats_loaded_signal.emit(stats)

        except Exception as e:
            self.error_signal.emit(str(e))


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.config = {}
        self.active_worker = None
        self.load_config()

        self.setWindowTitle(self.tr("MJC Operations Console"))
        self.resize(1100, 750)
        
        self.init_ui()
        self.refresh_stats()

    def load_config(self):
        config_path = os.path.join(APP_DIR, "config.json")
        if os.path.exists(config_path):
            try:
                with open(config_path, "r", encoding="utf-8") as f:
                    self.config = json.load(f)
            except Exception as e:
                print(f"Error loading config.json: {e}")
                self.set_default_config()
        else:
            self.set_default_config()
            self.save_config()

    def set_default_config(self):
        self.config = {
            "min_post_date": "2026-01-01",
            "language": "ko",
            "gemini_enabled": True,
            "gemini_api_key": "",
            "gemini_model": "gemini-2.5-flash",
            "firebase_project": "mjc-one",
            "service_account": "../serviceAccountKey.json",
            "env_file": "../.env"
        }

    def save_config(self):
        config_path = os.path.join(APP_DIR, "config.json")
        try:
            with open(config_path, "w", encoding="utf-8") as f:
                json.dump(self.config, f, indent=2, ensure_ascii=False)
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to save config.json: {e}")

    def get_resolved_service_account(self):
        sa = self.config.get("service_account", "../serviceAccountKey.json")
        if not os.path.isabs(sa):
            sa = os.path.abspath(os.path.join(APP_DIR, sa))
        return sa

    def get_serialized_firebase_key(self):
        sa_path = self.get_resolved_service_account()
        if os.path.exists(sa_path):
            try:
                with open(sa_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    return json.dumps(data)
            except Exception:
                pass
        return ""

    def get_env_dict(self):
        env = {}
        
        # Parse custom .env file if specified
        env_file_path = self.config.get("env_file", "../.env")
        if env_file_path:
            abs_env = os.path.abspath(os.path.join(APP_DIR, env_file_path))
            if os.path.exists(abs_env):
                try:
                    with open(abs_env, "r", encoding="utf-8") as f:
                        for line in f:
                            line = line.strip()
                            if line and not line.startswith("#"):
                                if "=" in line:
                                    k, v = line.split("=", 1)
                                    env[k.strip()] = v.strip().strip("'\"")
                except Exception as e:
                    print(f"Error loading .env: {e}")

        # Explicit configs override .env
        env["MIN_POST_DATE"] = self.config.get("min_post_date", "2026-01-01")
        
        # GEMINI_API_KEY
        if self.config.get("gemini_enabled", True):
            saved_key = self.config.get("gemini_api_key", "").strip()
            if saved_key:
                env["GEMINI_API_KEY"] = saved_key
            elif "GEMINI_API_KEY" not in env:
                env["GEMINI_API_KEY"] = os.environ.get("GEMINI_API_KEY", "").strip()
            
            env["GEMINI_MODEL"] = self.config.get("gemini_model", "gemini-2.5-flash")
        else:
            env["GEMINI_API_KEY"] = ""
            env["GEMINI_MODEL"] = ""

        # FIREBASE_KEY
        firebase_json = self.get_serialized_firebase_key()
        if firebase_json:
            env["FIREBASE_KEY"] = firebase_json

        return env


    def tr(self, text):
        lang = self.config.get('language', 'ko')
        if lang == 'en':
            return text
        ko_dict = {
            "MJC Operations Console": 'MJC 운영 콘솔',
            "📡 Crawlers": '📡 크롤러',
            "🔄 Backfills": '🔄 백필(데이터 갱신)',
            "🔔 Notifications": '🔔 알림',
            "🧪 Diagnostics": '🧪 진단',
            "⚙️ Settings": '⚙️ 설정',
            "🟢 Firebase Admin Ready": '🟢 Firebase Admin 준비됨',
            "⚠️ Firebase SDK Missing": '⚠️ Firebase SDK 없음',
            "📄 Live Console Log": '📄 실시간 콘솔 로그',
            "Clear": '지우기',
            "Stop Execution": '실행 중지',
            "Status: Idle": '상태: 대기 중',
            "🔄 Refresh Firestore Stats": '🔄 Firestore 통계 새로고침',
            "📡 Crawlers & Presets": '📡 크롤러 및 프리셋',
            "Run individual data collectors or queue them sequentially using presets.": '개별 데이터 수집기를 실행하거나 프리셋을 사용하여 순차적으로 실행합니다.',
            "Operations Presets": '작업 프리셋',
            "🌅 Daily Incremental Crawl": '🌅 일일 증분 크롤링',
            "🔄 Run All Crawlers (Full)": '🔄 모든 크롤러 실행 (전체)',
            "Individual Crawlers": '개별 크롤러',
            "Execution Mode:": '실행 모드:',
            "Execute Crawler:": '크롤러 실행:',
            "MJC Crawler": 'MJC 크롤러',
            "MPU Crawler": 'MPU 크롤러',
            "CTL Crawler": 'CTL 크롤러',
            "Schedule Crawler": '학사일정 크롤러',
            "Firestore Live Status Panel": 'Firestore 실시간 상태 패널',
            "🔄 Backfills & Summarizers": '🔄 백필 및 요약기',
            "Reprocess stored Firestore documents to enrich them with AI tags, bodies, and summaries.": '저장된 Firestore 문서를 재처리하여 AI 태그, 본문 및 요약을 추가합니다.',
            "AI Tagging Backfill (backfill_ai_tags.py)": 'AI 태깅 백필 (backfill_ai_tags.py)',
            "Dry Run (Preview changes only, does not modify Firestore)": '테스트 실행 (변경 사항만 미리보기, Firestore 수정 안 함)',
            "Force Overwrite (Overwrite existing tags even if they exist)": '강제 덮어쓰기 (기존 태그가 있어도 덮어쓰기)',
            "Source Filters:": '소스 필터:',
            "Limit (Limit count):": '제한 (처리 개수):',
            "Use LM Studio (Refines tags using LM Studio when rules assign '기타')": "LM Studio 사용 (규칙이 '기타'로 지정할 때 LM Studio를 사용하여 태그 세분화)",
            "🚀 Run AI Tag Backfill": '🚀 AI 태그 백필 실행',
            "Notice Body & Summary Backfill (backfill_notice_body.py)": '공지사항 본문 및 요약 백필 (backfill_notice_body.py)',
            "Dry Run (Preview changes only)": '테스트 실행 (변경 사항만 미리보기)',
            "Force Fetch (Refetch body and regenerate summary even if present)": '강제 가져오기 (본문을 다시 가져오고 요약을 재생성)',
            "Use Gemini Flash (Generates summarization via Gemini, API key required)": 'Gemini Flash 사용 (Gemini를 통해 요약 생성, API 키 필요)',
            "Resummary Flagged Only (Process documents marked 'needs_resummary=true')": "재요약 플래그된 문서만 ('needs_resummary=true' 문서 처리)",
            "Reported Only (Process flagged reports that are open)": '신고된 문서만 (활성 상태인 신고된 문서 처리)',
            "Backfill Target Mode:": '백필 대상 모드:',
            "MJC Board Filter:": 'MJC 게시판 필터:',
            "🚀 Run Body/Summary Backfill": '🚀 본문/요약 백필 실행',
            "🔔 Push Notifications Console": '🔔 푸시 알림 콘솔',
            "Dispatch FCM push notifications directly to app users using your Firebase key credentials.": 'Firebase 키 자격 증명을 사용하여 앱 사용자에게 직접 FCM 푸시 알림을 발송합니다.',
            "FCM Direct Broadcast Sender": 'FCM 직접 브로드캐스트 발송기',
            "Push Title:": '푸시 제목:',
            "Push Body:": '푸시 본문:',
            "Broadcast Topic:": '브로드캐스트 주제(토픽):',
            "Custom Topic Target:": '사용자 지정 토픽 대상:',
            "🔔 Send Direct Push Notification": '🔔 직접 푸시 알림 보내기',
            "⚠️ Important Operating Rules": '⚠️ 중요 운영 규칙',
            "This action sends live broadcast alerts directly to all active app installations matching the designated topic subscription. Please verify the contents and title formatting prior to dispatch.": '이 작업은 지정된 주제(토픽) 구독과 일치하는 모든 활성 앱 설치 기기에 실시간 브로드캐스트 알림을 직접 보냅니다. 발송 전에 내용과 제목 형식을 확인하십시오.',
            "System Configurations": '시스템 구성',
            "General Settings": '일반 설정',
            "Language (Requires Restart):": '언어 (재시작 필요):',
            "Save Settings": '설정 저장'
        }
        return ko_dict.get(text, text)

    def init_ui(self):
        # Set light theme stylesheet matching VSCode
        self.setStyleSheet("""
            QMainWindow {
                background-color: #FFFFFF;
            }
            QWidget {
                font-family: "Segoe UI", "Pretendard", "Apple SD Gothic Neo", "Arial";
                color: #333333;
            }
            QLabel {
                background-color: transparent;
            }
            QFrame#Sidebar {
                background-color: #F3F3F3;
                border-right: 1px solid #E5E5E5;
            }
            QFrame#Card {
                background-color: #FFFFFF;
                border: 1px solid #E5E5E5;
                border-radius: 8px;
            }
            QLabel#Title {
                font-size: 18px;
                font-weight: bold;
                color: #0078D4;
                background-color: transparent;
            }
            QLabel#SubTitle {
                font-size: 13px;
                color: #666666;
                background-color: transparent;
            }
            QLabel#MutedLabel {
                color: #888888;
                font-size: 13px;
                background-color: transparent;
            }
            QPushButton {
                background-color: #F8F8F8;
                border: 1px solid #CECECE;
                border-radius: 6px;
                padding: 8px 16px;
                font-weight: bold;
                font-size: 13px;
                color: #333333;
            }
            QPushButton:hover {
                background-color: #E8E8E8;
                border: 1px solid #BDBDBD;
            }
            QPushButton:pressed {
                background-color: #D4D4D4;
            }
            QPushButton#Primary {
                background-color: #0078D4;
                color: #FFFFFF;
                border: none;
            }
            QPushButton#Primary:hover {
                background-color: #106EBE;
            }
            QPushButton#Primary:pressed {
                background-color: #005A9E;
            }
            QPushButton#Danger {
                background-color: #D13438;
                color: #FFFFFF;
                border: none;
            }
            QPushButton#Danger:hover {
                background-color: #C12C30;
            }
            QPushButton#Danger:pressed {
                background-color: #A80000;
            }
            QPushButton#SidebarBtn {
                text-align: left;
                background-color: transparent;
                border: none;
                border-radius: 6px;
                padding: 12px 16px;
                font-size: 14px;
                color: #666666;
            }
            QPushButton#SidebarBtn:hover {
                background-color: #E8E8E8;
                color: #333333;
            }
            QPushButton#SidebarBtn:checked {
                background-color: #E4E6F1;
                color: #0078D4;
                font-weight: bold;
            }
            QLineEdit, QComboBox, QSpinBox {
                background-color: #FFFFFF;
                border: 1px solid #CECECE;
                border-radius: 6px;
                padding: 8px 12px;
                color: #333333;
                font-size: 13px;
            }
            QLineEdit:focus, QComboBox:focus, QSpinBox:focus {
                border: 1px solid #0078D4;
                background-color: #FFFFFF;
            }
            QPlainTextEdit {
                background-color: #FFFFFF;
                border: 1px solid #CECECE;
                border-radius: 6px;
                padding: 8px;
                color: #333333;
                font-size: 13px;
            }
            QPlainTextEdit#ConsoleLog {
                background-color: #F8F8F8;
                border: 1px solid #E5E5E5;
                border-radius: 8px;
                font-family: "Consolas", "Courier New", monospace;
                font-size: 13px;
                color: #333333;
            }
            QGroupBox {
                border: 1px solid #E5E5E5;
                border-radius: 8px;
                margin-top: 20px;
                padding-top: 15px;
                font-weight: bold;
                font-size: 14px;
                background-color: #FAFAFA;
            }
            QGroupBox::title {
                subcontrol-origin: margin;
                subcontrol-position: top left;
                left: 15px;
                padding: 0 5px;
                color: #0078D4;
                background-color: #FAFAFA;
            }
            QScrollArea {
                background-color: #FFFFFF;
                border: none;
            }
            QScrollArea > QWidget > QWidget {
                background-color: #FFFFFF;
            }
            QCheckBox, QRadioButton {
                background-color: transparent;
                color: #333333;
                font-size: 13px;
            }
            QScrollBar:vertical {
                border: none;
                background: #F3F3F3;
                width: 10px;
                margin: 0px 0px 0px 0px;
            }
            QScrollBar::handle:vertical {
                background: #CCCCCC;
                min-height: 20px;
                border-radius: 5px;
            }
            QScrollBar::handle:vertical:hover {
                background: #AAAAAA;
            }
            QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {
                border: none;
                background: none;
            }
        """)

        # Main Layout: Sidebar on the left, Operation Area on the right (split with console at bottom)
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QHBoxLayout(central_widget)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)

        # ------------------ SIDEBAR ------------------
        sidebar = QFrame()
        sidebar.setObjectName("Sidebar")
        sidebar.setFixedWidth(230)
        sidebar_layout = QVBoxLayout(sidebar)
        sidebar_layout.setContentsMargins(15, 20, 15, 20)
        sidebar_layout.setSpacing(10)

        # Logo / Brand Header
        logo_label = QLabel("📡 MJC Manager")
        logo_label.setStyleSheet("font-size: 20px; font-weight: 800; color: #0078D4; padding-bottom: 5px;")
        sub_logo = QLabel("MJC ONE Operations Console")
        sub_logo.setStyleSheet("font-size: 11px; color: #666666; padding-bottom: 20px;")
        sidebar_layout.addWidget(logo_label)
        sidebar_layout.addWidget(sub_logo)

        # Navigation Buttons Group
        self.nav_buttons = []
        nav_items = [
            (self.tr("📡 Crawlers"), 0),
            (self.tr("🔄 Backfills"), 1),
            (self.tr("🔔 Notifications"), 2),
            (self.tr("🧪 Diagnostics"), 3),
            (self.tr("⚙️ Settings"), 4),
        ]

        for text, index in nav_items:
            btn = QPushButton(text)
            btn.setObjectName("SidebarBtn")
            btn.setCheckable(True)
            if index == 0:
                btn.setChecked(True)
            btn.clicked.connect(lambda checked, idx=index: self.switch_tab(idx))
            sidebar_layout.addWidget(btn)
            self.nav_buttons.append(btn)

        sidebar_layout.addStretch()

        # Firebase Status Indicator
        self.fb_status_label = QLabel()
        if FIREBASE_AVAILABLE:
            self.fb_status_label.setText(self.tr("🟢 Firebase Admin Ready"))
            self.fb_status_label.setStyleSheet("color: #107C10; font-size: 12px; font-weight: bold;")
        else:
            self.fb_status_label.setText(self.tr("⚠️ Firebase SDK Missing"))
            self.fb_status_label.setStyleSheet("color: #D13438; font-size: 12px; font-weight: bold;")
        sidebar_layout.addWidget(self.fb_status_label)

        main_layout.addWidget(sidebar)

        # ------------------ RIGHT WORK AREA ------------------
        right_panel = QWidget()
        right_layout = QVBoxLayout(right_panel)
        right_layout.setContentsMargins(20, 20, 20, 20)
        right_layout.setSpacing(15)

        # Splitter to divide Upper Panel (Tab Content) and Lower Panel (Console)
        splitter = QSplitter(Qt.Orientation.Vertical)
        
        # Upper Container: Stacked Widget for Tabs
        self.stacked_widget = QStackedWidget()
        
        # Add Tabs
        self.tab_crawlers = self.create_crawlers_tab()
        self.tab_backfills = self.create_backfills_tab()
        self.tab_notifications = self.create_notifications_tab()
        self.tab_diagnostics = self.create_diagnostics_tab()
        self.tab_settings = self.create_settings_tab()

        self.stacked_widget.addWidget(self.tab_crawlers)
        self.stacked_widget.addWidget(self.tab_backfills)
        self.stacked_widget.addWidget(self.tab_notifications)
        self.stacked_widget.addWidget(self.tab_diagnostics)
        self.stacked_widget.addWidget(self.tab_settings)

        splitter.addWidget(self.stacked_widget)

        # Lower Container: Console log pane
        console_widget = QWidget()
        console_layout = QVBoxLayout(console_widget)
        console_layout.setContentsMargins(0, 10, 0, 0)
        console_layout.setSpacing(8)

        console_header_layout = QHBoxLayout()
        console_title = QLabel(self.tr("📄 Live Console Log"))
        console_title.setObjectName("Title")
        console_header_layout.addWidget(console_title)
        console_header_layout.addStretch()

        clear_console_btn = QPushButton(self.tr("Clear"))
        clear_console_btn.clicked.connect(self.clear_console)
        clear_console_btn.setFixedWidth(80)
        clear_console_btn.setFixedHeight(30)
        clear_console_btn.setStyleSheet("padding: 2px; font-size: 11px;")
        console_header_layout.addWidget(clear_console_btn)

        self.stop_btn = QPushButton(self.tr("Stop Execution"))
        self.stop_btn.setObjectName("Danger")
        self.stop_btn.setEnabled(False)
        self.stop_btn.clicked.connect(self.stop_current_job)
        self.stop_btn.setFixedHeight(30)
        self.stop_btn.setStyleSheet("font-size: 11px; padding: 2px 10px;")
        console_header_layout.addWidget(self.stop_btn)

        console_layout.addLayout(console_header_layout)

        self.console = QPlainTextEdit()
        self.console.setObjectName("ConsoleLog")
        self.console.setReadOnly(True)
        console_layout.addWidget(self.console)

        splitter.addWidget(console_widget)
        
        # Initial splitter sizes: 65% Stacked Content, 35% Console Log
        splitter.setSizes([550, 200])

        right_layout.addWidget(splitter)

        # Bottom Status Bar
        status_bar = QHBoxLayout()
        status_bar.setContentsMargins(0, 0, 0, 0)
        
        self.status_indicator = QLabel("●")
        self.status_indicator.setStyleSheet("color: #AAAAAA; font-size: 16px; margin-right: 5px;")
        self.status_text = QLabel(self.tr("Status: Idle"))
        self.status_text.setStyleSheet("color: #666666; font-size: 12px;")
        status_bar.addWidget(self.status_indicator)
        status_bar.addWidget(self.status_text)
        
        status_bar.addStretch()
        
        ref_stats_btn = QPushButton(self.tr("🔄 Refresh Firestore Stats"))
        ref_stats_btn.setStyleSheet("font-size: 12px; padding: 6px 12px; background-color: transparent; border: 1px solid #CCCCCC; border-radius: 6px;")
        ref_stats_btn.clicked.connect(self.refresh_stats)
        status_bar.addWidget(ref_stats_btn)

        right_layout.addLayout(status_bar)

        main_layout.addWidget(right_panel)

    def switch_tab(self, index):
        for i, btn in enumerate(self.nav_buttons):
            btn.setChecked(i == index)
        self.stacked_widget.setCurrentIndex(index)

    # ------------------ TAB CONSTRUCTORS ------------------
    
    def create_card(self, title_text, layout=None):
        card = QFrame()
        card.setObjectName("Card")
        vbox = QVBoxLayout(card)
        vbox.setContentsMargins(20, 20, 20, 20)
        vbox.setSpacing(15)
        if title_text:
            lbl = QLabel(title_text)
            lbl.setStyleSheet("font-size: 16px; font-weight: bold; color: #0078D4; margin-bottom: 5px;")
            vbox.addWidget(lbl)
        if layout:
            vbox.addLayout(layout)
        return card

    def create_crawlers_tab(self):
        widget = QScrollArea()
        widget.setWidgetResizable(True)
        widget.setFrameShape(QFrame.Shape.NoFrame)
        content = QWidget()
        layout = QVBoxLayout(content)
        layout.setContentsMargins(25, 25, 25, 25)
        layout.setSpacing(25)

        title = QLabel(self.tr("📡 Crawlers & Presets"))
        title.setObjectName("Title")
        sub = QLabel(self.tr("Run individual data collectors or queue them sequentially using presets."))
        sub.setObjectName("SubTitle")
        layout.addWidget(title)
        layout.addWidget(sub)

        # Top row: Presets and Crawlers side by side
        top_row = QHBoxLayout()
        top_row.setSpacing(20)

        # Presets Card
        presets_layout = QVBoxLayout()
        presets_layout.setSpacing(10)
        daily_crawl_btn = QPushButton(self.tr("🌅 Daily Incremental Crawl"))
        daily_crawl_btn.setObjectName("Primary")
        daily_crawl_btn.clicked.connect(self.run_daily_crawl_preset)
        presets_layout.addWidget(daily_crawl_btn)
        all_crawl_full_btn = QPushButton(self.tr("🔄 Run All Crawlers (Full)"))
        all_crawl_full_btn.clicked.connect(self.run_all_crawlers_full_preset)
        presets_layout.addWidget(all_crawl_full_btn)
        presets_layout.addStretch()
        top_row.addWidget(self.create_card(self.tr("Operations Presets"), presets_layout), 1)

        # Individual Crawlers Card
        crawlers_grid = QGridLayout()
        crawlers_grid.setSpacing(10)
        
        crawlers_grid.addWidget(QLabel(self.tr("MJC Mode:")), 0, 0)
        self.crawl_mode_combo = QComboBox()
        self.crawl_mode_combo.addItems(["incremental", "full"])
        crawlers_grid.addWidget(self.crawl_mode_combo, 0, 1)
        
        run_mjc = QPushButton(self.tr("Run MJC Crawler"))
        run_mjc.setObjectName("Primary")
        run_mjc.clicked.connect(lambda: self.run_single_script(os.path.join(TEST_DIR, "crawler_mjc.py"), ["--firebase"]))
        crawlers_grid.addWidget(run_mjc, 0, 2)

        run_mpu = QPushButton(self.tr("MPU Crawler"))
        run_mpu.clicked.connect(lambda: self.run_single_script(os.path.join(TEST_DIR, "crawler_mpu.py")))
        crawlers_grid.addWidget(run_mpu, 1, 0)

        run_ctl = QPushButton(self.tr("CTL Crawler"))
        run_ctl.clicked.connect(lambda: self.run_single_script(os.path.join(TEST_DIR, "crawler_ctl.py")))
        crawlers_grid.addWidget(run_ctl, 1, 1)

        run_sched = QPushButton(self.tr("Schedule Crawler"))
        run_sched.clicked.connect(lambda: self.run_single_script(os.path.join(TEST_DIR, "crawler_schedule.py")))
        crawlers_grid.addWidget(run_sched, 1, 2)
        
        top_row.addWidget(self.create_card(self.tr("Individual Crawlers"), crawlers_grid), 2)
        layout.addLayout(top_row)

        # Firestore Live Stats Dashboard
        stats_layout = QGridLayout()
        stats_layout.setSpacing(15)
        
        self.stats_labels = {}
        boards = [
            ("main_notice", "MJC 공지사항"),
            ("main_academic", "MJC 학사공지"),
            ("main_scholarship", "MJC 장학공지"),
            ("mpu", "MPU 핵심역량 프로그램"),
            ("ctl_programs", "CTL 프로그램"),
            ("ctl_notices", "CTL 공지사항"),
        ]
        
        for i, (board_id, name) in enumerate(boards):
            row, col = divmod(i, 3)
            stat_box = QVBoxLayout()
            stat_box.setSpacing(2)
            
            name_lbl = QLabel(name)
            name_lbl.setStyleSheet("font-size: 13px; color: #666666; font-weight: bold;")
            
            val_lbl = QLabel("-")
            val_lbl.setStyleSheet("font-size: 26px; color: #0078D4; font-weight: bold;")
            
            date_lbl = QLabel("Updated: -")
            date_lbl.setStyleSheet("font-size: 11px; color: #AAAAAA;")
            
            stat_box.addWidget(name_lbl)
            stat_box.addWidget(val_lbl)
            stat_box.addWidget(date_lbl)
            
            w = QWidget()
            w.setLayout(stat_box)
            w.setStyleSheet("background-color: #FAFAFA; border: 1px solid #E5E5E5; border-radius: 6px; padding: 10px;")
            stats_layout.addWidget(w, row, col)
            self.stats_labels[board_id] = (val_lbl, date_lbl, name_lbl)
            
        layout.addWidget(self.create_card(self.tr("Firestore Data Overview"), stats_layout))
        layout.addStretch()

        widget.setWidget(content)
        return widget

    def create_backfills_tab(self):
        widget = QScrollArea()
        widget.setWidgetResizable(True)
        widget.setFrameShape(QFrame.Shape.NoFrame)
        content = QWidget()
        layout = QVBoxLayout(content)
        layout.setContentsMargins(25, 25, 25, 25)
        layout.setSpacing(25)

        title = QLabel(self.tr("🔄 Backfills & Summarizers"))
        title.setObjectName("Title")
        sub = QLabel(self.tr("Reprocess stored Firestore documents to enrich them with AI tags, bodies, and summaries."))
        sub.setObjectName("SubTitle")
        layout.addWidget(title)
        layout.addWidget(sub)

        # Side by side panels
        panels_row = QHBoxLayout()
        panels_row.setSpacing(20)

        # 1. AI Tags Backfill
        tag_layout = QFormLayout()
        tag_layout.setSpacing(12)

        self.tag_dry_run = QCheckBox(self.tr("Dry Run Mode"))
        self.tag_dry_run.setChecked(True)
        tag_layout.addRow(self.tag_dry_run)

        self.tag_force = QCheckBox(self.tr("Force Overwrite Existing Tags"))
        tag_layout.addRow(self.tag_force)
        
        self.tag_use_lm = QCheckBox(self.tr("Use LM Studio for refinement"))
        tag_layout.addRow(self.tag_use_lm)

        self.tag_source = QComboBox()
        self.tag_source.addItems(["all", "mjc", "ctl", "mpu"])
        tag_layout.addRow(QLabel(self.tr("Source Filter:")), self.tag_source)

        self.tag_limit = QLineEdit("50")
        tag_layout.addRow(QLabel(self.tr("Process Limit:")), self.tag_limit)

        run_tag_btn = QPushButton(self.tr("🚀 Run AI Tag Backfill"))
        run_tag_btn.setObjectName("Primary")
        run_tag_btn.clicked.connect(self.run_tag_backfill)
        tag_layout.addRow(run_tag_btn)
        
        panels_row.addWidget(self.create_card(self.tr("AI Tagging (backfill_ai_tags)"), tag_layout))

        # 2. Notice Body Backfill
        body_layout = QFormLayout()
        body_layout.setSpacing(12)

        self.body_dry_run = QCheckBox(self.tr("Dry Run Mode"))
        self.body_dry_run.setChecked(True)
        body_layout.addRow(self.body_dry_run)

        self.body_force = QCheckBox(self.tr("Force Refetch & Resummarize"))
        body_layout.addRow(self.body_force)

        self.body_use_gemini = QCheckBox(self.tr("Use Gemini Flash AI"))
        self.body_use_gemini.setChecked(True)
        body_layout.addRow(self.body_use_gemini)

        flags_row = QHBoxLayout()
        self.body_resummary_flagged = QCheckBox(self.tr("Flagged Only"))
        self.body_reported = QCheckBox(self.tr("Reported Only"))
        flags_row.addWidget(self.body_resummary_flagged)
        flags_row.addWidget(self.body_reported)
        body_layout.addRow(flags_row)

        self.body_mode = QComboBox()
        self.body_mode.addItems(["Both (Fetch body & summary)", "Body Only", "Summary Only"])
        body_layout.addRow(QLabel(self.tr("Target Mode:")), self.body_mode)

        self.body_board = QComboBox()
        self.body_board.addItems(["all", "main_notice", "main_academic", "main_scholarship"])
        body_layout.addRow(QLabel(self.tr("Board Filter:")), self.body_board)

        self.body_limit = QLineEdit("10")
        body_layout.addRow(QLabel(self.tr("Process Limit:")), self.body_limit)

        run_body_btn = QPushButton(self.tr("🚀 Run Body/Summary Backfill"))
        run_body_btn.setObjectName("Primary")
        run_body_btn.clicked.connect(self.run_body_backfill)
        body_layout.addRow(run_body_btn)

        panels_row.addWidget(self.create_card(self.tr("Body Encrichment (backfill_notice_body)"), body_layout))

        layout.addLayout(panels_row)
        layout.addStretch()

        widget.setWidget(content)
        return widget

    def create_notifications_tab(self):
        widget = QScrollArea()
        widget.setWidgetResizable(True)
        widget.setFrameShape(QFrame.Shape.NoFrame)
        
        content = QWidget()
        layout = QVBoxLayout(content)
        layout.setContentsMargins(25, 25, 25, 25)
        layout.setSpacing(20)

        title = QLabel(self.tr("🔔 Push Notifications Console"))
        title.setObjectName("Title")
        sub = QLabel(self.tr("Dispatch FCM push notifications directly to app users using your Firebase key credentials."))
        sub.setObjectName("SubTitle")
        layout.addWidget(title)
        layout.addWidget(sub)

        # FCM Send Group
        fcm_group = QGroupBox(self.tr("FCM Direct Broadcast Sender"))
        fcm_layout = QFormLayout(fcm_group)
        fcm_layout.setContentsMargins(15, 20, 15, 20)
        fcm_layout.setSpacing(15)

        self.push_title = QLineEdit()
        self.push_title.setPlaceholderText("e.g. [학사공지] 2026학년도 장학금 신청 안내")
        fcm_layout.addRow(QLabel(self.tr("Push Title:")), self.push_title)

        self.push_body = QTextEdit()
        self.push_body.setPlaceholderText("Write the push alert contents here...")
        self.push_body.setMaximumHeight(100)
        fcm_layout.addRow(QLabel(self.tr("Push Body:")), self.push_body)

        self.push_topic_combo = QComboBox()
        self.push_topic_combo.addItems(["all_notices", "Custom Topic"])
        self.push_topic_combo.currentTextChanged.connect(self.toggle_custom_topic_field)
        fcm_layout.addRow(QLabel(self.tr("Broadcast Topic:")), self.push_topic_combo)

        self.push_custom_topic = QLineEdit("all_notices")
        self.push_custom_topic.setPlaceholderText("Enter custom FCM topic target")
        self.push_custom_topic.setEnabled(False)
        fcm_layout.addRow(QLabel(self.tr("Custom Topic Target:")), self.push_custom_topic)

        self.send_push_btn = QPushButton(self.tr("🔔 Send Direct Push Notification"))
        self.send_push_btn.setObjectName("Primary")
        self.send_push_btn.clicked.connect(self.send_push_notification)
        fcm_layout.addRow(self.send_push_btn)

        layout.addWidget(fcm_group)

        # Helper note
        note_card = QFrame()
        note_card.setObjectName("Card")
        note_layout = QVBoxLayout(note_card)
        note_layout.setContentsMargins(15, 15, 15, 15)
        
        note_title = QLabel(self.tr("⚠️ Important Operating Rules"))
        note_title.setStyleSheet("font-weight: bold; color: #D13438; font-size: 13px; margin-bottom: 5px;")
        note_body = QLabel(
            "This action sends live broadcast alerts directly to all active app installations matching the designated topic subscription. "
            "Please verify the contents and title formatting prior to dispatch."
        )
        note_body.setStyleSheet("font-size: 12px; color: #666666;")
        note_body.setWordWrap(True)
        note_layout.addWidget(note_title)
        note_layout.addWidget(note_body)
        
        layout.addWidget(note_card)
        layout.addStretch()

        widget.setWidget(content)
        return widget

    def toggle_custom_topic_field(self, text):
        self.push_custom_topic.setEnabled(text == "Custom Topic")
        if text == "all_notices":
            self.push_custom_topic.setText("all_notices")

    def create_diagnostics_tab(self):
        widget = QScrollArea()
        widget.setWidgetResizable(True)
        widget.setFrameShape(QFrame.Shape.NoFrame)
        
        content = QWidget()
        layout = QVBoxLayout(content)
        layout.setContentsMargins(25, 25, 25, 25)
        layout.setSpacing(20)

        title = QLabel("🧪 Diagnostics & Local Tests")
        title.setObjectName("Title")
        sub = QLabel("Verify crawler behavior and system integrations locally without spamming live users.")
        sub.setObjectName("SubTitle")
        layout.addWidget(title)
        layout.addWidget(sub)

        # Local Crawler Tester Group
        test_group = QGroupBox("Local Crawler Tester (test_crawler_local.py)")
        test_form = QFormLayout(test_group)
        test_form.setContentsMargins(15, 15, 15, 15)
        test_form.setSpacing(12)

        self.test_firebase = QCheckBox("Save lists to Firestore (--firebase option)")
        test_form.addRow(self.test_firebase)

        run_local_test = QPushButton("🧪 Run Local Crawl Test")
        run_local_test.clicked.connect(self.run_local_crawler_test)
        test_form.addRow(run_local_test)

        layout.addWidget(test_group)

        # Integration / Unit Tests Group
        unit_group = QGroupBox("Unit & Verification Tests")
        unit_layout = QFormLayout(unit_group)
        unit_layout.setContentsMargins(15, 15, 15, 15)
        unit_layout.setSpacing(12)

        run_mpu_unit = QPushButton("Run MPU Parser Test (test_mpu.py)")
        run_mpu_unit.clicked.connect(lambda: self.run_single_script(os.path.join(TEST_DIR, "test_mpu.py")))
        unit_layout.addRow(run_mpu_unit)

        run_body_unit = QPushButton("Run Notice HTML Body Parser Test (test_notice_body_html.py)")
        run_body_unit.clicked.connect(lambda: self.run_single_script(os.path.join(TEST_DIR, "test_notice_body_html.py")))
        unit_layout.addRow(run_body_unit)

        layout.addWidget(unit_group)
        layout.addStretch()

        widget.setWidget(content)
        return widget

    def create_settings_tab(self):
        widget = QScrollArea()
        widget.setWidgetResizable(True)
        widget.setFrameShape(QFrame.Shape.NoFrame)
        
        content = QWidget()
        layout = QVBoxLayout(content)
        layout.setContentsMargins(25, 25, 25, 25)
        layout.setSpacing(20)

        title = QLabel("⚙️ Operations Configuration")
        title.setObjectName("Title")
        sub = QLabel("Configure local execution paths, AI model behaviors, and Firebase integration keys.")
        sub.setObjectName("SubTitle")
        layout.addWidget(title)
        layout.addWidget(sub)

        # Configuration Fields Card
        card = QFrame()
        card.setObjectName("Card")
        form = QFormLayout(card)
        form.setContentsMargins(20, 20, 20, 20)
        form.setSpacing(15)

        # Environment File (.env) Picker
        env_layout = QHBoxLayout()
        self.set_env_path = QLineEdit(self.config.get("env_file", "../.env"))
        self.set_env_path.setPlaceholderText("Path to .env file (optional)")
        env_layout.addWidget(self.set_env_path)
        
        env_browse = QPushButton("Browse")
        env_browse.setFixedWidth(80)
        env_browse.clicked.connect(self.browse_env_file)
        env_layout.addWidget(env_browse)
        form.addRow(QLabel("Environment File (.env):"), env_layout)

        # Service Account Path Picker
        sa_layout = QHBoxLayout()
        self.set_sa_path = QLineEdit(self.config.get("service_account", ""))
        self.set_sa_path.setPlaceholderText("Path to serviceAccountKey.json file")
        sa_layout.addWidget(self.set_sa_path)
        
        sa_browse = QPushButton("Browse")
        sa_browse.setFixedWidth(80)
        sa_browse.clicked.connect(self.browse_service_account)
        sa_layout.addWidget(sa_browse)
        form.addRow(QLabel("Service Account Key:"), sa_layout)

        # Firebase Project Name
        self.set_fb_project = QLineEdit(self.config.get("firebase_project", ""))
        form.addRow(QLabel("Firebase Project ID:"), self.set_fb_project)

        # Minimum Post Date Cutoff
        self.set_min_date = QLineEdit(self.config.get("min_post_date", ""))
        self.set_min_date.setPlaceholderText("YYYY-MM-DD")
        form.addRow(QLabel("Crawl Post Cutoff Date:"), self.set_min_date)

        # Gemini API Toggle & Key
        self.set_gemini_enabled = QCheckBox("Enable Gemini Flash summaries")
        self.set_gemini_enabled.setChecked(self.config.get("gemini_enabled", True))
        self.set_gemini_enabled.toggled.connect(self.toggle_gemini_key_field)
        form.addRow(self.set_gemini_enabled)

        self.set_gemini_key = QLineEdit(self.config.get("gemini_api_key", ""))
        self.set_gemini_key.setEchoMode(QLineEdit.EchoMode.Password)
        self.set_gemini_key.setPlaceholderText("Enter Gemini API key")
        
        # Show/Hide key toggle
        key_layout = QHBoxLayout()
        key_layout.addWidget(self.set_gemini_key)
        
        self.show_key_btn = QPushButton("Show")
        self.show_key_btn.setCheckable(True)
        self.show_key_btn.setFixedWidth(60)
        self.show_key_btn.clicked.connect(self.toggle_gemini_key_visibility)
        key_layout.addWidget(self.show_key_btn)
        
        self.gemini_form_row_label = QLabel("Gemini API Key:")
        form.addRow(self.gemini_form_row_label, key_layout)
        
        # Gemini Model Selection
        self.set_gemini_model = QComboBox()
        self.set_gemini_model.addItems([
            "gemini-2.5-flash",
            "gemini-2.0-flash",
            "gemini-1.5-flash",
            "gemini-1.5-pro",
            "gemini-1.0-pro",
            "gemma-4-31b-it",
            "gemma-2-27b-it"
        ])
        saved_model = self.config.get("gemini_model", "gemini-2.5-flash")
        self.set_gemini_model.setCurrentText(saved_model)
        self.gemini_model_label = QLabel("Gemini Model:")
        form.addRow(self.gemini_model_label, self.set_gemini_model)
        
        # Enable/Disable initial state
        self.toggle_gemini_key_field(self.set_gemini_enabled.isChecked())

        # Save Button
        save_btn = QPushButton(self.tr("Save Settings"))
        save_btn.setObjectName("Primary")
        save_btn.clicked.connect(self.save_settings_from_form)
        form.addRow(save_btn)

        layout.addWidget(card)
        layout.addStretch()

        widget.setWidget(content)
        return widget

    def toggle_gemini_key_visibility(self):
        if self.show_key_btn.isChecked():
            self.set_gemini_key.setEchoMode(QLineEdit.EchoMode.Normal)
            self.show_key_btn.setText("Hide")
        else:
            self.set_gemini_key.setEchoMode(QLineEdit.EchoMode.Password)
            self.show_key_btn.setText("Show")

    def toggle_gemini_key_field(self, checked):
        self.set_gemini_key.setEnabled(checked)
        self.show_key_btn.setEnabled(checked)
        self.gemini_form_row_label.setEnabled(checked)
        self.set_gemini_model.setEnabled(checked)
        self.gemini_model_label.setEnabled(checked)

    def browse_env_file(self):
        file_path, _ = QFileDialog.getOpenFileName(
            self, "Select Environment File", TEST_DIR, "All Files (*)"
        )
        if file_path:
            relative_path = os.path.relpath(file_path, APP_DIR)
            self.set_env_path.setText(relative_path.replace("\\", "/"))

    def browse_service_account(self):
        file_path, _ = QFileDialog.getOpenFileName(
            self, "Select Service Account Key JSON", TEST_DIR, "JSON Files (*.json)"
        )
        if file_path:
            # Save path as relative if it's within the TEST_DIR
            relative_path = os.path.relpath(file_path, APP_DIR)
            # If relative path starts with '..', it is clean
            self.set_sa_path.setText(relative_path.replace("\\", "/"))

    def save_settings_from_form(self):
        self.config["env_file"] = self.set_env_path.text().strip()
        self.config["service_account"] = self.set_sa_path.text().strip()
        self.config["firebase_project"] = self.set_fb_project.text().strip()
        self.config["min_post_date"] = self.set_min_date.text().strip()
        self.config["gemini_enabled"] = self.set_gemini_enabled.isChecked()
        self.config["gemini_api_key"] = self.set_gemini_key.text().strip()
        self.config["gemini_model"] = self.set_gemini_model.currentText()

        self.save_config()
        QMessageBox.information(self, "Success", "Settings saved and config.json updated successfully!")
        self.refresh_stats()

    # ------------------ SCRIPT LAUNCHERS ------------------
    
    def log_append(self, text):
        self.console.moveCursor(QTextCursor.MoveOperation.End)
        self.console.insertPlainText(text)
        self.console.moveCursor(QTextCursor.MoveOperation.End)

    def clear_console(self):
        self.console.clear()

    def set_app_running_state(self, running, task_name="Task"):
        if running:
            self.status_indicator.setStyleSheet("color: #107C10; font-size: 16px; margin-right: 5px;")
            self.status_text.setText(f"Status: Running {task_name}...")
            self.stop_btn.setEnabled(True)
            # Disable script buttons while running
            self.stacked_widget.setEnabled(False)
        else:
            self.status_indicator.setStyleSheet("color: #AAAAAA; font-size: 16px; margin-right: 5px;")
            self.status_text.setText(self.tr("Status: Idle"))
            self.stop_btn.setEnabled(False)
            self.stacked_widget.setEnabled(True)

    def run_scripts_list(self, scripts_info, task_label="Job Queue"):
        if self.active_worker and self.active_worker.isRunning():
            QMessageBox.warning(self, "Warning", "A script is already running!")
            return

        self.set_app_running_state(True, task_label)
        
        env = self.get_env_dict()
        self.active_worker = ScriptWorker(scripts_info, env, TEST_DIR)
        self.active_worker.log_signal.connect(self.log_append)
        self.active_worker.finished_signal.connect(self.on_worker_finished)
        self.active_worker.start()

    def run_single_script(self, script_path, args=None):
        if args is None:
            args = []
        
        script_name = os.path.basename(script_path)
        
        # Inject Crawl Mode to Env if we are running crawler_mjc
        env = {}
        if script_name == "crawler_mjc.py":
            # Read selection from GUI combo box
            mode = self.crawl_mode_combo.currentText()
            env["CRAWL_MODE"] = mode

        # Merge defaults
        full_env = self.get_env_dict()
        full_env.update(env)

        self.run_scripts_list([(script_path, args)], task_label=script_name)

    def stop_current_job(self):
        if self.active_worker and self.active_worker.isRunning():
            reply = QMessageBox.question(
                self, self.tr("Stop Execution"), "Are you sure you want to terminate the running processes?",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
            )
            if reply == QMessageBox.StandardButton.Yes:
                self.active_worker.terminate_process()

    @Slot(bool)
    def on_worker_finished(self, success):
        self.set_app_running_state(False)
        if success:
            QMessageBox.information(self, "Job Completed", "The scheduled scripts completed successfully.")
        else:
            QMessageBox.warning(self, "Job Completed", "The script queue stopped due to an error or termination.")
        self.refresh_stats()

    # ------------------ PRESETS IMPLEMENTATION ------------------
    
    def run_daily_crawl_preset(self):
        # MJC -> MPU -> CTL (Incremental)
        # Override CRAWL_MODE to incremental
        scripts = [
            (os.path.join(TEST_DIR, "crawler_mjc.py"), ["--firebase"]),
            (os.path.join(TEST_DIR, "crawler_mpu.py"), []),
            (os.path.join(TEST_DIR, "crawler_ctl.py"), [])
        ]
        
        # Make sure we force incremental env
        self.run_scripts_list(scripts, task_label="Daily Incremental Crawl")

    def run_all_crawlers_full_preset(self):
        # MJC -> MPU -> CTL (Full)
        # Run MJC with full crawl mode env (will be passed via execution handler override)
        scripts = [
            (os.path.join(TEST_DIR, "crawler_mjc.py"), ["--firebase"]),
            (os.path.join(TEST_DIR, "crawler_mpu.py"), []),
            (os.path.join(TEST_DIR, "crawler_ctl.py"), [])
        ]
        
        # We need to override CRAWL_MODE=full
        env = self.get_env_dict()
        env["CRAWL_MODE"] = "full"
        
        if self.active_worker and self.active_worker.isRunning():
            QMessageBox.warning(self, "Warning", "A script is already running!")
            return

        self.set_app_running_state(True, "All Crawlers (Full)")
        self.active_worker = ScriptWorker(scripts, env, TEST_DIR)
        self.active_worker.log_signal.connect(self.log_append)
        self.active_worker.finished_signal.connect(self.on_worker_finished)
        self.active_worker.start()

    # ------------------ INDIVIDUAL PARAMETER RUNNERS ------------------

    def run_tag_backfill(self):
        script = os.path.join(TEST_DIR, "backfill_ai_tags.py")
        args = []
        
        if self.tag_dry_run.isChecked():
            args.append("--dry-run")
        if self.tag_force.isChecked():
            args.append("--force")
        
        source = self.tag_source.currentText()
        args.append(f"--source={source}")
        
        limit = self.tag_limit.text().strip()
        if limit.isdigit():
            args.append(f"--limit={limit}")
            
        if self.tag_use_lm.isChecked():
            args.append("--use-lmstudio")
            
        self.run_single_script(script, args)

    def run_body_backfill(self):
        script = os.path.join(TEST_DIR, "backfill_notice_body.py")
        args = []
        
        if self.body_dry_run.isChecked():
            args.append("--dry-run")
        if self.body_force.isChecked():
            args.append("--force")
        if self.body_use_gemini.isChecked():
            args.append("--use-gemini")
        if self.body_resummary_flagged.isChecked():
            args.append("--resummary-flagged")
        if self.body_reported.isChecked():
            args.append("--reported-only")
            
        mode = self.body_mode.currentText()
        if mode == "Body Only":
            args.append("--body-only")
        elif mode == "Summary Only":
            args.append("--summary-only")
            
        board = self.body_board.currentText()
        if board != "all":
            args.append(f"--board={board}")
            
        limit = self.body_limit.text().strip()
        if limit.isdigit():
            args.append(f"--limit={limit}")
            
        self.run_single_script(script, args)

    def run_local_crawler_test(self):
        script = os.path.join(TEST_DIR, "test_crawler_local.py")
        args = []
        if self.test_firebase.isChecked():
            args.append("--firebase")
            
        self.run_single_script(script, args)

    # ------------------ FIREBASE LIVE CALLS ------------------

    def send_push_notification(self):
        title = self.push_title.text().strip()
        body = self.push_body.toPlainText().strip()
        topic_mode = self.push_topic_combo.currentText()
        topic = self.push_custom_topic.text().strip() if topic_mode == "Custom Topic" else "all_notices"

        if not title or not body:
            QMessageBox.warning(self, "Invalid Inputs", "Title and Body contents cannot be empty!")
            return

        sa_path = self.get_resolved_service_account()
        if not os.path.exists(sa_path):
            QMessageBox.critical(self, "Missing Credentials", "Service Account JSON file could not be found.")
            return

        self.send_push_btn.setEnabled(False)
        self.status_text.setText("Broadcasting Notification...")
        
        self.fcm_worker = FcmSendWorker(sa_path, title, body, topic)
        self.fcm_worker.success_signal.connect(self.on_fcm_success)
        self.fcm_worker.error_signal.connect(self.on_fcm_error)
        self.fcm_worker.start()

    @Slot(str)
    def on_fcm_success(self, response_text):
        self.send_push_btn.setEnabled(True)
        self.status_text.setText(self.tr("Status: Idle"))
        QMessageBox.information(self, "Success", response_text)
        self.push_title.clear()
        self.push_body.clear()

    @Slot(str)
    def on_fcm_error(self, err_text):
        self.send_push_btn.setEnabled(True)
        self.status_text.setText(self.tr("Status: Idle"))
        QMessageBox.critical(self, "FCM Failed", err_text)

    def refresh_stats(self):
        if not FIREBASE_AVAILABLE:
            for board_id, labels in self.stats_labels.items():
                labels[0].setText("ERR")
                labels[1].setText("Module unavailable (firebase-admin missing)")
            return

        sa_path = self.get_resolved_service_account()
        if not os.path.exists(sa_path):
            for board_id, labels in self.stats_labels.items():
                labels[0].setText("ERR")
                labels[1].setText("Credentials missing (Configure key)")
            return

        self.status_text.setText("Loading live stats from Firestore...")
        self.stats_worker = StatsWorker(sa_path)
        self.stats_worker.stats_loaded_signal.connect(self.on_stats_loaded)
        self.stats_worker.error_signal.connect(self.on_stats_error)
        self.stats_worker.start()

    @Slot(dict)
    def on_stats_loaded(self, stats):
        self.status_text.setText(self.tr("Status: Idle"))
        for board_id, data in stats.items():
            if board_id in self.stats_labels:
                val_lbl, date_lbl, name_lbl = self.stats_labels[board_id]
                val_lbl.setText(f"{data['count']}")
                date_lbl.setText(f"Updated: {data['updated_at']}")

    @Slot(str)
    def on_stats_error(self, error_msg):
        self.status_text.setText(self.tr("Status: Idle"))
        print(f"Stats error: {error_msg}")
        for board_id, labels in self.stats_labels.items():
            labels[0].setText("ERR")
            labels[1].setText("Connection failed")


def main():
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
