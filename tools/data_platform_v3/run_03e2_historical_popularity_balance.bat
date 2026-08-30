@echo off
setlocal
cd /d "%~dp0..\.."
echo ==========================================================
echo LINKBALL DATA PLATFORM V3 - STEP 03E.2
echo HISTORICAL POPULARITY BALANCE - READ ONLY
echo ==========================================================
echo.
python tools\data_platform_v3\03e2_historical_popularity_balance.py
if errorlevel 1 (
  echo.
  echo [ERROR] 03E.2 failed. Nothing in assets/data was modified.
  pause
  exit /b 1
)
echo.
echo [OK] Reports: reports\data_platform_v3\03e2
pause
