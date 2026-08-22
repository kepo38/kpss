@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul

title HEDEF Kamu - Telegram (surekli dinleme)

set "ROOT=D:\HEDEFKAMU"
set "LOCK=%ROOT%\telegram_bot.lock"

if not exist "%ROOT%\backend\manage.py" (
  echo [HATA] Proje bulunamadi: %ROOT%\backend
  pause
  exit /b 1
)

if exist "%LOCK%" (
  set "LOCKPID="
  for /f "usebackq delims=" %%P in ("%LOCK%") do set "LOCKPID=%%P"
  if defined LOCKPID (
    tasklist /FI "PID eq !LOCKPID!" 2>nul | find "!LOCKPID!" >nul
    if not errorlevel 1 (
      echo.
      echo [BILGI] Telegram zaten calisiyor ^(PID !LOCKPID!^).
      echo         TELEGRAM.bat veya baska WATCH penceresi acik.
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
  pause
  exit /b 1
)

echo.
echo  ========================================
echo   Telegram WATCH — surekli dinleme
echo  ========================================
echo.
echo   Bu pencere acik kaldigi surece ilettiginiz fotograflar
echo   aninda islenir ve panele duser.
echo   Django / panel ayri acik olmali; bu bat Telegram icindir.
echo   Durdurmak: Ctrl+C
echo.

set "PY="
if exist "%ROOT%\venv\Scripts\python.exe" set "PY=%ROOT%\venv\Scripts\python.exe"
if not defined PY if exist "%ROOT%\.venv\Scripts\python.exe" set "PY=%ROOT%\.venv\Scripts\python.exe"
if not defined PY if exist "%ROOT%\backend\venv\Scripts\python.exe" set "PY=%ROOT%\backend\venv\Scripts\python.exe"
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
  pause
  exit /b 1
)

echo [.] Python: !PY!
"!PY!" manage.py migrate --noinput
if errorlevel 1 (
  echo [HATA] migrate basarisiz.
  pause
  exit /b 1
)

echo [.] Surekli dinleme basliyor...
echo.
"!PY!" manage.py run_telegram_bot --watch
set "RC=!ERRORLEVEL!"
echo.
if not "!RC!"=="0" echo [HATA] Cikis kodu !RC!
pause
exit /b !RC!
