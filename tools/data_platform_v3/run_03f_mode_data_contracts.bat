@echo off
setlocal
cd /d "%~dp0..\.."
echo ==========================================================
echo LINKBALL DATA PLATFORM V3 - STEP 03F
echo GAME MODE DATA CONTRACTS + POOL PREVIEW - READ ONLY
echo ==========================================================
echo.
python tools\data_platform_v3\03f_mode_data_contracts.py
if errorlevel 1 (
  echo.
  echo [ERROR] 03F failed. Nothing in assets/data was modified.
  pause
  exit /b 1
)
echo.
echo [OK] Reports: reports\data_platform_v3\03f
pause
