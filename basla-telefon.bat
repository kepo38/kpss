@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul

rem Explorer double-click: keep window open via outer cmd /k
if "%~1"=="__INNER__" goto :main
cmd /k "%~f0" __INNER__
exit /b

:main
title KPSS Odak - Telefon (Django + USB)

set "ROOT=D:\HEDEFKAMU"
echo.
echo  ============================================================
echo   KPSS Odak - Telefon: Django LAN + USB hot reload
echo  ============================================================
echo.
echo   [ADIM] Proje kokunu dogruluyor...
if not exist "%ROOT%\basla-telefon.bat" (
  echo [HATA] Proje bulunamadi: %ROOT%
  goto :fail
)
cd /d "%ROOT%"
if errorlevel 1 (
  echo [HATA] Klasore girilemedi: %ROOT%
  goto :fail
)
echo [OK] ROOT=%ROOT%

echo.
echo   [ADIM] JAVA / Flutter / adb PATH...
if exist "C:\Program Files\Microsoft\jdk-17.0.20.8-hotspot\bin\java.exe" (
  set "JAVA_HOME=C:\Program Files\Microsoft\jdk-17.0.20.8-hotspot"
  set "PATH=C:\Program Files\Microsoft\jdk-17.0.20.8-hotspot\bin;%PATH%"
  echo [OK] JAVA_HOME ayarlandi
) else (
  echo [.] JAVA_HOME varsayilan - jdk-17.0.20 bulunamadi
)
if exist "C:\flutter\flutter\bin\flutter.bat" (
  set "PATH=C:\flutter\flutter\bin;%PATH%"
  echo [OK] Flutter PATH eklendi
)
if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
  set "PATH=%LOCALAPPDATA%\Android\Sdk\platform-tools;%PATH%"
  echo [OK] adb PATH eklendi
) else echo [UYARI] adb SDK yolunda yok - flutter kendi adb kullanabilir

set "GRADLE_USER_HOME=D:\.gradle"
if not exist "%GRADLE_USER_HOME%\" mkdir "%GRADLE_USER_HOME%" >nul 2>&1
if not exist "%GRADLE_USER_HOME%\" (
  echo [HATA] Gradle onbellegi olusturulamadi: %GRADLE_USER_HOME%
  goto :fail
)
set "PUB_CACHE=%ROOT%\.pub-cache"
if not exist "%PUB_CACHE%\" mkdir "%PUB_CACHE%" >nul 2>&1
if not exist "%PUB_CACHE%\" (
  echo [HATA] Pub onbellegi olusturulamadi: %PUB_CACHE%
  goto :fail
)
echo [OK] GRADLE_USER_HOME=%GRADLE_USER_HOME%
echo [OK] PUB_CACHE=%PUB_CACHE%

echo.
echo   [ADIM] Python bulunuyor...
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
  goto :fail
)
echo [OK] Python: !PY!

echo.
echo   [ADIM] Django import kontrolu...
"!PY!" -c "import django" 1>nul 2>nul
if errorlevel 1 (
  echo [HATA] Django yuklu degil.
  echo        "!PY!" -m pip install -r "%ROOT%\backend\requirements.txt"
  goto :fail
)
echo [OK] Django import OK

if not exist "%ROOT%\backend\manage.py" (
  echo [HATA] backend\manage.py bulunamadi.
  goto :fail
)

echo.
echo   [ADIM] LAN IPv4 okunuyor (get-lan-ip.ps1)...
set "LAN_IP="
for /f "usebackq delims=" %%I in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\get-lan-ip.ps1"`) do set "LAN_IP=%%I"

