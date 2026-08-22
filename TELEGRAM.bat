@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul

set "AUTO=0"
if /i "%~1"=="/auto" set "AUTO=1"

if "!AUTO!"=="1" (
  title HEDEF Kamu - Telegram (otomatik)
  if not exist "%ROOT%\logs\" mkdir "%ROOT%\logs\" >nul 2>&1
  echo.>> "%ROOT%\logs\telegram-auto.log"
  echo ===== TELEGRAM.bat /auto %DATE% %TIME% =====>> "%ROOT%\logs\telegram-auto.log"
) else (
  title HEDEF Kamu - Telegram Soru Botu
)

set "ROOT=D:\HEDEFKAMU"
set "LOCK=%ROOT%\telegram_bot.lock"

if not exist "%ROOT%\backend\manage.py" (
  echo [HATA] Proje bulunamadi: %ROOT%\backend
  if "!AUTO!"=="0" pause
  exit /b 1
)

if exist "%LOCK%" (
  set "LOCKPID="
  for /f "usebackq delims=" %%P in ("%LOCK%") do set "LOCKPID=%%P"
  if defined LOCKPID (
    tasklist /FI "PID eq !LOCKPID!" 2>nul | find "!LOCKPID!" >nul
    if not errorlevel 1 (
      if "!AUTO!"=="1" (
        echo [BILGI] Telegram aktarimi zaten calisiyor ^(PID !LOCKPID!^).
        exit /b 0
      )
      echo.
      echo [BILGI] TELEGRAM.bat zaten calisiyor ^(PID !LOCKPID!^).
      echo         Ikinci pencere acmayin; ilki bitene kadar bekleyin.
      echo         Telegram'dan /durum ile ozet alabilirsiniz.
      echo.
      pause
      exit /b 1
    )
  )
  del "%LOCK%" 2>nul
)

cd /d "%ROOT%\backend"
if errorlevel 1 (
  echo [HATA] backend klasorune girilemedi.
  if "!AUTO!"=="0" pause
  exit /b 1
)

if "!AUTO!"=="0" (
  echo.
  echo  ========================================
  echo   Telegram Soru Botu (@hedefkamubot)
  echo  ========================================
  echo.
  echo   Kuyruktaki fotograflar islenir, ozet gosterilir, pencere kapanir.
  echo   Evde surekli dinleme icin: TELEGRAM-WATCH.bat ^(onerilen^)
  echo   Django/panel acik olmasi yetmez — Telegram bat ayri calismali.
  echo   Is yerinde gonderdiginiz fotograflar (son 24 saat) otomatik islenir.
  echo   Daha eski fotograflar kendi sohbetinizde kalir - ILET (forward) ile gonderin.
  echo   Islenen fotograflar bot sohbetinden silinir; tekrar iletirseniz uyari alirsiniz.
  echo   Panel: Onay bekleyen sorular
  echo   Telegram: /durum — bat acmadan ozet
  echo.
  echo   Surekli dinleme icin: TELEGRAM-WATCH.bat
  echo.
)

set "PY="
if exist "%ROOT%\venv\Scripts\python.exe" set "PY=%ROOT%\venv\Scripts\python.exe"
if not defined PY if exist "%ROOT%\.venv\Scripts\python.exe" set "PY=%ROOT%\.venv\Scripts\python.exe"
if not defined PY if exist "%ROOT%\backend\venv\Scripts\python.exe" set "PY=%ROOT%\backend\venv\Scripts\python.exe"
if not defined PY if exist "%LocalAppData%\Programs\Python\Python314\python.exe" set "PY=%LocalAppData%\Programs\Python\Python314\python.exe"
if not defined PY if exist "%LocalAppData%\Programs\Python\Python313\python.exe" set "PY=%LocalAppData%\Programs\Python\Python313\python.exe"
if not defined PY if exist "%LocalAppData%\Programs\Python\Python312\python.exe" set "PY=%LocalAppData%\Programs\Python\Python312\python.exe"
if not defined PY (
  where py >nul 2>&1
  if not errorlevel 1 for /f "delims=" %%P in ('py -3 -c "import sys; print(sys.executable)" 2^>nul') do set "PY=%%P"
)
if not defined PY (
  for /f "delims=" %%P in ('where python 2^>nul') do (
    echo %%P | findstr /I "WindowsApps" >nul
    if errorlevel 1 if not defined PY set "PY=%%P"
  )
)
if not defined PY (
  echo [HATA] Python bulunamadi.
  if "!AUTO!"=="0" pause
  exit /b 1
)

echo [.] Python: !PY!

if not exist "%ROOT%\backend\.env" (
  echo [UYARI] backend\.env yok - TELEGRAM_BOT_TOKEN tanimli olmali.
)

echo [.] Veritabani kontrol ediliyor...
"!PY!" manage.py migrate --noinput
if errorlevel 1 (
  echo [HATA] migrate basarisiz.
  if "!AUTO!"=="0" pause
  exit /b 1
)

echo [.] Kuyruk aktariliyor...
if "!AUTO!"=="1" echo [.] Kuyruk aktariliyor...>> "%ROOT%\logs\telegram-auto.log"
echo.
if "!AUTO!"=="1" (
  "!PY!" manage.py run_telegram_bot >> "%ROOT%\logs\telegram-auto.log" 2>&1
) else (
  "!PY!" manage.py run_telegram_bot
)
set "RC=!ERRORLEVEL!"

if "!RC!"=="2" (
  echo.
  if "!AUTO!"=="1" (
    echo [BILGI] Baska bir aktarim zaten calisiyor olabilir.
  ) else (
    echo [BILGI] Baska bir TELEGRAM.bat penceresi zaten acik olabilir.
  )
)

if not "!RC!"=="0" if not "!RC!"=="2" (
  echo.
  echo [HATA] Islem basarisiz (kod !RC!).
)

echo.
if "!AUTO!"=="1" exit /b !RC!
pause
exit /b !RC!
