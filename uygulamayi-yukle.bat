@echo off
setlocal EnableExtensions
title Hedef Kamu - APK derle ve yukle
goto :main

:: ===================== alt rutinler =====================

:resolve_device
set "SERIAL="
set "WAIT=0"
:wait_device
for /f "tokens=1,2" %%A in ('"%ADB%" devices 2^>nul') do (
  if /I "%%B"=="unauthorized" (
    echo [!] Cihaz %%A yetkisiz - telefondaki izin penceresine Tamam deyin.
  )
  if /I "%%B"=="device" (
    echo %%A | findstr /I "emulator-" >nul
    if errorlevel 1 (
      set "SERIAL=%%A"
      goto :eof
    )
  )
)
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

:: ===================== ana akis =====================

:main
set "EXITCODE=0"
cd /d "%~dp0" 2>nul
if errorlevel 1 (
  echo [HATA] Proje klasorune girilemedi:
  echo   %~dp0
  goto :fail
)

chcp 65001 >nul 2>&1

set "PACKAGE=com.hedefkamu.hedef_kamu"
set "ACTIVITY=%PACKAGE%/com.hedefkamu.hedef_kamu.MainActivity"
set "APK="
set "SERIAL="
set "ADB="

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
  goto :fail
)

set "PUB_CACHE=%~dp0.pub-cache"
if not exist "%PUB_CACHE%\" mkdir "%PUB_CACHE%" >nul 2>&1
if not exist "%PUB_CACHE%\" (
  echo [HATA] Pub onbellegi olusturulamadi: %PUB_CACHE%
  goto :fail
)

echo.
echo  ============================================================
echo   Hedef Kamu - guncel RELEASE APK derle + telefona kur
echo  ============================================================
echo.
echo   Telefon USB bagli, USB hata ayiklama acik olsun.
echo   "USB uzerinden yukleme" / Install via USB acik olsun.
echo   Ekranda izin penceresi cikarsa Tamam deyin.
echo.
echo   Akis: derle -^> eski uygulamayi SIL -^> yeni APK kur -^> ac
echo   Derleme 3-8 dk surebilir; pencereyi kapatmayin.
echo.
echo   Proje: %CD%
echo.

where flutter >nul 2>&1
if errorlevel 1 (
  echo [HATA] flutter PATH'te yok.
  echo   Beklenen: C:\flutter\flutter\bin
  goto :fail
)

call :find_adb
if not defined ADB (
  echo [HATA] adb bulunamadi. Android SDK platform-tools kurulu olsun.
  goto :fail
)

"%ADB%" start-server >nul 2>&1
call :resolve_device
if not defined SERIAL (
  echo [HATA] Telefon bulunamadi / yetkisiz.
  echo   USB baglayin, hata ayiklama iznini onaylayin.
  goto :fail
)

echo [OK] Cihaz: %SERIAL%
echo [.] Bagimliliklar...
echo.

call flutter pub get
if errorlevel 1 (
  echo [HATA] flutter pub get basarisiz.
  goto :fail
)

echo.
echo [.] Release APK derleniyor...
echo     ^(Birkac dakika surebilir; pencereyi kapatmayin.^)
echo.

call flutter build apk --release
if errorlevel 1 (
  echo [HATA] APK derlenemedi.
  goto :fail
)

echo.
echo [.] Release APK araniyor...
set "APK_CANDIDATE="

if exist "build\app\outputs\flutter-apk\app-release.apk" (
  set "APK_CANDIDATE=build\app\outputs\flutter-apk\app-release.apk"
  goto :apk_found
)

for /f "delims=" %%F in ('dir /b /s /o-d build\app\outputs\flutter-apk\*release*.apk 2^>nul') do (
  set "APK_CANDIDATE=%%F"
  goto :apk_found
)

for /f "delims=" %%F in ('dir /b /s /o-d build\app\outputs\apk\release\*release*.apk 2^>nul') do (
  set "APK_CANDIDATE=%%F"
  goto :apk_found
)

:apk_found
set "APK=%APK_CANDIDATE%"

if not defined APK (
  echo [HATA] Release APK bulunamadi.
  goto :fail
)
if "%APK%"=="" (
  echo [HATA] Release APK bulunamadi.
  goto :fail
)

echo [OK] APK: %APK%
dir "%APK%"

echo.
echo [.] ADB baglantisi yenileniyor...
"%ADB%" start-server >nul 2>&1
call :resolve_device
if not defined SERIAL (
  echo [HATA] Derleme sonrasi telefon kayboldu. USB'yi cikip takin, tekrar deneyin.
  goto :fail
)
echo [OK] Cihaz hazir: %SERIAL%

echo.
echo [.] Mevcut uygulama siliniyor: %PACKAGE%
"%ADB%" -s %SERIAL% shell am force-stop %PACKAGE% >nul 2>&1
"%ADB%" -s %SERIAL% uninstall %PACKAGE%
if errorlevel 1 (
  echo [!] Silinemedi veya zaten yok - kuruluma devam.
) else (
  echo [OK] Eski surum silindi.
)

echo.
echo [.] Yeni APK kuruluyor...
"%ADB%" -s %SERIAL% install "%APK%"
if errorlevel 1 (
  echo [!] adb install basarisiz - flutter install deneniyor...
  echo     Telefonda USB yukleme iznini onaylayin.
  call flutter install -d %SERIAL% --release
  if errorlevel 1 (
    echo.
    echo [HATA] Kurulum basarisiz.
    echo   Redmi / Xiaomi Gelistirici secenekleri:
    echo   - USB hata ayiklama
    echo   - USB hata ayiklama ^(Guvenlik ayarlari^)
    echo   - USB uzerinden yukleme / Install via USB
    goto :fail
  )
)

echo [.] Kurulum dogrulaniyor...
"%ADB%" -s %SERIAL% shell pm path %PACKAGE% >nul 2>&1
if errorlevel 1 (
  echo [HATA] Paket telefonda gorunmuyor - kurulum tamamlanamamis.
  goto :fail
)

echo [.] Uygulama aciliyor...
"%ADB%" -s %SERIAL% shell am start -n %ACTIVITY%
if errorlevel 1 (
  "%ADB%" -s %SERIAL% shell monkey -p %PACKAGE% -c android.intent.category.LAUNCHER 1 >nul 2>&1
)

echo.
echo [OK] Eski uygulama silindi, guncel APK kuruldu ve acildi.
echo.
goto :done

:fail
set "EXITCODE=1"
echo.
echo --- Islem basarisiz. Yukaridaki [HATA] satirina bakin. ---
echo.

:done
echo.
echo Pencereyi kapatmak icin bir tusa basin...
pause >nul
endlocal & exit /b %EXITCODE%