if not defined LAN_IP (
  echo [!] get-lan-ip.ps1 bos - ipconfig yedegi...
  for /f "tokens=2 delims=:" %%A in ('ipconfig ^| findstr /I /C:"IPv4"') do (
    for /f "tokens=1" %%B in ("%%A") do (
      set "CAND=%%B"
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
  echo [HATA] LAN IPv4 okunamadi. PC Wi-Fi acik olsun.
  echo        Deneyin: powershell -File "%ROOT%\scripts\get-lan-ip.ps1"
  goto :fail
)
set "API_BASE=http://!LAN_IP!:8000"
echo [OK] LAN_IP=!LAN_IP!
echo [OK] API_BASE=!API_BASE!

echo.
echo   [ADIM] Django 127.0.0.1:8000 saglik kontrolu...
set "DJANGO_OK="
powershell -NoProfile -Command "try { $r = Invoke-WebRequest -Uri 'http://127.0.0.1:8000/api/v1/health/' -UseBasicParsing -TimeoutSec 2; if ($r.StatusCode -eq 200) { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>&1
if errorlevel 1 goto start_django

netstat -ano 2>nul | findstr /C:"0.0.0.0:8000" | findstr /I "LISTENING" >nul
if errorlevel 1 goto django_no_lan_bind

echo [OK] Django zaten ayakta - LAN bind OK
goto django_ok

:django_no_lan_bind
echo [!] Django ayakta ama LAN bind 0.0.0.0:8000 yok - yeniden baslatilacak
goto start_django

:start_django
echo [.] Django yok veya LAN bind yok - baslatilacak
echo.
echo   [ADIM] Eski runserver temizligi...
if exist "%ROOT%\scripts\stop-django-runserver.ps1" powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\stop-django-runserver.ps1"
ping -n 2 127.0.0.1 >nul

set "BUSY_PID="
for /f "tokens=5" %%A in ('netstat -ano 2^>nul ^| findstr /C:":8000" ^| findstr /I "LISTENING"') do set "BUSY_PID=%%A"
if defined BUSY_PID echo [.] Port 8000 PID !BUSY_PID! kapatiliyor...
if defined BUSY_PID taskkill /F /PID !BUSY_PID! >nul 2>&1
if defined BUSY_PID ping -n 2 127.0.0.1 >nul

echo.
echo   [ADIM] migrate --noinput...
pushd "%ROOT%\backend"
"!PY!" manage.py migrate --noinput
if errorlevel 1 goto migrate_fail
"!PY!" manage.py ensure_admin >nul 2>&1
popd
echo [OK] migrate bitti
goto migrate_done

:migrate_fail
popd
echo [HATA] migrate basarisiz. Yukaridaki Python/Django hatasina bakin.
goto :fail

:migrate_done
echo.
echo   [ADIM] Django penceresi aciliyor 0.0.0.0:8000 ...
if not exist "%ROOT%\scripts\run-django-telefon.bat" echo [HATA] scripts\run-django-telefon.bat bulunamadi.
if not exist "%ROOT%\scripts\run-django-telefon.bat" goto :fail
rem Guvenli start: launcher bat - PY yolunda bosluk olsa da kirilmaz
start "KPSS Odak - Django telefon" cmd /k call "%ROOT%\scripts\run-django-telefon.bat" "!PY!"

echo   [ADIM] Saglik bekleniyor max ~50 sn...
set "DJANGO_OK="
set /a DJANGO_TRY=0
:wait_django_health
set /a DJANGO_TRY+=1
if !DJANGO_TRY! GTR 25 goto wait_django_fail
ping -n 2 127.0.0.1 >nul
powershell -NoProfile -Command "try { $r = Invoke-WebRequest -Uri 'http://127.0.0.1:8000/api/v1/health/' -UseBasicParsing -TimeoutSec 2; if ($r.StatusCode -eq 200) { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>&1
if not errorlevel 1 set "DJANGO_OK=1"
if defined DJANGO_OK goto wait_django_done
echo [.] deneme !DJANGO_TRY!/25...
goto wait_django_health

:wait_django_fail
echo [HATA] Django saglik kontrolu basarisiz http://127.0.0.1:8000/api/v1/health/
echo        Acilan Django penceresindeki hataya bakin.
echo        run-django-telefon.bat penceresi kapandiysa oradaki hatayi okuyun.
goto :fail

:wait_django_done
echo [OK] Django ayakta 0.0.0.0:8000

:django_ok
echo.
echo   [ADIM] LAN saglik: !API_BASE!/api/v1/health/
powershell -NoProfile -Command "try { $r = Invoke-WebRequest -Uri '!API_BASE!/api/v1/health/' -UseBasicParsing -TimeoutSec 3; if ($r.StatusCode -eq 200) { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>&1
if errorlevel 1 goto lan_health_warn
echo [OK] LAN saglik OK
goto lan_health_done

:lan_health_warn
echo [UYARI] !API_BASE!/api/v1/health/ ulasilamadi.
echo         Windows Guvenlik Duvari - Python inbound 8000 / ozel ag izni verin.

:lan_health_done

echo.
echo  ------------------------------------------------------------
echo   Panel:        http://127.0.0.1:8000/panel/
echo   Telefon API:  !API_BASE!
echo   dart-define:  KPSS_API_BASE=!API_BASE!
echo  ------------------------------------------------------------
echo.

echo   [ADIM] flutter kontrol...
where flutter >nul 2>&1
if errorlevel 1 goto no_flutter
echo [OK] flutter bulundu
goto flutter_ok

:no_flutter
echo [HATA] flutter PATH'te yok.
goto :fail

:flutter_ok
where adb >nul 2>&1
if errorlevel 1 goto no_adb
adb start-server >nul 2>&1
echo [OK] adb start-server
goto adb_ok

:no_adb
echo [UYARI] adb PATH'te yok; flutter kendi adb'sini kullanacak.

:adb_ok

set "WAIT_N=0"
:wait_device
set /a WAIT_N+=1
if !WAIT_N! GTR 40 (
  echo [HATA] 2 dk boyunca Android cihaz bulunamadi.
  echo        USB hata ayiklama acik mi?  adb devices
  goto :fail
)
echo.
echo [.] Android cihaz bekleniyor... (!WAIT_N!/40)
flutter devices 2>nul | findstr /I "android-arm android-arm64 android-x64" >nul
if errorlevel 1 (
  timeout /t 3 /nobreak >nul
  goto wait_device
)

set "DEVICE_ID="
for /f "tokens=1" %%A in ('flutter devices 2^>nul ^| findstr /I "android-arm android-arm64"') do (
  set "DEVICE_ID=%%A"
  goto have_device
)

echo [HATA] Cihaz ID okunamadi. flutter devices:
flutter devices
goto :fail

:have_device
echo [OK] Cihaz: !DEVICE_ID!
echo.
echo   [ADIM] flutter pub get...
flutter pub get
if errorlevel 1 (
  echo [HATA] flutter pub get basarisiz.
  goto :fail
)

echo.
echo   [ADIM] flutter run --dart-define=KPSS_API_BASE=!API_BASE!
echo     (Ilk kurulumda tam derleme gerekir; hot reload dart-define degistirmez.)
echo.
flutter run -d !DEVICE_ID! --debug "--dart-define=KPSS_API_BASE=!API_BASE!"
set "RC=!ERRORLEVEL!"

echo.
if not "!RC!"=="0" echo [HATA] flutter run cikti kod !RC!.
if not "!RC!"=="0" goto :fail

echo [!] Oturum bitti. Yeniden baglaninca devam...
set "WAIT_N=0"
timeout /t 2 /nobreak >nul
goto wait_device

:fail
echo.
echo [BITTI] Hata nedeniyle durdu. Pencereyi kapatmak icin bir tusa basin.
pause
exit /b 1
