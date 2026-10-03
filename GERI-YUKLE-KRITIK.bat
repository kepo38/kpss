@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title HEDEF Kamu - Kritik dosya geri yukleme

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "SAFELOG=%ROOT%\logs\safety.log"
set "MANIFEST=%ROOT%\scripts\critical-files.txt"

if not exist "%ROOT%\logs" mkdir "%ROOT%\logs" >nul 2>&1
>>"%SAFELOG%" echo(
>>"%SAFELOG%" echo ===== GERI-YUKLE-KRITIK %DATE% %TIME% =====

cd /d "%ROOT%"
if errorlevel 1 (
  echo [HATA] Proje klasorune girilemedi: %ROOT%
  pause
  exit /b 1
)

where git >nul 2>&1
if errorlevel 1 (
  echo [HATA] git bulunamadi.
  >>"%SAFELOG%" echo git missing
  pause
  exit /b 1
)

echo.
echo  Git ile kritik dosyalar geri yuklenecek (silme YOK).
echo  Manifest: %MANIFEST%
echo.

set "MISSING=0"
if exist "%MANIFEST%" (
  for /f "usebackq delims=" %%F in ("%MANIFEST%") do (
    if not "%%F"=="" if not exist "%ROOT%\%%F" (
      echo  [EKSIK] %%F
      set /a MISSING+=1
      >>"%SAFELOG%" echo missing %%F
    )
  )
)

echo  Eksik sayisi: !MISSING!
echo.
echo  Tum izlenen silinmis dosyalar + manifest git checkout ile restore...
echo.

git ls-files --deleted > "%TEMP%\hedefkamu-deleted.txt" 2>nul
for /f "usebackq delims=" %%F in ("%TEMP%\hedefkamu-deleted.txt") do (
  echo  restore deleted: %%F
  git checkout HEAD -- "%%F"
  >>"%SAFELOG%" echo restored-deleted %%F
)

if exist "%MANIFEST%" (
  for /f "usebackq delims=" %%F in ("%MANIFEST%") do (
    if not "%%F"=="" (
      git checkout HEAD -- "%%F" 2>nul
      if exist "%ROOT%\%%F" (
        echo  [OK] %%F
        >>"%SAFELOG%" echo ensured %%F
      ) else (
        echo  [UYARI] hala yok: %%F
        >>"%SAFELOG%" echo still-missing %%F
      )
    )
  )
)

echo.
echo  Bitti. Log: %SAFELOG%
echo  Bat listesi:
dir /b "%ROOT%\*.bat"
echo.
>>"%SAFELOG%" echo ===== GERI-YUKLE done %TIME% =====
pause
exit /b 0
