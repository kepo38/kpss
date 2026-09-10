@echo off
rem Guvenli tek-dosya silme. Joker ve klasor silme ENGELLENIR.
rem Kullanım: call "%~dp0safe-del.bat" "C:\path\file.lock"
setlocal EnableExtensions
set "TARGET=%~1"
set "ROOT=%~dp0.."
for %%I in ("%ROOT%") do set "ROOT=%%~fI"
set "SAFELOG=%ROOT%\logs\safety.log"

if not exist "%ROOT%\logs" mkdir "%ROOT%\logs" >nul 2>&1

if "%TARGET%"=="" (
  >>"%SAFELOG%" echo [%DATE% %TIME%] SAFE-DEL blocked: empty path
  exit /b 2
)

echo %TARGET%| findstr /R "[\*\?]" >nul
if not errorlevel 1 (
  >>"%SAFELOG%" echo [%DATE% %TIME%] SAFE-DEL blocked wildcard: %TARGET%
  echo [SAFETY] Joker silme engellendi: %TARGET%
  exit /b 3
)

rem Klasor silmeyi engelle
if exist "%TARGET%\" (
  >>"%SAFELOG%" echo [%DATE% %TIME%] SAFE-DEL blocked directory: %TARGET%
  echo [SAFETY] Klasor silme engellendi: %TARGET%
  exit /b 4
)

rem Sadece bilinen guvenli uzantilar / isimler
echo %TARGET%| findstr /I /E /C:"\telegram_bot.lock" /C:".tmp" /C:"\_tmp_" >nul
if errorlevel 1 (
  rem lock dosyasi tam yol kontrolu
  if /I not "%~nx1"=="telegram_bot.lock" if /I not "%~nx1"=="telegram_chat_messages.json" (
    >>"%SAFELOG%" echo [%DATE% %TIME%] SAFE-DEL blocked unknown: %TARGET%
    echo [SAFETY] Onaysiz hedef engellendi: %TARGET%
    exit /b 5
  )
)

if not exist "%TARGET%" (
  >>"%SAFELOG%" echo [%DATE% %TIME%] SAFE-DEL skip missing: %TARGET%
  exit /b 0
)

>>"%SAFELOG%" echo [%DATE% %TIME%] SAFE-DEL ok: %TARGET%
del /f /q "%TARGET%" >nul 2>&1
exit /b 0
