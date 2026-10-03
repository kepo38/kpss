@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title HEDEF Kamu - Dosya durum kontrolu

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "SAFELOG=%ROOT%\logs\safety.log"
set "MANIFEST=%ROOT%\scripts\critical-files.txt"
set "REPORT=%ROOT%\logs\file-integrity.txt"

if not exist "%ROOT%\logs" mkdir "%ROOT%\logs" >nul 2>&1

>>"%SAFELOG%" echo(
>>"%SAFELOG%" echo ===== DOSYA-DURUM %DATE% %TIME% =====
>"%REPORT%" echo HEDEF Kamu file integrity %DATE% %TIME%
>>"%REPORT%" echo ROOT=%ROOT%

echo.
echo  Proje: %ROOT%
echo.

set "OK=0"
set "BAD=0"

if not exist "%MANIFEST%" (
  echo [HATA] Manifest yok: %MANIFEST%
  pause
  exit /b 1
)

for /f "usebackq delims=" %%F in ("%MANIFEST%") do (
  if not "%%F"=="" (
    if exist "%ROOT%\%%F" (
      echo  [OK] %%F
      >>"%REPORT%" echo OK %%F
      >>"%SAFELOG%" echo OK %%F
      set /a OK+=1
    ) else (
      echo  [EKSIK] %%F
      >>"%REPORT%" echo MISSING %%F
      >>"%SAFELOG%" echo MISSING %%F
      set /a BAD+=1
    )
  )
)

echo.
echo  Bat dosyalari (kok):
dir /b "%ROOT%\*.bat" 2>nul
dir /b "%ROOT%\*.bat" >>"%REPORT%" 2>nul

echo.
echo  Ozet: OK=!OK!  EKSIK=!BAD!
echo  Rapor: %REPORT%
echo  Safety log: %SAFELOG%
if not "!BAD!"=="0" (
  echo.
  echo  Kurtarma: GERI-YUKLE-KRITIK.bat
  >>"%SAFELOG%" echo integrity FAIL missing=!BAD!
  pause
  exit /b 1
)

>>"%SAFELOG%" echo integrity OK
echo.
pause
exit /b 0
