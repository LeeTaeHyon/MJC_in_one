import os
import sys
import json
import subprocess
import traceback
from datetime import datetime

from PySide6.QtCore import Qt, QSize, QThread, Signal, Slot
from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QPushButton, QLineEdit, QCheckBox, QComboBox, QTextEdit,
    QStackedWidget, QFileDialog, QFormLayout, QScrollArea, QFrame,
    QPlainTextEdit, QMessageBox, QGroupBox, QSplitter
)
from PySide6.QtGui import QColor, QFont, QTextCursor

# Paths
APP_DIR = os.path.dirname(os.path.abspath(__file__))
# APP_DIR is .../tools/upload/guiapp
TOOLS_UPLOAD_DIR = os.path.dirname(APP_DIR) # .../tools/upload

class DropLineEdit(QLineEdit):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setAcceptDrops(True)
        self.setPlaceholderText("Drag and drop a file here, or click to browse...")

    def dragEnterEvent(self, event):
        if event.mimeData().hasUrls():
            event.accept()
        else:
            event.ignore()

    def dropEvent(self, event):
        if event.mimeData().hasUrls():
            urls = event.mimeData().urls()
            if urls:
                # Use the first dropped file
                file_path = urls[0].toLocalFile()
                self.setText(file_path)
            event.accept()
        else:
            event.ignore()

    def mousePressEvent(self, event):
        super().mousePressEvent(event)
        # Check if right click to maybe clear or just standard click
        if event.button() == Qt.LeftButton and not self.text():
            file_path, _ = QFileDialog.getOpenFileName(self, "Select File", "", "All Files (*)")
            if file_path:
                self.setText(file_path)


