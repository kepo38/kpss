@echo off
chcp 65001 >nul
title Hedef Kamu — Guncel APK Derle ve Yukle
cd /d "%~dp0"

set "PACKAGE=com.hedefkamu.hedef_kamu"
set "ACTIVITY=%PACKAGE%/com.hedefkamu.hedef_kamu.MainActivity"
set "APK="
set "SERIAL="

:: Cift tiklamada PATH / JDK eksik olmasin
if exist "C:\Program Files\Microsoft\jdk-17.0.20.8-hotspot\bin\java.exe" (
  set "JAVA_HOME=C:\Program Files\Microsoft\jdk-17.0.20.8-hotspot"
  set "PATH=%JAVA_HOME%\bin;%PATH%"
)
if exist "C:\flutter\flutter\bin\flutter.bat" (
  set "PATH=C:\flutter\flutter\bin;%PATH%"
)
if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
  set "PATH=%LOCALAPPDATA%\Android\Sdk\platform-tools;%PATH%"
)
if exist "D:\.gradle" set "GRADLE_USER_HOME=D:\.gradle"

echo.
echo  ============================================================
echo   Hedef Kamu — guncel RELEASE APK derle + telefona kur
echo  ============================================================
echo.
echo   Telefon USB bagli olsun, USB hata ayiklama acik olsun.
echo   "USB uzerinden yukleme" / Install via USB acik olsun.
echo   Ekranda izin penceresi cikarsa Tamam deyin.
echo.
echo   Akis: derle -^> eski uygulamayi SIL -^> yeni APK kur -^> ac
echo   Derleme 3-8 dk surebilir; bu sirada telefon tepki vermez — normal.
echo.

where flutter >nul 2>&1
if errorlevel 1 (
  echo [HATA] flutter PATH'te yok.
  pause
  exit /b 1
)

call :find_adb
if not defined ADB (
  echo [HATA] adb bulunamadi. Android SDK platform-tools kurulu olsun.
  pause
  exit /b 1
)

"%ADB%" start-server >nul 2>&1
call :resolve_device
if not defined SERIAL (
  echo [HATA] Telefon bulunamadi / yetkisiz.
  echo   USB baglayin, hata ayiklama iznini onaylayin.
  pause
  exit /b 1
)

echo [OK] Cihaz: %SERIAL%
echo [.] Bagimliliklar...
echo.

call flutter pub get
if errorlevel 1 (
  echo [HATA] flutter pub get basarisiz.
  pause
  exit /b 1
)

echo.
echo [.] Release APK derleniyor...
echo     ^(Birkaç dakika surebilir; pencereyi kapatmayin.^)
echo.

call flutter build apk --release
if errorlevel 1 (
  echo [HATA] APK derlenemedi.
  pause
  exit /b 1
)

echo.
echo [.] Release APK araniyor...
set "APK_CANDIDATE="

if exist "build\app\outputs\flutter-apk\app-release.apk" (
  set "APK_CANDIDATE=build\app\outputs\flutter-apk\app-release.apk"
  goto apk_found
)

for /f "delims=" %%F in ('dir /b /s /o-d build\app\outputs\flutter-apk\*release*.apk 2^>nul') do (
  set "APK_CANDIDATE=%%F"
  goto apk_found
)

for /f "delims=" %%F in ('dir /b /s /o-d build\app\outputs\apk\release\*release*.apk 2^>nul') do (
  set "APK_CANDIDATE=%%F"
  goto apk_found
)

:apk_found
set "APK=%APK_CANDIDATE%"

if "%APK%"=="" (
  echo [HATA] Release APK bulunamadi.
  pause
  exit /b 1
)

echo [OK] APK: %APK%
dir "%APK%"

:: Derleme uzun surdugu icin cihaz baglantisini yenile
echo.
echo [.] ADB baglantisi yenileniyor...
"%ADB%" start-server >nul 2>&1
call :resolve_device
if not defined SERIAL (
  echo [HATA] Derleme sonrasi telefon kayboldu. USB'yi cikip takin, tekrar deneyin.
  pause
  exit /b 1
)
echo [OK] Cihaz hazir: %SERIAL%

