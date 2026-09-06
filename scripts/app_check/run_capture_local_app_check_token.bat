@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0capture_local_app_check_token.ps1"
exit /b %errorlevel%
