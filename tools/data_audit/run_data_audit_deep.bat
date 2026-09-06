@echo off
setlocal
cd /d "%~dp0\..\.."
echo.
echo ==========================================
echo   Linkball Data Audit - Step 03A DEEP
ECHO ==========================================
echo Bu mod players.json + players_min.json karsilastirir ve daha fazla RAM kullanabilir.
echo.
where py >nul 2>nul
if %errorlevel%==0 (
  py -3 tools\data_audit\audit.py --deep
) else (
  python tools\data_audit\audit.py --deep
)
echo.
echo Rapor: reports\data_audit\latest\report.md
echo.
pause
