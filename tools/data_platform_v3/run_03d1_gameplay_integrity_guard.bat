@echo off
setlocal
cd /d "%~dp0..\.."
echo ==========================================================
echo LINKBALL DATA PLATFORM V3 - STEP 03D.1
echo GAMEPLAY INTEGRITY GUARD - READ ONLY
echo ==========================================================
echo.
python tools\data_platform_v3\03d1_gameplay_integrity_guard.py
if errorlevel 1 (
  echo.
  echo [ERROR] 03D.1 failed. Nothing in assets/data was modified.
  pause
  exit /b 1
)
echo.
echo [OK] Reports: reports\data_platform_v3\03d1
pause
