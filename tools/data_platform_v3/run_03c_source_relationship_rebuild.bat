@echo off
setlocal
cd /d "%~dp0\..\.."
echo.
echo ==============================================
echo  LINKBALL DATA PLATFORM V3 - STEP 03C
echo  TRUSTED CAREER + CLUB SOURCE RESOLVER
echo  READ-ONLY
echo ==============================================
echo.
where py >nul 2>nul
if %errorlevel%==0 (
  py -3 -u tools\data_platform_v3\03c_source_relationship_rebuild.py
) else (
  python -u tools\data_platform_v3\03c_source_relationship_rebuild.py
)
if errorlevel 1 (
  echo.
  echo [ERROR] 03C failed. Nothing in assets/data was modified.
  echo Check that transfermarkt-datasets-csv.zip exists under:
  echo tools\data_platform_v3\input\
  pause
  exit /b 1
)
echo.
echo Done. Zip reports\data_platform_v3\03c and send it back.
pause
