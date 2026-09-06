@echo off
REM Soru metin alanlarini kayit-tek-yol pipeline ile toplu normalize eder.
REM Akis: yedek -> dry-run -> onay -> apply -> dogrulama dry-run -> (opsiyonel) testler
REM
REM Kullanim:
REM   normalize-prod.bat                  Tam akis (onay sorar)
REM   normalize-prod.bat --dry-run-only   Yalnizca dry-run
REM   normalize-prod.bat --yes            Onay sormadan uygula
REM   normalize-prod.bat --unpublished-only   Yayinlanmamis sorular
REM   normalize-prod.bat --skip-tests     Test adimini atla

setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title HEDEF Kamu - normalize_stored_questions

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

if not exist "%ROOT%\backend\manage.py" (
  echo [HATA] backend\manage.py bulunamadi: %ROOT%
  pause
  exit /b 1
)

set "DRY_RUN_ONLY=0"
set "SKIP_CONFIRM=0"
set "UNPUBLISHED_ONLY=0"
set "SKIP_TESTS=0"

:parse_args
if "%~1"=="" goto args_done
if /I "%~1"=="--dry-run-only" set "DRY_RUN_ONLY=1"
if /I "%~1"=="--yes" set "SKIP_CONFIRM=1"
if /I "%~1"=="--unpublished-only" set "UNPUBLISHED_ONLY=1"
if /I "%~1"=="--skip-tests" set "SKIP_TESTS=1"
shift
goto parse_args
:args_done

set "PY="
for /f "usebackq delims=" %%P in (`call "%ROOT%\scripts\find-python.bat" "%ROOT%"`) do set "PY=%%P"
if not defined PY (
  echo [HATA] Python bulunamadi.
  pause
  exit /b 1
)

set "BACKEND=%ROOT%\backend"
set "DB=%BACKEND%\db.sqlite3"
if not exist "%DB%" (
  echo [HATA] Veritabani bulunamadi: %DB%
  pause
  exit /b 1
)

if not exist "%ROOT%\logs" mkdir "%ROOT%\logs"

for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "Get-Date -Format 'yyyyMMdd-HHmmss'"`) do set "STAMP=%%T"
set "BACKUP=%BACKEND%\db.sqlite3.bak-%STAMP%-normalize"
set "LOG=%ROOT%\logs\normalize-prod-%STAMP%.log"

set "EXTRA_ARGS="
if "%UNPUBLISHED_ONLY%"=="1" set "EXTRA_ARGS=--unpublished-only"

echo.
echo  ========================================
echo   normalize_stored_questions (prod)
echo  ========================================
echo   Python : %PY%
echo   DB     : %DB%
echo   Log    : %LOG%
echo.

cd /d "%BACKEND%" || exit /b 1

echo [%DATE% %TIME%] Basladi > "%LOG%"
echo Python: %PY%>> "%LOG%"
echo DB: %DB%>> "%LOG%"
echo.>> "%LOG%"

echo [1/5] Veritabani yedegi aliniyor...
copy /Y "%DB%" "%BACKUP%" >nul
if errorlevel 1 (
  echo [HATA] Yedek alinamadi: %BACKUP%
  pause
  exit /b 1
)
echo       Yedek: %BACKUP%
echo Yedek: %BACKUP%>> "%LOG%"
echo.>> "%LOG%"

echo [2/5] Dry-run...
set "DRY_OUT=%TEMP%\normalize_dry_%RANDOM%%RANDOM%.txt"
"%PY%" manage.py normalize_stored_questions --dry-run %EXTRA_ARGS% > "%DRY_OUT%" 2>&1
set "DRY_ERR=!ERRORLEVEL!"
type "%DRY_OUT%"
echo === DRY-RUN ===>> "%LOG%"
type "%DRY_OUT%">> "%LOG%"
del "%DRY_OUT%" >nul 2>&1
if !DRY_ERR! neq 0 (
  echo [HATA] Dry-run basarisiz (kod !DRY_ERR!).
  pause
  exit /b !DRY_ERR!
)

if "%DRY_RUN_ONLY%"=="1" (
  echo.
  echo Dry-run tamamlandi. Log: %LOG%
  pause
  exit /b 0
)

if "%SKIP_CONFIRM%"=="0" (
  echo.
  echo Dry-run ciktisini kontrol edin. Devam edilirse DB guncellenir.
  echo Geri almak icin: copy /Y "%BACKUP%" "%DB%"
  echo.
  set "ANS="
  set /p "ANS=Uygulamaya devam edilsin mi? [e/H]: "
  if /I not "!ANS!"=="e" (
    echo Iptal edildi.
    exit /b 0
  )
)

echo.
echo [3/5] Normalize uygulaniyor...
echo === APPLY ===>> "%LOG%"
"%PY%" manage.py normalize_stored_questions %EXTRA_ARGS% >> "%LOG%" 2>&1
set "APPLY_ERR=!ERRORLEVEL!"
if !APPLY_ERR! neq 0 (
  echo [HATA] Normalize basarisiz (kod !APPLY_ERR!). Log: %LOG%
  echo Geri alma: copy /Y "%BACKUP%" "%DB%"
  pause
  exit /b !APPLY_ERR!
)

echo [4/5] Dogrulama dry-run...
echo === VERIFY DRY-RUN ===>> "%LOG%"
"%PY%" manage.py normalize_stored_questions --dry-run %EXTRA_ARGS% >> "%LOG%" 2>&1
set "VERIFY_ERR=!ERRORLEVEL!"
if !VERIFY_ERR! neq 0 (
  echo [HATA] Dogrulama dry-run basarisiz (kod !VERIFY_ERR!).
  pause
  exit /b !VERIFY_ERR!
)

if "%SKIP_TESTS%"=="0" (
  echo [5/5] Rich-text testleri...
  echo === TESTS ===>> "%LOG%"
  "%PY%" manage.py test content.test_rich_text content.test_rich_text_storage content.test_rich_text_parity content.test_rich_text_js_parity -v 0 >> "%LOG%" 2>&1
  set "TEST_ERR=!ERRORLEVEL!"
  if !TEST_ERR! neq 0 (
    echo [HATA] Testler basarisiz (kod !TEST_ERR!). Log: %LOG%
    pause
    exit /b !TEST_ERR!
  )
) else (
  echo [5/5] Testler atlandi (--skip-tests).
)

echo.
echo Bitti.
echo   Yedek : %BACKUP%
echo   Log   : %LOG%
echo [%DATE% %TIME%] Bitti >> "%LOG%"
echo.
pause
exit /b 0
