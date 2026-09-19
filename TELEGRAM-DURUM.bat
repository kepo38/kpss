@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title HEDEF Kamu - Telegram Durum

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "LOCK=%ROOT%\telegram_bot.lock"
set "LOG=%ROOT%\logs\telegram-watch.log"

echo.
if exist "%LOCK%" (
  set "LOCKPID="
  for /f "usebackq delims=" %%P in ("%LOCK%") do set "LOCKPID=%%P"
  tasklist /FI "PID eq !LOCKPID!" 2>nul | find "!LOCKPID!" >nul
  if not errorlevel 1 (
    echo  Bot: CALISIYOR  ^(PID !LOCKPID!^)
  ) else (
    echo  Bot: DURMUS  ^(eski lock — BASLAT-TELEGRAM-WATCH.bat^)
  )
) else (
  echo  Bot: CALISMIYOR  ^(BASLAT-TELEGRAM-WATCH.bat^)
)

echo  Log: %LOG%
echo.
if exist "%ROOT%\backend\manage.py" (
  cd /d "%ROOT%\backend"
  for /f "delims=" %%P in ('where py 2^>nul') do set "PY=%%P" & goto :diag
  set "PY=python"
  :diag
  py -3 manage.py run_telegram_bot --diagnose 2>nul
  if errorlevel 1 python manage.py run_telegram_bot --diagnose 2>nul
)
echo.
pause
