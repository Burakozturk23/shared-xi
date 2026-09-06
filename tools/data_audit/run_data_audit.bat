@echo off
setlocal
cd /d "%~dp0\..\.."
echo.
echo ==========================================
echo   Linkball Data Audit - Step 03A
ECHO ==========================================
echo.
where py >nul 2>nul
if %errorlevel%==0 (
  py -3 tools\data_audit\audit.py
) else (
  python tools\data_audit\audit.py
)
echo.
echo Rapor: reports\data_audit\latest\report.md
echo.
pause
