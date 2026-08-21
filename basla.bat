@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title KPSS Odak - Panel

set "ROOT=D:\HEDEFKAMU"
if not exist "%ROOT%\basla.bat" (
  echo [HATA] Proje bulunamadi: %ROOT%
  pause
  exit /b 1
)
cd /d "%ROOT%"
if errorlevel 1 (
  echo [HATA] Klasore girilemedi: %ROOT%
  pause
  exit /b 1
)

echo.
echo  ========================================
echo   KPSS Odak - Icerik Paneli baslatiliyor
echo  ========================================
echo.
echo   Telefon (Django LAN + USB):  basla-telefon.bat
echo.

cd /d "%ROOT%\backend"
if not exist "manage.py" (
  echo [HATA] backend\manage.py bulunamadi.
  pause
  exit /b 1
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
  echo [HATA] Python bulunamadi. Python 3 kurulu olmali.
  pause
  exit /b 1
)

echo [.] Python: !PY!
"!PY!" -c "import django" 1>nul 2>nul
if errorlevel 1 (
  echo [HATA] Django yuklu degil.
  echo        Ornek: "!PY!" -m pip install -r "%ROOT%\backend\requirements.txt"
  pause
  exit /b 1
)

echo [.] Eski Django runserver temizleniyor (varsa)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\stop-django-runserver.ps1"
ping -n 2 127.0.0.1 >nul

set "BUSY_PID="
for /f "tokens=5" %%A in ('netstat -ano ^| findstr /R /C:":8000 .*LISTENING"') do set "BUSY_PID=%%A"
if defined BUSY_PID (
  echo [HATA] Port 8000 baska bir surec tarafindan kullaniliyor.
  echo        PID: !BUSY_PID!
  echo        Bu sureci Task Manager ile kapatip tekrar deneyin.
  pause
  exit /b 1
)

echo [1/3] Veritabani guncelleniyor...
"!PY!" manage.py migrate --noinput
if errorlevel 1 (
  echo [HATA] migrate basarisiz.
  pause
  exit /b 1
)

echo [2/3] Admin kullanici kontrol ediliyor...
"!PY!" manage.py ensure_admin
if errorlevel 1 (
  echo [HATA] admin kullanici olusturulamadi.
  pause
  exit /b 1
)

echo [3/3] Sunucu: http://127.0.0.1:8000/panel/
echo       Saglik:  http://127.0.0.1:8000/api/v1/health/
echo       Admin:   http://127.0.0.1:8000/admin/
echo.
echo  Durdurmak icin bu pencerede Ctrl+C
echo.

start "" "http://127.0.0.1:8000/panel/"
"!PY!" manage.py runserver 0.0.0.0:8000
set "RC=!ERRORLEVEL!"
if not "!RC!"=="0" (
  echo.
  echo [HATA] Sunucu cikti (kod !RC!).
)
echo.
pause
exit /b !RC!