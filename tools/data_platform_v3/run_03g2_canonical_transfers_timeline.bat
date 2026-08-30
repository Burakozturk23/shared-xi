@echo off
setlocal
cd /d "%~dp0..\.."
echo ==========================================================
echo LINKBALL DATA PLATFORM V3 - STEP 03G.2
echo CANONICAL TRANSFERS + CAREER TIMELINE - READ ONLY
echo ==========================================================
echo.
python tools\data_platform_v3\03g2_canonical_transfers_timeline.py
if errorlevel 1 (
  echo.
  echo [ERROR] 03G.2 failed. Nothing in assets/data was modified.
  pause
  exit /b 1
)
echo.
echo [OK] Reports: reports\data_platform_v3\03g2
pause
