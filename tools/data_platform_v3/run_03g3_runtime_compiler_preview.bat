@echo off
setlocal
cd /d "%~dp0..\.."
echo ==========================================================
echo LINKBALL DATA PLATFORM V3 - STEP 03G.3
echo FINAL DATA QA + RUNTIME SQLITE COMPILER PREVIEW
echo ==========================================================
echo.
python tools\data_platform_v3\03g3_runtime_compiler_preview.py
if errorlevel 1 (
  echo.
  echo [ERROR] 03G.3 failed. Nothing in assets/data was modified.
  pause
  exit /b 1
)
echo.
echo [OK] Reports: reports\data_platform_v3\03g3
pause
