@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title HEDEF Kamu - Telegram WATCH Baslat

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "LOCK=%ROOT%\telegram_bot.lock"
set "LOG=%ROOT%\logs\telegram-watch.log"
set "SAFELOG=%ROOT%\logs\safety.log"
set "WATCH=%ROOT%\TELEGRAM-WATCH.bat"
set "SAFEDEL=%ROOT%\scripts\safe-del.bat"

if not exist "%ROOT%\logs" mkdir "%ROOT%\logs" >nul 2>&1
>>"%SAFELOG%" echo ===== BASLAT-WATCH %DATE% %TIME% ROOT=%ROOT% =====

if not exist "%ROOT%\backend\manage.py" (
  echo [HATA] Proje klasoru bulunamadi: %ROOT%
  >>"%SAFELOG%" echo ERROR no manage.py
  pause
  exit /b 1
)

if not exist "%WATCH%" (
  echo [HATA] TELEGRAM-WATCH.bat yok - DOSYA-DURUM.bat / GERI-YUKLE-KRITIK.bat
  >>"%SAFELOG%" echo ERROR missing TELEGRAM-WATCH.bat
  pause
  exit /b 1
)

if exist "%LOCK%" (
  set "LOCKPID="
  for /f "usebackq delims=" %%P in ("%LOCK%") do set "LOCKPID=%%P"
  if defined LOCKPID (
    tasklist /FI "PID eq !LOCKPID!" 2>nul | find "!LOCKPID!" >nul
    if not errorlevel 1 (
      echo(
      echo  [OK] Telegram bot ZATEN calisiyor.
      echo       PID: !LOCKPID!
      echo       Log: %LOG%
      echo(
      echo  Durdurmak icin: DURDUR-TELEGRAM-WATCH.bat
      echo(
      >>"%SAFELOG%" echo already-running PID=!LOCKPID!
      pause
      exit /b 0
    )
  )
  call "%SAFEDEL%" "%LOCK%"
)

echo(
echo  Telegram bot baslatiliyor - gorev cubugunda minimize pencere...
echo(
>>"%SAFELOG%" echo starting WATCH minimized

start "HEDEF-TG-WATCH" /MIN "%WATCH%"

set "WAIT=0"
:wait_loop
ping -n 3 127.0.0.1 >nul
set /a WAIT+=1
if exist "%LOCK%" goto started
if !WAIT! LSS 25 goto wait_loop

echo  [UYARI] Lock olusmadi. Log:
if exist "%LOG%" powershell -NoProfile -Command "Get-Content -LiteralPath '%LOG%' -Tail 12 -ErrorAction SilentlyContinue"
echo(
echo  Elle: TELEGRAM-WATCH.bat  -  Durum: DOSYA-DURUM.bat
>>"%SAFELOG%" echo WARN lock-timeout
pause
exit /b 1

:started
for /f "usebackq delims=" %%P in ("%LOCK%") do set "LOCKPID=%%P"
echo  [OK] Bot basladi. PID: !LOCKPID!
echo  Log: %LOG%
echo  Safety: %SAFELOG%
echo(
echo  Telegram: /durum
echo  Durdurmak: DURDUR-TELEGRAM-WATCH.bat
echo(
>>"%SAFELOG%" echo started PID=!LOCKPID!
pause
exit /b 0