class ScriptWorker(QThread):
    log_signal = Signal(str)
    finished_signal = Signal(bool)
    
    def __init__(self, script_path: str, args: list[str], env: dict, cwd: str):
        super().__init__()
        self.script_path = script_path
        self.args = args
        self.env = env
        self.cwd = cwd
        self.process = None
        self.is_killed = False

    def run(self):
        if self.is_killed:
            return
        
        script_name = os.path.basename(self.script_path)
        self.log_signal.emit(f"\n========================================\n")
        self.log_signal.emit(f"🚀 Running: {script_name} {' '.join(self.args)}\n")
        self.log_signal.emit(f"========================================\n\n")
        
        python_bin = sys.executable
        cmd = [python_bin, self.script_path] + self.args
        
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
            
            while True:
                line = self.process.stdout.readline()
                if not line and self.process.poll() is not None:
                    break
                if line:
                    self.log_signal.emit(line)
            
            rc = self.process.wait()
            if rc == 0:
                self.log_signal.emit(f"\n✅ Completed: {script_name}\n")
                self.finished_signal.emit(True)
            else:
                if self.is_killed:
                    self.log_signal.emit(f"\n⏹️ Stopped by user: {script_name}\n")
                else:
                    self.log_signal.emit(f"\n❌ Failed with return code {rc}: {script_name}\n")
                self.finished_signal.emit(False)
                    
        except Exception as e:
            self.log_signal.emit(f"\n❌ Error executing script {script_name}: {str(e)}\n")
            self.finished_signal.emit(False)

    def terminate_process(self):
        self.is_killed = True
        if self.process:
            self.process.terminate()
            try:
                self.process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.process.kill()


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.config = {}
        self.active_worker = None
        self.load_config()

        self.setWindowTitle("Upload Manager Console")
        self.resize(1100, 750)
        
        self.init_ui()

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
            "firebase_project": "mjc-one"
        }

    def save_config(self):
        config_path = os.path.join(APP_DIR, "config.json")
        try:
            with open(config_path, "w", encoding="utf-8") as f:
                json.dump(self.config, f, indent=2, ensure_ascii=False)
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to save config.json: {e}")

    def get_env_dict(self):
        env = {}
        env["FIREBASE_PROJECT_ID"] = self.config.get("firebase_project", "mjc-one")
        return env

    def init_ui(self):
        # Set dark theme stylesheet matching MJC Manager App
        self.setStyleSheet("""
            QMainWindow {
                background-color: #0A0A0A;
            }
            QWidget {
                font-family: "Segoe UI", "Pretendard", "Arial";
                color: #E6FFFFFF;
            }
            QFrame#Sidebar {
                background-color: #16181C;
                border-right: 1px solid #2A2A2D;
            }
            QLabel#Title {
                font-size: 16px;
                font-weight: bold;
                color: #5B8CFF;
            }
            QLabel#SubTitle {
                font-size: 12px;
                color: #9CA3AF;
            }
            QPushButton {
                background-color: #20242B;
                border: 1px solid #2A2A2D;
                border-radius: 8px;
                padding: 10px 18px;
                font-weight: bold;
                font-size: 13px;
            }
            QPushButton:hover {
                background-color: #2D323C;
            }
            QPushButton:pressed {
                background-color: #1A1D24;
            }
            QPushButton#Primary {
                background-color: #5B8CFF;
                color: #0A0A0A;
                border: none;
            }
            QPushButton#Primary:hover {
                background-color: #7AA2FF;
            }
            QPushButton#Primary:pressed {
                background-color: #4C7CE6;
            }
            QPushButton#Danger {
                background-color: #FF6B7A;
                color: #0A0A0A;
                border: none;
            }
            QPushButton#SidebarBtn {
                text-align: left;
                background-color: transparent;
                border: none;
                border-radius: 6px;
                padding: 12px 16px;
                font-size: 14px;
                color: #9CA3AF;
            }
            QPushButton#SidebarBtn:hover {
                background-color: #20242B;
                color: #E6FFFFFF;
            }
            QPushButton#SidebarBtn:checked {
                background-color: #20242B;
                color: #5B8CFF;
                font-weight: bold;
            }
            QLineEdit, QComboBox, QSpinBox {
                background-color: #20242B;
                border: 1px solid #2A2A2D;
                border-radius: 6px;
                padding: 8px;
                color: #E6FFFFFF;
                font-size: 13px;
            }
            QLineEdit:focus, QComboBox:focus {
                border: 1px solid #5B8CFF;
            }
            QPlainTextEdit#ConsoleLog {
                background-color: #16181C;
                border: 1px solid #2A2A2D;
                border-radius: 8px;
                font-family: "Consolas", "Courier New", monospace;
                font-size: 12px;
                color: #E5E7EB;
            }
            QGroupBox {
                border: 1px solid #2A2A2D;
                border-radius: 8px;
                margin-top: 12px;
                font-weight: bold;
                font-size: 13px;
            }
            QGroupBox::title {
                subcontrol-origin: margin;
                left: 10px;
                padding: 0 5px;
                color: #5B8CFF;
            }
            QScrollArea {
                background-color: #0A0A0A;
                border: none;
            }
            QScrollArea > QWidget > QWidget {
                background-color: #0A0A0A;
            }
            QCheckBox {
                background-color: transparent;
                color: #E6FFFFFF;
            }
        """)

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

        logo_label = QLabel("☁️ Upload Manager")
        logo_label.setStyleSheet("font-size: 20px; font-weight: 800; color: #5B8CFF; padding-bottom: 5px;")
        sub_logo = QLabel("Data Publishing Console")
        sub_logo.setStyleSheet("font-size: 11px; color: #9CA3AF; padding-bottom: 20px;")
        sidebar_layout.addWidget(logo_label)
        sidebar_layout.addWidget(sub_logo)

        self.nav_buttons = []
        nav_items = [
            ("🚀 Data Uploads", 0),
            ("⚙️ Settings", 1),
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
        main_layout.addWidget(sidebar)

        # ------------------ RIGHT WORK AREA ------------------
        right_panel = QWidget()
        right_layout = QVBoxLayout(right_panel)
        right_layout.setContentsMargins(20, 20, 20, 20)
        right_layout.setSpacing(15)

        splitter = QSplitter(Qt.Orientation.Vertical)
        
        self.stacked_widget = QStackedWidget()
        
        self.tab_uploads = self.create_uploads_tab()
        self.tab_settings = self.create_settings_tab()

        self.stacked_widget.addWidget(self.tab_uploads)
        self.stacked_widget.addWidget(self.tab_settings)
        splitter.addWidget(self.stacked_widget)

        # ------------------ CONSOLE ------------------
        console_widget = QWidget()
        console_layout = QVBoxLayout(console_widget)
        console_layout.setContentsMargins(0, 10, 0, 0)
        console_layout.setSpacing(8)

        console_header_layout = QHBoxLayout()
        console_title = QLabel("📄 Live Console Log")
        console_title.setObjectName("Title")
        console_header_layout.addWidget(console_title)
        console_header_layout.addStretch()

        clear_console_btn = QPushButton("Clear")
        clear_console_btn.clicked.connect(self.clear_console)
        clear_console_btn.setFixedWidth(80)
        clear_console_btn.setFixedHeight(30)
        clear_console_btn.setStyleSheet("padding: 2px; font-size: 11px;")
        console_header_layout.addWidget(clear_console_btn)

        self.stop_btn = QPushButton("Stop Execution")
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
        splitter.setSizes([450, 300])

        right_layout.addWidget(splitter)

        # Status Bar
        status_bar = QHBoxLayout()
        status_bar.setContentsMargins(0, 0, 0, 0)
        self.status_indicator = QLabel("●")
        self.status_indicator.setStyleSheet("color: #7f849c; font-size: 16px; margin-right: 5px;")
        self.status_text = QLabel("Status: Idle")
        self.status_text.setStyleSheet("color: #9CA3AF; font-size: 12px;")
        status_bar.addWidget(self.status_indicator)
        status_bar.addWidget(self.status_text)
        status_bar.addStretch()
        right_layout.addLayout(status_bar)

        main_layout.addWidget(right_panel)

    def switch_tab(self, index):
        for i, btn in enumerate(self.nav_buttons):
            btn.setChecked(i == index)
        self.stacked_widget.setCurrentIndex(index)

    def create_uploads_tab(self):
        widget = QScrollArea()
        widget.setWidgetResizable(True)
        widget.setFrameShape(QFrame.Shape.NoFrame)
        
        content = QWidget()
        layout = QVBoxLayout(content)
        layout.setContentsMargins(0, 0, 10, 0)
        layout.setSpacing(15)

        title = QLabel("🚀 Data Uploads")
        title.setObjectName("Title")
        sub = QLabel("Run upload scripts to publish data to Firestore. Drag and drop files to populate path inputs.")
        sub.setObjectName("SubTitle")
        layout.addWidget(title)
        layout.addWidget(sub)

        # General / Config Data Group
        cfg_group = QGroupBox("Configuration Data (Campus, Departments)")
        cfg_layout = QFormLayout(cfg_group)
        cfg_layout.setContentsMargins(15, 15, 15, 15)
        
        self.cfg_dry_run = QCheckBox("Dry Run (Preview changes without uploading)")
        self.cfg_dry_run.setChecked(True)
        self.cfg_validate = QCheckBox("Validate Only (Parse and check format, no upload)")
        
        cfg_layout.addRow(self.cfg_dry_run, self.cfg_validate)
        
        btn_campus = QPushButton("Upload Campus Map (upload_campus.py)")
        btn_campus.clicked.connect(lambda: self.run_script("upload_campus.py", [self.cfg_dry_run, self.cfg_validate]))
        
        btn_depts = QPushButton("Upload Departments (upload_departments.py)")
        btn_depts.clicked.connect(lambda: self.run_script("upload_departments.py", [self.cfg_dry_run, self.cfg_validate]))
        
        btn_slugs = QPushButton("Upload Department Slugs (upload_department_slugs.py)")
        btn_slugs.clicked.connect(lambda: self.run_script("upload_department_slugs.py", [self.cfg_dry_run, self.cfg_validate]))
        
        cfg_btns = QHBoxLayout()
        cfg_btns.addWidget(btn_campus)
        cfg_btns.addWidget(btn_depts)
        cfg_btns.addWidget(btn_slugs)
        cfg_layout.addRow("Run Scripts:", cfg_btns)
        layout.addWidget(cfg_group)

        # Timetable Group
        tt_group = QGroupBox("Official Timetable (upload_timetable.py)")
        tt_layout = QFormLayout(tt_group)
        tt_layout.setContentsMargins(15, 15, 15, 15)
        
        self.tt_file_input = DropLineEdit()
        tt_layout.addRow("CSV Path:", self.tt_file_input)
        
        self.tt_dry_run = QCheckBox("Dry Run")
        self.tt_dry_run.setChecked(True)
        self.tt_validate = QCheckBox("Validate Only")
        self.tt_replace = QCheckBox("Replace (Delete all existing docs first)")
        
        tt_opts = QHBoxLayout()
        tt_opts.addWidget(self.tt_dry_run)
        tt_opts.addWidget(self.tt_validate)
        tt_opts.addWidget(self.tt_replace)
        tt_layout.addRow("Options:", tt_opts)
        
        btn_tt = QPushButton("Upload Timetable")
        btn_tt.setObjectName("Primary")
        btn_tt.clicked.connect(self.run_timetable)
        tt_layout.addRow("", btn_tt)
        layout.addWidget(tt_group)

        # Foodcourt & Shuttle Group
        fs_group = QGroupBox("Foodcourt & Shuttle")
        fs_layout = QFormLayout(fs_group)
        fs_layout.setContentsMargins(15, 15, 15, 15)
        
        self.fs_file_input = DropLineEdit()
        fs_layout.addRow("CSV/Data Path:", self.fs_file_input)
        
        self.fs_dry_run = QCheckBox("Dry Run")
        self.fs_dry_run.setChecked(True)
        self.fs_validate = QCheckBox("Validate Only")
        self.fs_prune = QCheckBox("Prune Missing (Delete docs not in CSV) [Foodcourt only]")
        
        fs_opts = QHBoxLayout()
        fs_opts.addWidget(self.fs_dry_run)
        fs_opts.addWidget(self.fs_validate)
        fs_opts.addWidget(self.fs_prune)
        fs_layout.addRow("Options:", fs_opts)
        
        btn_food = QPushButton("Upload Foodcourt")
        btn_food.clicked.connect(self.run_foodcourt)
        
        btn_shuttle = QPushButton("Upload Shuttle")
        btn_shuttle.clicked.connect(self.run_shuttle)
        
        fs_btns = QHBoxLayout()
        fs_btns.addWidget(btn_food)
        fs_btns.addWidget(btn_shuttle)
        fs_layout.addRow("", fs_btns)
        layout.addWidget(fs_group)

        # Others Group
        oth_group = QGroupBox("Other Utilities")
        oth_layout = QVBoxLayout(oth_group)
        oth_layout.setContentsMargins(15, 15, 15, 15)
        
        btn_seed = QPushButton("Seed Community Boards (seed_community_boards.py)")
        btn_seed.clicked.connect(lambda: self.run_script("seed_community_boards.py", []))
        
        btn_sync = QPushButton("Sync From Local (sync_from_local.py)")
        btn_sync.clicked.connect(lambda: self.run_script("sync_from_local.py", []))
        
        oth_btns = QHBoxLayout()
        oth_btns.addWidget(btn_seed)
        oth_btns.addWidget(btn_sync)
        oth_layout.addLayout(oth_btns)
        layout.addWidget(oth_group)

        layout.addStretch()
        widget.setWidget(content)
        return widget

    def create_settings_tab(self):
        widget = QWidget()
        layout = QVBoxLayout(widget)
        layout.setContentsMargins(0, 0, 10, 0)
        
        title = QLabel("⚙️ Settings")
        title.setObjectName("Title")
        layout.addWidget(title)
        
        group = QGroupBox("Environment Variables")
        form = QFormLayout(group)
        
        self.fb_project_input = QLineEdit(self.config.get("firebase_project", "mjc-one"))
        form.addRow("FIREBASE_PROJECT_ID:", self.fb_project_input)
        
        save_btn = QPushButton("Save Settings")
        save_btn.setObjectName("Primary")
        save_btn.clicked.connect(self.save_settings_ui)
        form.addRow("", save_btn)
        
        layout.addWidget(group)
        layout.addStretch()
        return widget

    def save_settings_ui(self):
        self.config["firebase_project"] = self.fb_project_input.text().strip()
        self.save_config()
        QMessageBox.information(self, "Settings", "Settings saved successfully.")

    def run_script(self, script_name: str, checkboxes: list):
        if self.active_worker and self.active_worker.isRunning():
            QMessageBox.warning(self, "Busy", "A script is already running.")
            return

        script_path = os.path.join(TOOLS_UPLOAD_DIR, script_name)
        if not os.path.exists(script_path):
            QMessageBox.critical(self, "Error", f"Script not found:\n{script_path}")
            return

        args = []
        for cb in checkboxes:
            if cb.isChecked():
                if "Dry Run" in cb.text():
                    args.append("--dry-run")
                elif "Validate Only" in cb.text():
                    args.append("--validate")
                elif "Replace" in cb.text():
                    args.append("--replace")
                elif "Prune Missing" in cb.text():
                    args.append("--prune-missing")

        self.start_worker(script_path, args)

    def run_timetable(self):
        script_path = os.path.join(TOOLS_UPLOAD_DIR, "upload_timetable.py")
        args = []
        path = self.tt_file_input.text().strip()
        if path:
            args.extend(["--path", path])
        
        if self.tt_dry_run.isChecked(): args.append("--dry-run")
        if self.tt_validate.isChecked(): args.append("--validate")
        if self.tt_replace.isChecked(): args.append("--replace")
        
        self.start_worker(script_path, args)

    def run_foodcourt(self):
        script_path = os.path.join(TOOLS_UPLOAD_DIR, "upload_foodcourt.py")
        args = []
        path = self.fs_file_input.text().strip()
        if path:
            args.extend(["--path", path])
        
        if self.fs_dry_run.isChecked(): args.append("--dry-run")
        if self.fs_validate.isChecked(): args.append("--validate")
        if self.fs_prune.isChecked(): args.append("--prune-missing")
        
        self.start_worker(script_path, args)

    def run_shuttle(self):
        script_path = os.path.join(TOOLS_UPLOAD_DIR, "upload_shuttle.py")
        args = []
        path = self.fs_file_input.text().strip()
        if path:
            args.extend(["--path", path])
        
        if self.fs_dry_run.isChecked(): args.append("--dry-run")
        if self.fs_validate.isChecked(): args.append("--validate")
        
        self.start_worker(script_path, args)

    def start_worker(self, script_path, args):
        if self.active_worker and self.active_worker.isRunning():
            return
            
        env = self.get_env_dict()
        self.active_worker = ScriptWorker(script_path, args, env, cwd=TOOLS_UPLOAD_DIR)
        self.active_worker.log_signal.connect(self.append_log)
        self.active_worker.finished_signal.connect(self.on_worker_finished)
        
        self.status_text.setText(f"Status: Running {os.path.basename(script_path)}...")
        self.status_indicator.setStyleSheet("color: #4CAF50; font-size: 16px; margin-right: 5px;")
        self.stop_btn.setEnabled(True)
        
        self.active_worker.start()

    def stop_current_job(self):
        if self.active_worker and self.active_worker.isRunning():
            self.append_log("\n🛑 Stopping process...\n")
            self.active_worker.terminate_process()

    def on_worker_finished(self, success):
        self.status_text.setText("Status: Idle")
        self.status_indicator.setStyleSheet("color: #7f849c; font-size: 16px; margin-right: 5px;")
        self.stop_btn.setEnabled(False)

    def append_log(self, text):
        self.console.moveCursor(QTextCursor.MoveOperation.End)
        self.console.insertPlainText(text)
        self.console.moveCursor(QTextCursor.MoveOperation.End)

    def clear_console(self):
        self.console.clear()


if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec())
