@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul

set "AUTO=0"
set "HIDDEN=0"
if /i "%~1"=="/auto" set "AUTO=1"
if /i "%~1"=="/auto-hidden" (
  set "AUTO=1"
  set "HIDDEN=1"
)
if /i "%~2"=="__hidden__" set "HIDDEN=1"

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "LOCK=%ROOT%\telegram_bot.lock"
set "LOG=%ROOT%\logs\telegram-watch.log"
set "SAFEDEL=%ROOT%\scripts\safe-del.bat"

if "!AUTO!"=="1" if "!HIDDEN!"=="0" goto launch_hidden
goto after_hidden_launch

:launch_hidden
if exist "%ROOT%\scripts\telegram-watch-hidden.vbs" (
  wscript.exe //B "%ROOT%\scripts\telegram-watch-hidden.vbs"
  exit /b 0
)
start "HEDEF-TG-WATCH" /MIN cmd /c ""%~f0" /auto __hidden__"
exit /b 0

:after_hidden_launch
if not "!AUTO!"=="1" goto prep_interactive
title HEDEF Kamu - Telegram WATCH (otomatik)
if not exist "%ROOT%\logs" mkdir "%ROOT%\logs" >nul 2>&1
>>"%LOG%" echo(
>>"%LOG%" echo ===== TELEGRAM-WATCH.bat /auto %DATE% %TIME% =====
goto prep_common

:prep_interactive
title HEDEF Kamu - Telegram (surekli dinleme)

:prep_common
if not exist "%ROOT%\backend\manage.py" (
  call :logerr "Proje bulunamadi: %ROOT%\backend"
  exit /b 1
)

if exist "%LOCK%" (
  set "LOCKPID="
  for /f "usebackq delims=" %%P in ("%LOCK%") do set "LOCKPID=%%P"
  if defined LOCKPID (
    tasklist /FI "PID eq !LOCKPID!" 2>nul | find "!LOCKPID!" >nul
    if not errorlevel 1 (
      if "!AUTO!"=="1" (
        >>"%LOG%" echo [BILGI] Telegram WATCH zaten calisiyor PID !LOCKPID!
        exit /b 0
      )
      echo(
      echo [BILGI] Telegram zaten calisiyor - PID !LOCKPID!
      echo         Baska TELEGRAM-WATCH veya TELEGRAM.bat acik.
      echo(
      pause
      exit /b 1
    )
  )
  call "%SAFEDEL%" "%LOCK%"
)

cd /d "%ROOT%\backend"
if errorlevel 1 (
  call :logerr "backend klasorune girilemedi."
  exit /b 1
)

if "!AUTO!"=="1" goto find_python
echo(
echo  ========================================
echo   Telegram WATCH - surekli dinleme
echo  ========================================
echo(
echo   Bu pencere acik kaldigi surece fotograflar aninda islenir.
echo   Django / panel ayri acik olmali.
echo   Durdurmak: Ctrl+C
echo   PC acilisinda otomatik (gizli): KUR-TELEGRAM-ZAMANLAYICI.bat
echo(

:find_python
set "PY="
if exist "%ROOT%\venv\Scripts\python.exe" set "PY=%ROOT%\venv\Scripts\python.exe"
if not defined PY if exist "%ROOT%\.venv\Scripts\python.exe" set "PY=%ROOT%\.venv\Scripts\python.exe"
if not defined PY if exist "%ROOT%\backend\venv\Scripts\python.exe" set "PY=%ROOT%\backend\venv\Scripts\python.exe"
if not defined PY if exist "%LocalAppData%\Programs\Python\Python314\python.exe" set "PY=%LocalAppData%\Programs\Python\Python314\python.exe"
if not defined PY if exist "%LocalAppData%\Programs\Python\Python313\python.exe" set "PY=%LocalAppData%\Programs\Python\Python313\python.exe"
if not defined PY if exist "%LocalAppData%\Programs\Python\Python312\python.exe" set "PY=%LocalAppData%\Programs\Python\Python312\python.exe"
if not defined PY (
  for /f "delims=" %%P in ('where python 2^>nul') do (
    echo %%P | findstr /I "WindowsApps" >nul
    if errorlevel 1 if not defined PY set "PY=%%P"
  )
)
if not defined PY (
  call :logerr "Python bulunamadi."
  exit /b 1
)

set "PYTHONUNBUFFERED=1"
if "!AUTO!"=="1" (
  >>"%LOG%" echo [.] Python: !PY!
) else (
  echo [.] Python: !PY!
)

if "!AUTO!"=="1" (
  "!PY!" manage.py migrate --noinput >>"%LOG%" 2>&1
) else (
  "!PY!" manage.py migrate --noinput
)
if errorlevel 1 (
  call :logerr "migrate basarisiz."
  exit /b 1
)

if "!AUTO!"=="0" goto watch_foreground
goto watch_auto

:watch_foreground
echo [.] Surekli dinleme basliyor...
echo(
"!PY!" manage.py run_telegram_bot --watch
set "RC=!ERRORLEVEL!"
echo(
if not "!RC!"=="0" echo [HATA] Cikis kodu !RC!
pause
exit /b !RC!

:watch_auto
>>"%LOG%" echo [.] Surekli dinleme basliyor...
:watch_loop_auto
"!PY!" -u manage.py run_telegram_bot --watch >>"%LOG%" 2>&1
set "RC=!ERRORLEVEL!"
if "!RC!"=="0" exit /b 0
>>"%LOG%" echo [UYARI] Bot durdu kod !RC!, 10 sn sonra yeniden...
ping -n 11 127.0.0.1 >nul
goto watch_loop_auto

:logerr
if "!AUTO!"=="1" (
  >>"%LOG%" echo [HATA] %~1
) else (
  echo [HATA] %~1
  pause
)
goto :eof
