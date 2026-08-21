@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title KPSS Odak - Telefon (Django + USB)

echo.
echo  ============================================================
echo   KPSS Odak - Telefon TEST (LAN IP + Django health)
echo   Flutter YOK ? sadece API_BASE dogrulama
echo  ============================================================
echo.

set "ROOT=D:\HEDEFKAMU"
echo [ADIM 1/6] Proje kokunu dogruluyor...
if not exist "%ROOT%\basla-telefon.bat" (
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
echo [OK] ROOT=%ROOT%

echo.
echo [ADIM 2/6] Python bulunuyor...
set "PY="
if exist "%ROOT%\venv\Scripts\python.exe" set "PY=%ROOT%\venv\Scripts\python.exe"
if not defined PY if exist "%ROOT%\.venv\Scripts\python.exe" set "PY=%ROOT%\.venv\Scripts\python.exe"
if not defined PY if exist "%ROOT%\backend\venv\Scripts\python.exe" set "PY=%ROOT%\backend\venv\Scripts\python.exe"
if not defined PY if exist "%LocalAppData%\Programs\Python\Python314\python.exe" set "PY=%LocalAppData%\Programs\Python\Python314\python.exe"
if not defined PY if exist "%LocalAppData%\Programs\Python\Python313\python.exe" set "PY=%LocalAppData%\Programs\Python\Python313\python.exe"
if not defined PY if exist "%LocalAppData%\Programs\Python\Python312\python.exe" set "PY=%LocalAppData%\Programs\Python\Python312\python.exe"
if not defined PY if exist "%LocalAppData%\Programs\Python\Python311\python.exe" set "PY=%LocalAppData%\Programs\Python\Python311\python.exe"
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
  pause
  exit /b 1
)
echo [OK] PY=!PY!

echo.
echo [ADIM 3/6] Django import...
"!PY!" -c "import django; print(django.get_version())"
if errorlevel 1 (
  echo [HATA] Django yuklu degil.
  echo        "!PY!" -m pip install -r "%ROOT%\backend\requirements.txt"
  pause
  exit /b 1
)
echo [OK] Django import

echo.
echo [ADIM 4/6] LAN IP (get-lan-ip.ps1 + ipconfig yedek)...
set "LAN_IP="
for /f "usebackq delims=" %%I in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\get-lan-ip.ps1"`) do set "LAN_IP=%%I"
if defined LAN_IP echo [.] get-lan-ip.ps1 =^> !LAN_IP!
if not defined LAN_IP (
  echo [!] get-lan-ip.ps1 bos ? ipconfig...
  for /f "tokens=2 delims=:" %%A in ('ipconfig ^| findstr /I /C:"IPv4"') do (
    for /f "tokens=1" %%B in ("%%A") do (
      set "CAND=%%B"
      echo [.] ipconfig aday: !CAND!
      echo !CAND! | findstr /R "^192\.168\." >nul
      if not errorlevel 1 if not defined LAN_IP set "LAN_IP=!CAND!"
    )
  )
)
if not defined LAN_IP (
  for /f "tokens=2 delims=:" %%A in ('ipconfig ^| findstr /I /C:"IPv4"') do (
    for /f "tokens=1" %%B in ("%%A") do (
      set "CAND=%%B"
      echo !CAND! | findstr /R "^10\." >nul
      if not errorlevel 1 if not defined LAN_IP set "LAN_IP=!CAND!"
    )
  )
)
if not defined LAN_IP (
  echo [HATA] LAN IPv4 okunamadi.
  pause
  exit /b 1
)
set "API_BASE=http://!LAN_IP!:8000"
echo [OK] LAN_IP=!LAN_IP!
echo [OK] API_BASE=!API_BASE!

echo.
echo [ADIM 5/6] Port 8000 / local health...
netstat -ano 2>nul | findstr "8000"
powershell -NoProfile -Command "try { $r = Invoke-WebRequest -Uri 'http://127.0.0.1:8000/api/v1/health/' -UseBasicParsing -TimeoutSec 3; Write-Host ('[OK] local health ' + $r.StatusCode + ' ' + $r.Content) } catch { Write-Host ('[HATA] local health: ' + $_.Exception.Message); exit 1 }"
if errorlevel 1 goto start_django
goto django_ok

:start_django
echo.
echo [!] Django ayakta degil. Test baslatmayi deniyor...
if not exist "%ROOT%\scripts\run-django-telefon.bat" echo [HATA] scripts\run-django-telefon.bat bulunamadi.
if not exist "%ROOT%\scripts\run-django-telefon.bat" goto :fail_pause
start "KPSS Odak - Django test" cmd /k call "%ROOT%\scripts\run-django-telefon.bat" "!PY!"
set "OK="
set /a TRY=0
:wait_health
set /a TRY+=1
if !TRY! GTR 20 goto wait_health_fail
ping -n 2 127.0.0.1 >nul
powershell -NoProfile -Command "try { $r = Invoke-WebRequest -Uri 'http://127.0.0.1:8000/api/v1/health/' -UseBasicParsing -TimeoutSec 2; if ($r.StatusCode -eq 200) { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>&1
if not errorlevel 1 set "OK=1"
if defined OK goto wait_health_done
echo [.] bekleniyor !TRY!/20...
goto wait_health

:wait_health_fail
echo [HATA] Django health hala basarisiz. Django penceresine bakin.
goto :fail_pause

:wait_health_done
echo [OK] Django test penceresinden ayaga kalkti

:django_ok
echo.
echo [ADIM 6/6] LAN health !API_BASE!/api/v1/health/ ...
powershell -NoProfile -Command "try { $r = Invoke-WebRequest -Uri '!API_BASE!/api/v1/health/' -UseBasicParsing -TimeoutSec 3; Write-Host ('[OK] LAN health ' + $r.StatusCode + ' ' + $r.Content) } catch { Write-Host ('[HATA] LAN health: ' + $_.Exception.Message); exit 1 }"
if errorlevel 1 goto lan_fail

echo.
echo  ============================================================
echo   SONUC: API_BASE=!API_BASE!
echo   Flutter icin: basla-telefon.bat
echo  ============================================================
echo.
pause
exit /b 0

:lan_fail
echo [UYARI] Firewall / ozel ag: Python icin 8000 inbound izin verin.
goto :fail_pause

:fail_pause
echo.
echo [BITTI] Hata nedeniyle durdu. Pencereyi kapatmak icin bir tusa basin.
pause
exit /b 1
