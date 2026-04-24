@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..\..") do set "REPO_ROOT=%%~fI"
set "BASELINE=%~1"
set "CANDIDATE=%~2"
set "AVG=%~3"
set "P95=%~4"
set "MAX=%~5"

if "%BASELINE%"=="" set "BASELINE=%REPO_ROOT%\perf\baseline.quick.json"
if "%CANDIDATE%"=="" set "CANDIDATE=%REPO_ROOT%\perf\candidate.quick.json"
if "%AVG%"=="" set "AVG=8"
if "%P95%"=="" set "P95=12"
if "%MAX%"=="" set "MAX=15"

call :ResolvePath BASELINE
call :ResolvePath CANDIDATE

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%compare-baseline.ps1" ^
  -BaselinePath "%BASELINE%" ^
  -CandidatePath "%CANDIDATE%" ^
  -AvgRegressionPct %AVG% ^
  -P95RegressionPct %P95% ^
  -MaxRegressionPct %MAX%

exit /b %errorlevel%

:ResolvePath
setlocal enabledelayedexpansion
call set "INPUT=%%%~1%%"
if not defined INPUT (
  endlocal & exit /b 0
)
if "!INPUT:~1,1!"==":" (
  endlocal & set "%~1=%INPUT%" & exit /b 0
)
if "!INPUT:~0,2!"=="\\" (
  endlocal & set "%~1=%INPUT%" & exit /b 0
)
for %%P in ("%REPO_ROOT%\!INPUT!") do (
  endlocal
  set "%~1=%%~fP"
)
exit /b 0
