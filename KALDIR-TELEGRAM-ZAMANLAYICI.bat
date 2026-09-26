@echo off
chcp 65001 >nul
title HEDEF Kamu - Telegram Zamanlayici Kaldir

set "PS1=D:\HEDEFKAMU\scripts\register-telegram-scheduled-task.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Unregister
echo.
pause
