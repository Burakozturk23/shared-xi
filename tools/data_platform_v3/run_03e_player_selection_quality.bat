@echo off
setlocal
cd /d "%~dp0..\.."
echo ==========================================================
echo LINKBALL DATA PLATFORM V3 - STEP 03E
echo PLAYER SELECTION QUALITY / POPULARITY SEED - READ ONLY
echo ==========================================================
echo.
python tools\data_platform_v3\03e_player_selection_quality.py
if errorlevel 1 (
  echo.
  echo [ERROR] 03E failed. Nothing in assets/data was modified.
  pause
  exit /b 1
)
echo.
echo [OK] Reports: reports\data_platform_v3\03e
pause
