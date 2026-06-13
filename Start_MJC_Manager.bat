@echo off
cd /d "%~dp0test\GUI_app"

call venv311\Scripts\activate.bat

start "" pythonw gui_manager.py
