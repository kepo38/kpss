@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem Usage: call scripts\find-python.bat [ROOT]
rem On success: prints absolute python.exe path to stdout, exit 0
rem On failure: prints nothing, exit 1

set "FIND_ROOT=%~1"
if not defined FIND_ROOT set "FIND_ROOT=%CD%"

set "PY="

if exist "%FIND_ROOT%\venv\Scripts\python.exe" set "PY=%FIND_ROOT%\venv\Scripts\python.exe"
if not defined PY if exist "%FIND_ROOT%\.venv\Scripts\python.exe" set "PY=%FIND_ROOT%\.venv\Scripts\python.exe"
if not defined PY if exist "%FIND_ROOT%\backend\venv\Scripts\python.exe" set "PY=%FIND_ROOT%\backend\venv\Scripts\python.exe"

for %%V in (314 313 312 311 310 39 38) do (
  if not defined PY if exist "%LocalAppData%\Programs\Python\Python%%V\python.exe" (
    set "PY=%LocalAppData%\Programs\Python\Python%%V\python.exe"
  )
)

if not defined PY if exist "C:\Python314\python.exe" set "PY=C:\Python314\python.exe"
if not defined PY if exist "C:\Python313\python.exe" set "PY=C:\Python313\python.exe"
if not defined PY if exist "C:\Python312\python.exe" set "PY=C:\Python312\python.exe"
if not defined PY if exist "C:\Python311\python.exe" set "PY=C:\Python311\python.exe"

if not defined PY (
  where py >nul 2>&1
  if not errorlevel 1 (
    set "PY_TMP=%TEMP%\kpss_py_%RANDOM%%RANDOM%.txt"
    py -3 -c "import sys; print(sys.executable)" > "!PY_TMP!" 2>nul
    if exist "!PY_TMP!" (
      set /p PY=<"!PY_TMP!"
      del "!PY_TMP!" >nul 2>&1
    )
  )
)

if not defined PY (
  set "WHERE_TMP=%TEMP%\kpss_where_py_%RANDOM%%RANDOM%.txt"
  where python > "!WHERE_TMP!" 2>nul
  if exist "!WHERE_TMP!" (
    for /f "usebackq delims=" %%P in ("!WHERE_TMP!") do (
      if not defined PY (
        echo %%P | findstr /I "WindowsApps" >nul
        if errorlevel 1 set "PY=%%P"
      )
    )
    del "!WHERE_TMP!" >nul 2>&1
  )
)

if not defined PY (
  for /f "usebackq delims=" %%P in (`powershell -NoProfile -Command "foreach($v in 314,313,312,311,310){$p=Join-Path $env:LocalAppData ('Programs\Python\Python'+$v+'\python.exe'); if(Test-Path -LiteralPath $p){Write-Output $p; exit 0}}; if(Get-Command py -ErrorAction SilentlyContinue){$o=& py -3 -c 'import sys; print(sys.executable)' 2>$null; if($LASTEXITCODE -eq 0 -and $o){Write-Output $o.Trim(); exit 0}}; foreach($c in (Get-Command python -All -ErrorAction SilentlyContinue)){if($c.Source -notmatch 'WindowsApps'){Write-Output $c.Source; exit 0}}"`) do (
    if not defined PY set "PY=%%P"
  )
)

if defined PY (
  echo !PY!
  endlocal
  exit /b 0
)

endlocal
exit /b 1
