@echo off
setlocal
cd /d "%~dp0..\.."
echo ==========================================================
echo LINKBALL DATA PLATFORM V3 - STEP 03G.1.2
echo CROSS-ID REMAP FALSE-POSITIVE GUARD - READ ONLY
echo ==========================================================
echo.
python tools\data_platform_v3\03g1_2_identity_remap_guard.py
if errorlevel 1 (
  echo.
  echo [ERROR] 03G.1.2 failed. Nothing in assets/data was modified.
  pause
  exit /b 1
)
echo.
echo [OK] Reports: reports\data_platform_v3\03g1_2
pause
