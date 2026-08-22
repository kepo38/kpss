@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title HEDEF Kamu - Telegram WATCH Durdur

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "LOCK=%ROOT%\telegram_bot.lock"

if not exist "%LOCK%" (
  echo Telegram bot calismiyor ^(lock dosyasi yok^).
  pause
  exit /b 0
)

set "LOCKPID="
for /f "usebackq delims=" %%P in ("%LOCK%") do set "LOCKPID=%%P"
if not defined LOCKPID (
  del "%LOCK%" 2>nul
  echo Gecersiz lock dosyasi silindi.
  pause
  exit /b 0
)

taskkill /PID !LOCKPID! /F >nul 2>&1
del "%LOCK%" 2>nul
echo Bot durduruldu ^(PID !LOCKPID!^).
pause
exit /b 0
