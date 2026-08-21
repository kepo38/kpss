@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title KPSS Odak — Telefon (Django + USB)

set "ROOT=D:\HEDEFKAMU"
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

if exist "C:\Program Files\Microsoft\jdk-17.0.20.8-hotspot\bin\java.exe" (
  set "JAVA_HOME=C:\Program Files\Microsoft\jdk-17.0.20.8-hotspot"
  set "PATH=C:\Program Files\Microsoft\jdk-17.0.20.8-hotspot\bin;%PATH%"
)
if exist "C:\flutter\flutter\bin\flutter.bat" (
  set "PATH=C:\flutter\flutter\bin;%PATH%"
)
if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
  set "PATH=%LOCALAPPDATA%\Android\Sdk\platform-tools;%PATH%"
)

set "GRADLE_USER_HOME=D:\.gradle"
if not exist "%GRADLE_USER_HOME%\" mkdir "%GRADLE_USER_HOME%" >nul 2>&1
if not exist "%GRADLE_USER_HOME%\" (
  echo [HATA] Gradle onbellegi olusturulamadi: %GRADLE_USER_HOME%
  pause
  exit /b 1
)

set "PUB_CACHE=%ROOT%\.pub-cache"
if not exist "%PUB_CACHE%\" mkdir "%PUB_CACHE%" >nul 2>&1
if not exist "%PUB_CACHE%\" (
  echo [HATA] Pub onbellegi olusturulamadi: %PUB_CACHE%
  pause
  exit /b 1
)

echo.
echo  ============================================================
echo   KPSS Odak — Telefon: Django LAN + USB hot reload
echo  ============================================================
echo.
echo   1) Django 0.0.0.0:8000 (telefon ayni Wi-Fi)
echo   2) Flutter USB ile uzerine yazar (silmeye gerek yok)
echo      Kod degisince:  r = hot reload   R = hot restart   q = cik
echo  ============================================================
echo.

rem ---------- Python (aynı basla.bat cozumleyici) ----------
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

if not exist "%ROOT%\backend\manage.py" (
  echo [HATA] backend\manage.py bulunamadi.
  pause
  exit /b 1
)

rem ---------- Django: saglikli degilse baslat ----------
set "DJANGO_OK="
powershell -NoProfile -Command "try { $r = Invoke-WebRequest -Uri 'http://127.0.0.1:8000/api/v1/health/' -UseBasicParsing -TimeoutSec 2; if ($r.StatusCode -eq 200) { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>&1
if not errorlevel 1 set "DJANGO_OK=1"

if not defined DJANGO_OK (
  echo [.] Eski Django runserver temizleniyor (varsa)...
  if exist "%ROOT%\scripts\stop-django-runserver.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\stop-django-runserver.ps1"
  )
  ping -n 2 127.0.0.1 >nul

  set "BUSY_PID="
  for /f "tokens=5" %%A in ('netstat -ano ^| findstr /R /C:":8000 .*LISTENING"') do set "BUSY_PID=%%A"
  if defined BUSY_PID (
    echo [HATA] Port 8000 baska bir surec tarafindan kullaniliyor.
    echo        PID: !BUSY_PID!
    echo        Task Manager ile kapatip tekrar deneyin.
    pause
    exit /b 1
  )

  echo [.] Veritabani guncelleniyor...
  pushd "%ROOT%\backend"
  "!PY!" manage.py migrate --noinput
  if errorlevel 1 (
    popd
    echo [HATA] migrate basarisiz.
    pause
    exit /b 1
  )
  "!PY!" manage.py ensure_admin >nul 2>&1
  popd

  echo [.] Django ayri pencerede baslatiliyor: 0.0.0.0:8000
  start "KPSS Odak - Django (telefon)" /D "%ROOT%\backend" "!PY!" manage.py runserver 0.0.0.0:8000

  set "DJANGO_OK="
  for /L %%I in (1,1,20) do (
    if not defined DJANGO_OK (
      ping -n 2 127.0.0.1 >nul
      powershell -NoProfile -Command "try { $r = Invoke-WebRequest -Uri 'http://127.0.0.1:8000/api/v1/health/' -UseBasicParsing -TimeoutSec 2; if ($r.StatusCode -eq 200) { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>&1
      if not errorlevel 1 set "DJANGO_OK=1"
    )
  )
  if not defined DJANGO_OK (
    echo [HATA] Django saglik kontrolu basarisiz (http://127.0.0.1:8000/api/v1/health/).
    echo        Acilan Django penceresindeki hataya bakin.
    pause
    exit /b 1
  )
  echo [OK] Django ayakta.
) else (
  echo [OK] Django zaten ayakta (port 8000).
)

rem LAN IP goster (telefon ApiConfig ile ayni ag)
set "LAN_IP="
for /f "delims=" %%I in ('powershell -NoProfile -Command "Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike \"127.*\" -and $_.PrefixOrigin -ne \"WellKnown\" } | Select-Object -ExpandProperty IPAddress -First 1"') do set "LAN_IP=%%I"
echo.
echo   Panel:   http://127.0.0.1:8000/panel/
echo   Saglik:  http://127.0.0.1:8000/api/v1/health/
if defined LAN_IP (
  echo   Telefon API: http://!LAN_IP!:8000
  echo   ^(lib\config\api_config.dart defaultValue ile eslesmeli^)
) else (
  echo   [!] LAN IP okunamadi — telefon icin PC Wi-Fi IPv4 adresini kullanin.
)
echo.

where flutter >nul 2>&1
if errorlevel 1 (
  echo [HATA] flutter PATH'te yok.
  pause
  exit /b 1
)

where adb >nul 2>&1
if errorlevel 1 (
  echo [UYARI] adb bulunamadi; flutter kendi adb'sini kullanacak.
)

:wait_device
echo.
echo [.] Android cihaz bekleniyor (USB baglayin, hata ayiklama acik)...
flutter devices 2>nul | findstr /I "android-arm android-arm64 android-x64" >nul
if errorlevel 1 (
  timeout /t 3 /nobreak >nul
  goto wait_device
)

set "DEVICE_ID="
for /f "tokens=1,*" %%A in ('flutter devices 2^>nul ^| findstr /I "android-arm android-arm64"') do (
  set "DEVICE_ID=%%A"
  goto have_device
)

echo [HATA] Cihaz ID okunamadi. "flutter devices" ciktilarina bakin.
pause
exit /b 1

:have_device
echo [OK] Cihaz: !DEVICE_ID!
echo [.] Derlenip uzerine yukleniyor...
echo.

flutter pub get
if errorlevel 1 (
  echo [HATA] flutter pub get basarisiz.
  pause
  exit /b 1
)

flutter run -d !DEVICE_ID! --debug
set "RC=!ERRORLEVEL!"

echo.
if not "!RC!"=="0" (
  echo [HATA] flutter run cikti (kod !RC!).
  pause
  exit /b !RC!
)

echo [!] Oturum bitti (telefon cikmis veya q).
echo [.] Yeniden baglaninca otomatik devam...
timeout /t 2 /nobreak >nul
goto wait_device