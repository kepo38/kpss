@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title HEDEF Kamu - Telegram WATCH Durdur

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "LOCK=%ROOT%\telegram_bot.lock"
set "SAFELOG=%ROOT%\logs\safety.log"
set "SAFEDEL=%ROOT%\scripts\safe-del.bat"

if not exist "%ROOT%\logs" mkdir "%ROOT%\logs" >nul 2>&1
>>"%SAFELOG%" echo ===== DURDUR-WATCH %DATE% %TIME% =====

if not exist "%LOCK%" (
  echo Telegram bot calismiyor - lock yok.
  >>"%SAFELOG%" echo stop: no lock
  pause
  exit /b 0
)

set "LOCKPID="
for /f "usebackq delims=" %%P in ("%LOCK%") do set "LOCKPID=%%P"
if not defined LOCKPID (
  call "%SAFEDEL%" "%LOCK%"
  echo Gecersiz lock silindi.
  >>"%SAFELOG%" echo stop: invalid lock removed
  pause
  exit /b 0
)

taskkill /PID !LOCKPID! /F >nul 2>&1
call "%SAFEDEL%" "%LOCK%"
echo Bot durduruldu - PID !LOCKPID!
>>"%SAFELOG%" echo stop: killed PID=!LOCKPID!
pause
exit /b 0