echo.
echo [.] Mevcut uygulama siliniyor: %PACKAGE%
"%ADB%" -s %SERIAL% shell am force-stop %PACKAGE% >nul 2>&1
"%ADB%" -s %SERIAL% uninstall %PACKAGE%
if errorlevel 1 (
  echo [!] Silinemedi veya zaten yok — kuruluma devam.
) else (
  echo [OK] Eski surum silindi.
)

echo.
echo [.] Yeni APK kuruluyor...
"%ADB%" -s %SERIAL% install "%APK%"
if errorlevel 1 (
  echo [!] adb install basarisiz — flutter install deneniyor...
  echo     Telefonda USB yukleme iznini onaylayin.
  call flutter install -d %SERIAL% --release
  if errorlevel 1 (
    echo.
    echo [HATA] Kurulum basarisiz.
    echo   Redmi / Xiaomi: Gelistirici secenekleri
    echo   - USB hata ayiklama
    echo   - USB hata ayiklama ^(Guvenlik ayarlari^)
    echo   - USB uzerinden yukleme / Install via USB
    echo   Acik olsun; izin penceresine Tamam deyin.
    pause
    exit /b 1
  )
)

echo [.] Kurulum dogrulaniyor...
"%ADB%" -s %SERIAL% shell pm path %PACKAGE% >nul 2>&1
if errorlevel 1 (
  echo [HATA] Paket telefonda gorunmuyor — kurulum tamamlanamamis.
  pause
  exit /b 1
)

echo [.] Uygulama aciliyor...
"%ADB%" -s %SERIAL% shell am start -n %ACTIVITY%
if errorlevel 1 (
  "%ADB%" -s %SERIAL% shell monkey -p %PACKAGE% -c android.intent.category.LAUNCHER 1 >nul 2>&1
)

echo.
echo [OK] Eski uygulama silindi, guncel APK kuruldu ve acildi.
echo.
pause
exit /b 0

:resolve_device
set "SERIAL="
set "WAIT=0"
:wait_device
for /f "tokens=1,2" %%A in ('"%ADB%" devices 2^>nul') do (
  if /I "%%B"=="unauthorized" (
    echo [!] Cihaz %%A yetkisiz — telefondaki izin penceresine Tamam deyin.
  )
  if /I "%%B"=="device" (
    echo %%A | findstr /I "emulator-" >nul
    if errorlevel 1 (
      set "SERIAL=%%A"
      goto :eof
    )
  )
)
:: Fiziksel yoksa emulator kabul
for /f "tokens=1,2" %%A in ('"%ADB%" devices 2^>nul') do (
  if /I "%%B"=="device" (
    set "SERIAL=%%A"
    goto :eof
  )
)
set /a WAIT+=1
if %WAIT% GEQ 20 (
  set "SERIAL="
  goto :eof
)
echo [.] Android telefon bekleniyor... ^(%WAIT%/20^)
timeout /t 3 /nobreak >nul
goto wait_device

:find_adb
set "ADB="
where adb >nul 2>&1
if not errorlevel 1 (
  for /f "delims=" %%A in ('where adb') do (
    set "ADB=%%A"
    goto :eof
  )
)
if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
  set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
  goto :eof
)
if exist "%LOCALAPPDATA%\Android\sdk\platform-tools\adb.exe" (
  set "ADB=%LOCALAPPDATA%\Android\sdk\platform-tools\adb.exe"
  goto :eof
)
if exist "%ANDROID_HOME%\platform-tools\adb.exe" (
  set "ADB=%ANDROID_HOME%\platform-tools\adb.exe"
  goto :eof
)
if exist "%ANDROID_SDK_ROOT%\platform-tools\adb.exe" (
  set "ADB=%ANDROID_SDK_ROOT%\platform-tools\adb.exe"
)
goto :eof
