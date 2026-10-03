@echo off
setlocal EnableExtensions
chcp 65001 >nul
title HEDEF Kamu - Eski TelegramDrain kaldir

rem Yalnizca eski tek-seferlik gorevi siler.
rem Startup WATCH (surekli dinleme) dokunulmaz.

net session >nul 2>&1
if errorlevel 1 (
  echo Yonetici izni isteniyor...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b 0
)

echo.
echo  Eski gorev siliniyor: HEDEFKamu-TelegramDrain
echo  (TELEGRAM.bat /auto — tek seferlik kuyruk)
echo.
schtasks /Delete /TN "HEDEFKamu-TelegramDrain" /F
if errorlevel 1 (
  echo [OK] Gorev zaten yok veya silindi — ek islem gerekmez.
) else (
  echo [OK] HEDEFKamu-TelegramDrain kaldirildi.
)

echo.
echo  Startup WATCH kontrolu:
if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\HEDEFKamu-Telegram-Watch.bat" (
  echo  [OK] HEDEFKamu-Telegram-Watch.bat hala var — surekli dinleme aktif.
) else (
  echo  [UYARI] Startup WATCH yok. Yeniden kur: KUR-TELEGRAM-ZAMANLAYICI.bat
)
echo.
pause
exit /b 0
