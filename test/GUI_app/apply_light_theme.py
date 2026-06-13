import sys

qss_light = """            QMainWindow {
                background-color: #FFFFFF;
            }
            QWidget {
                font-family: "Segoe UI", "Pretendard", "Apple SD Gothic Neo", "Arial";
                color: #333333;
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
            }
            QLabel#SubTitle {
                font-size: 13px;
                color: #666666;
            }
            QLabel#MutedLabel {
                color: #888888;
                font-size: 13px;
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
            }
            QGroupBox::title {
                subcontrol-origin: margin;
                subcontrol-position: top left;
                left: 15px;
                padding: 0 5px;
                color: #0078D4;
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
            }"""

import re

with open("g:/Mio/MJC_in_one/test/GUI_app/gui_manager.py", "r", encoding="utf-8") as f:
    content = f.read()

# Replace QSS Block
# The block starts with self.setStyleSheet(""" and ends with """)
start_idx = content.find('self.setStyleSheet("""')
end_idx = content.find('""")', start_idx) + 4
if start_idx != -1 and end_idx != -1:
    content = content[:start_idx] + 'self.setStyleSheet("""\n' + qss_light + '\n        """)' + content[end_idx:]

# Replace inline styles
replacements = {
    "#5B8CFF": "#0078D4",
    "#9CA3AF": "#666666",
    "#4CAF50": "#107C10",
    "#FF6B7A": "#D13438",
    "#7f849c": "#AAAAAA",
    "border: 1px solid #444444;": "border: 1px solid #CCCCCC;",
    "color: #FFFFFF;": "color: #333333;" # Only for lbl.setStyleSheet
}

for k, v in replacements.items():
    content = content.replace(k, v)

with open("g:/Mio/MJC_in_one/test/GUI_app/gui_manager.py", "w", encoding="utf-8") as f:
    f.write(content)

print("Applied Light Theme!")
