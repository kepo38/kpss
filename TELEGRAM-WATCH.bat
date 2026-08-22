@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul

set "AUTO=0"
set "HIDDEN=0"
if /i "%~1"=="/auto" set "AUTO=1"
if /i "%~2"=="__hidden__" set "HIDDEN=1"

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "LOCK=%ROOT%\telegram_bot.lock"

rem /auto: gorunmez arka plan (cocuk oturumu / otomatik baslangic)
if "!AUTO!"=="1" if "!HIDDEN!"=="0" (
  if exist "%ROOT%\scripts\telegram-watch-hidden.vbs" (
    wscript.exe //B "%ROOT%\scripts\telegram-watch-hidden.vbs"
    exit /b 0
  )
  powershell -NoProfile -WindowStyle Hidden -Command "Start-Process -FilePath '%~f0' -ArgumentList '/auto','__hidden__' -WindowStyle Hidden"
  exit /b 0
)

if "!AUTO!"=="1" (
  title HEDEF Kamu - Telegram WATCH (otomatik)
  if not exist "%ROOT%\logs\" mkdir "%ROOT%\logs\" >nul 2>&1
  echo.>> "%ROOT%\logs\telegram-watch.log"
  echo ===== TELEGRAM-WATCH.bat /auto %DATE% %TIME% =====>> "%ROOT%\logs\telegram-watch.log"
) else (
  title HEDEF Kamu - Telegram (surekli dinleme)
)

if not exist "%ROOT%\backend\manage.py" (
  echo [HATA] Proje bulunamadi: %ROOT%\backend
  if "!AUTO!"=="0" pause
  exit /b 1
)

if exist "%LOCK%" (
  set "LOCKPID="
  for /f "usebackq delims=" %%P in ("%LOCK%") do set "LOCKPID=%%P"
  if defined LOCKPID (
    tasklist /FI "PID eq !LOCKPID!" 2>nul | find "!LOCKPID!" >nul
    if not errorlevel 1 (
      if "!AUTO!"=="1" (
        echo [BILGI] Telegram WATCH zaten calisiyor ^(PID !LOCKPID!^).>> "%ROOT%\logs\telegram-watch.log"
        exit /b 0
      )
      echo.
      echo [BILGI] Telegram zaten calisiyor ^(PID !LOCKPID!^).
      echo         Baska TELEGRAM-WATCH veya TELEGRAM.bat acik.
      echo.
      pause
      exit /b 1
    )
  )
  del "%LOCK%" 2>nul
)

cd /d "%ROOT%\backend"
if errorlevel 1 (
  echo [HATA] backend klasorune girilemedi.
  if "!AUTO!"=="0" pause
  exit /b 1
)

if "!AUTO!"=="0" (
  echo.
  echo  ========================================
  echo   Telegram WATCH — surekli dinleme
  echo  ========================================
  echo.
  echo   Bu pencere acik kaldigi surece fotograflar aninda islenir.
  echo   Django / panel ayri acik olmali.
  echo   Durdurmak: Ctrl+C
  echo   PC acilisinda otomatik (gizli): KUR-TELEGRAM-ZAMANLAYICI.bat
  echo.
)

set "PY="
if exist "%ROOT%\venv\Scripts\python.exe" set "PY=%ROOT%\venv\Scripts\python.exe"
if not defined PY if exist "%ROOT%\.venv\Scripts\python.exe" set "PY=%ROOT%\.venv\Scripts\python.exe"
if not defined PY if exist "%ROOT%\backend\venv\Scripts\python.exe" set "PY=%ROOT%\backend\venv\Scripts\python.exe"
if not defined PY if exist "%LocalAppData%\Programs\Python\Python314\python.exe" set "PY=%LocalAppData%\Programs\Python\Python314\python.exe"
if not defined PY if exist "%LocalAppData%\Programs\Python\Python313\python.exe" set "PY=%LocalAppData%\Programs\Python\Python313\python.exe"
if not defined PY if exist "%LocalAppData%\Programs\Python\Python312\python.exe" set "PY=%LocalAppData%\Programs\Python\Python312\python.exe"
if not defined PY (
  where py >nul 2>&1
  if not errorlevel 1 for /f "delims=" %%P in ('py -3 -c "import sys; print(sys.executable)" 2^>nul') do set "PY=%%P"
)
if not defined PY (
  for /f "delims=" %%P in ('where python 2^>nul') do (
    echo %%P | findstr /I "WindowsApps" >nul
    if errorlevel 1 if not defined PY set "PY=%%P"
  )
)
if not defined PY (
  echo [HATA] Python bulunamadi.
  if "!AUTO!"=="0" pause
  exit /b 1
)

if "!AUTO!"=="0" echo [.] Python: !PY!
if "!AUTO!"=="1" echo [.] Python: !PY!>> "%ROOT%\logs\telegram-watch.log"

if "!AUTO!"=="1" (
  "!PY!" manage.py migrate --noinput >> "%ROOT%\logs\telegram-watch.log" 2>&1
) else (
  "!PY!" manage.py migrate --noinput
)
if errorlevel 1 (
  echo [HATA] migrate basarisiz.
  if "!AUTO!"=="0" pause
  exit /b 1
)

if "!AUTO!"=="0" (
  echo [.] Surekli dinleme basliyor...
  echo.
  "!PY!" manage.py run_telegram_bot --watch
  set "RC=!ERRORLEVEL!"
) else (
  echo [.] Surekli dinleme basliyor...>> "%ROOT%\logs\telegram-watch.log"
  :watch_loop_auto
  "!PY!" manage.py run_telegram_bot --watch >> "%ROOT%\logs\telegram-watch.log" 2>&1
  set "RC=!ERRORLEVEL!"
  if "!RC!"=="0" exit /b 0
  echo [!] Bot durdu ^(kod !RC!^), 10 sn sonra yeniden baslatiliyor...>> "%ROOT%\logs\telegram-watch.log"
  timeout /t 10 /nobreak >nul
  goto watch_loop_auto
)
set "RC=!ERRORLEVEL!"

if not "!AUTO!"=="0" exit /b !RC!

echo.
if not "!RC!"=="0" echo [HATA] Cikis kodu !RC!
pause
exit /b !RC!
