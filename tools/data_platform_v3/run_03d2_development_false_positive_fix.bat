@echo off
setlocal
cd /d "%~dp0..\.."
echo ==========================================================
echo LINKBALL DATA PLATFORM V3 - STEP 03D.2
echo DEVELOPMENT FALSE-POSITIVE FIX - READ ONLY
echo ==========================================================
echo.
python tools\data_platform_v3\03d2_development_false_positive_fix.py
if errorlevel 1 (
  echo.
  echo [ERROR] 03D.2 failed. Nothing in assets/data was modified.
  pause
  exit /b 1
)
echo.
echo [OK] Reports: reports\data_platform_v3\03d2
pause
