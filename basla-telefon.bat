@echo off
setlocal EnableExtensions
chcp 65001 >nul
title KPSS Odak — Telefon (otomatik guncelle)
cd /d "%~dp0" 2>nul
if errorlevel 1 (
  echo [HATA] Proje klasorune girilemedi: %~dp0
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

set "GRADLE_USER_HOME=%~d0\.gradle"
if not exist "%GRADLE_USER_HOME%\" mkdir "%GRADLE_USER_HOME%" >nul 2>&1
if not exist "%GRADLE_USER_HOME%\" (
  echo [HATA] Gradle onbellegi olusturulamadi: %GRADLE_USER_HOME%
  pause
  exit /b 1
)

set "PUB_CACHE=%~dp0.pub-cache"
if not exist "%PUB_CACHE%\" mkdir "%PUB_CACHE%" >nul 2>&1
if not exist "%PUB_CACHE%\" (
  echo [HATA] Pub onbellegi olusturulamadi: %PUB_CACHE%
  pause
  exit /b 1
)

echo.
echo  ============================================================
echo   KPSS Odak — USB telefon otomatik guncelleme
echo  ============================================================
echo.
echo   - Uygulamayi SILMENIZE gerek yok
echo   - Telefon USB ile bagli olsun (USB hata ayiklama acik)
echo   - Kod degisince bu pencerede  r  = hot reload
echo                                  R  = hot restart
echo                                  q  = cik
echo.
echo   Telefon cikinca tekrar baglanmaniz beklenir, yeniden yukler.
echo  ============================================================
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
echo [.] Android cihaz bekleniyor (USB baglayin)...
flutter devices 2>nul | findstr /I "android-arm android-arm64 android-x64" >nul
if errorlevel 1 (
  timeout /t 3 /nobreak >nul
  goto wait_device
)

for /f "tokens=1,*" %%A in ('flutter devices 2^>nul ^| findstr /I "android-arm android-arm64"') do (
  set "DEVICE_ID=%%A"
  goto have_device
)

echo [HATA] Cihaz ID okunamadi. "flutter devices" ciktilarina bakin.
pause
exit /b 1

:have_device
echo [OK] Cihaz: %DEVICE_ID%
echo [.] Derlenip uzerine yukleniyor (silinmez, guncellenir)...
echo.

flutter pub get
flutter run -d %DEVICE_ID% --debug

echo.
echo [!] Oturum bitti (telefon cikmis veya q).
echo [.] Yeniden baglaninca otomatik devam...
timeout /t 2 /nobreak >nul
goto wait_device
