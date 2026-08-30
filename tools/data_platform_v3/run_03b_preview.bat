@echo off
setlocal
cd /d "%~dp0\..\.."
echo.
echo ================================================
echo  LINKBALL DATA PLATFORM V3 - STEP 03B PREVIEW
echo ================================================
echo.
where python >nul 2>&1
if %errorlevel% neq 0 (
  echo Python bulunamadi. Python 3 kurulu olmali.
  pause
  exit /b 1
)
python tools\data_platform_v3\preview_contract.py
if %errorlevel% neq 0 (
  echo.
  echo 03B basarisiz oldu. Yukaridaki hatayi gonder.
  pause
  exit /b 1
)
echo.
echo Tamamlandi: reports\data_platform_v3\03b\
echo Bu asama uygulama runtime verisini DEGISTIRMEZ.
echo.
pause
