@echo off
setlocal
cd /d "%~dp0\..\.."
echo.
echo ==============================================
echo  LINKBALL DATA PLATFORM V3 - STEP 03B.1
echo  PLAYER IDENTITY GUARD (READ-ONLY)
echo ==============================================
echo.
where py >nul 2>nul
if %errorlevel%==0 (
  py -3 -u tools\data_platform_v3\03b1_player_identity_guard.py
) else (
  python -u tools\data_platform_v3\03b1_player_identity_guard.py
)
if errorlevel 1 (
  echo.
  echo [ERROR] Audit failed. Nothing in assets/data was modified.
  pause
  exit /b 1
)
echo.
echo Done. Send reports\data_platform_v3\03b1 as ZIP.
pause
