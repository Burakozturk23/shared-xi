@echo off
setlocal
cd /d "%~dp0\..\.."

echo ============================================================
echo LINKBALL DATA PLATFORM V3 - STEP 03D
echo CANONICAL CLUB + CAREER PREVIEW ^(READ-ONLY^)
echo ============================================================
echo.

where py >nul 2>nul
if %ERRORLEVEL%==0 (
  py -3 "tools\data_platform_v3\03d_canonical_career_preview.py"
) else (
  python "tools\data_platform_v3\03d_canonical_career_preview.py"
)

set RC=%ERRORLEVEL%
echo.
if not "%RC%"=="0" (
  echo [ERROR] 03D failed. Nothing in assets/data was modified.
) else (
  echo [OK] 03D finished.
  echo Send this folder back: reports\data_platform_v3\03d
)
echo.
pause
exit /b %RC%
