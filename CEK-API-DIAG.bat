@echo off
setlocal EnableExtensions
chcp 65001 >nul
title KPSS Odak - API teshis logu

set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if not exist "%ADB%" (
  where adb >nul 2>&1
  if errorlevel 1 (
    echo [HATA] adb bulunamadi.
    pause
    exit /b 1
  )
  set "ADB=adb"
)

set "PKG=com.hedefkamu.hedef_kamu"
set "OUT=%~dp0logs\api-diag-from-phone.txt"
if not exist "%~dp0logs" mkdir "%~dp0logs" >nul 2>&1

echo.
echo  Telefon api-diag.log cekiliyor...
echo  Paket: %PKG%
echo.

"%ADB%" devices
echo.

rem Debug build: run-as ile app documents
"%ADB%" shell "run-as %PKG% cat app_flutter/logs/api-diag.log 2>/dev/null" > "%OUT%"
if errorlevel 1 goto try_alt
for %%A in ("%OUT%") do if %%~zA GTR 0 goto show

:try_alt
"%ADB%" shell "run-as %PKG% cat files/logs/api-diag.log 2>/dev/null" > "%OUT%"
for %%A in ("%OUT%") do if %%~zA GTR 0 goto show

echo [!] Log bos veya run-as okuyamadi.
echo     Uygulamayi bir kez acip senkron denensin; sonra tekrar calistirin.
echo     Cikti: %OUT%
pause
exit /b 1

:show
echo [OK] Kaydedildi: %OUT%
echo ------------------------------------------------------------
type "%OUT%"
echo ------------------------------------------------------------
echo.
echo Son satirlar yukarida. Timeout / unreachable = Wi-Fi veya USB reverse.
pause
exit /b 0
