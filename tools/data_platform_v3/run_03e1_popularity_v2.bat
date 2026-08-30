@echo off
setlocal
cd /d "%~dp0..\.."
echo ==========================================================
echo LINKBALL DATA PLATFORM V3 - STEP 03E.1
echo POPULARITY / RECOGNIZABILITY V2 - READ ONLY
echo ==========================================================
echo.
python tools\data_platform_v3\03e1_popularity_v2.py
if errorlevel 1 (
  echo.
  echo [ERROR] 03E.1 failed. Nothing in assets/data was modified.
  pause
  exit /b 1
)
echo.
echo [OK] Reports: reports\data_platform_v3\03e1
pause
