@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title HEDEF Kamu - Telegram WATCH Baslat

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "LOCK=%ROOT%\telegram_bot.lock"
set "LOG=%ROOT%\logs\telegram-watch.log"

if not exist "%ROOT%\backend\manage.py" (
  echo [HATA] Proje klasoru bulunamadi: %ROOT%
  pause
  exit /b 1
)

if not exist "%ROOT%\logs\" mkdir "%ROOT%\logs\" >nul 2>&1

if exist "%LOCK%" (
  set "LOCKPID="
  for /f "usebackq delims=" %%P in ("%LOCK%") do set "LOCKPID=%%P"
  if defined LOCKPID (
    tasklist /FI "PID eq !LOCKPID!" 2>nul | find "!LOCKPID!" >nul
    if not errorlevel 1 (
      echo.
      echo  [OK] Telegram bot ZATEN calisiyor.
      echo       PID: !LOCKPID!
      echo       Log: %LOG%
      echo.
      echo  Durdurmak icin: DURDUR-TELEGRAM-WATCH.bat
      echo.
      pause
      exit /b 0
    )
  )
  del "%LOCK%" 2>nul
)

echo.
echo  Telegram bot arka planda baslatiliyor...
echo  (Pencere acilmaz — bu normal.)
echo.

rem wscript yerine dogrudan bat — antivirus / PowerShell sorunu olmaz
start "" /MIN cmd /c ""%ROOT%\TELEGRAM-WATCH.bat" /auto __hidden__"

set "WAIT=0"
:wait_loop
timeout /t 2 /nobreak >nul
set /a WAIT+=1
if exist "%LOCK%" goto started
if !WAIT! LSS 15 goto wait_loop

echo  [UYARI] 30 sn icinde bot lock dosyasi olusmadi.
echo  Log son satirlar:
if exist "%LOG%" powershell -NoProfile -Command "Get-Content -LiteralPath '%LOG%' -Tail 12"
echo.
echo  Alternatif: TELEGRAM-WATCH.bat dosyasina cift tiklayin (gorunur pencere).
pause
exit /b 1

:started
for /f "usebackq delims=" %%P in ("%LOCK%") do set "LOCKPID=%%P"
echo  [OK] Bot basladi. PID: !LOCKPID!
echo  Log: %LOG%
echo.
echo  Telegram'dan /durum yazarak test edebilirsiniz.
echo  Durdurmak: DURDUR-TELEGRAM-WATCH.bat
echo.
pause
exit /b 0
