@echo off
chcp 65001 >nul
title KPSS Akademi — Uygulamayı Yükle
cd /d "%~dp0"

set "PACKAGE=com.hedefkamu.hedef_kamu"
set "APK="

echo.
echo  ============================================================
echo   KPSS Akademi — bağlı telefona GÜNCEL RELEASE uygulamayı kur
echo  ============================================================
echo.
echo   Telefon USB ile bağlı olsun, USB hata ayıklama açık olsun.
echo   Ekranda "USB hata ayıklamaya izin ver" çıkarsa Tamam deyin.
echo.

where flutter >nul 2>&1
if errorlevel 1 (
  echo [HATA] flutter PATH'te yok.
  pause
  exit /b 1
)

call :find_adb
if not defined ADB (
  echo [HATA] adb bulunamadı. Android SDK platform-tools kurulu olsun.
  pause
  exit /b 1
)

"%ADB%" start-server >nul 2>&1

:wait_device
set "SERIAL="
for /f "tokens=1,2" %%A in ('"%ADB%" devices 2^>nul') do (
  if /I "%%B"=="unauthorized" (
    echo [!] Cihaz %%A yetkisiz — telefondaki izin penceresine Tamam deyin.
  )
  if /I "%%B"=="device" (
    echo %%A | findstr /I "emulator-" >nul
    if errorlevel 1 (
      set "SERIAL=%%A"
      goto have_device
    )
  )
)
for /f "tokens=1,2" %%A in ('"%ADB%" devices 2^>nul') do (
  if /I "%%B"=="device" (
    set "SERIAL=%%A"
    goto have_device
  )
)

echo [.] Android telefon bekleniyor (USB bağlayın)...
timeout /t 3 /nobreak >nul
goto wait_device

:have_device
echo [OK] Cihaz: %SERIAL%
echo [.] Derleniyor (birkaç dakika sürebilir)...
echo.

flutter pub get
if errorlevel 1 (
  echo [HATA] flutter pub get başarısız.
  pause
  exit /b 1
)

flutter clean
if errorlevel 1 (
  echo [HATA] flutter clean başarısız.
  pause
  exit /b 1
)

flutter build apk --release
if errorlevel 1 (
  echo [HATA] APK derlenemedi.
  pause
  exit /b 1
)

:: Build çıktısının bulunduğu yeri otomatik bul (Flutter sürümlerine göre path değişebiliyor)
echo.
echo [.] Release APK aranıyor...
set "APK_CANDIDATE="

:: 1) flutter-apk çıktısı (en yaygını)
for /f "delims=" %%F in ('dir /b /s build\app\outputs\flutter-apk\*release*.apk 2^>nul') do (
  set "APK_CANDIDATE=%%F"
  goto :apk_found
)

:: 2) apk çıktısı (alternatif)
for /f "delims=" %%F in ('dir /b /s build\app\outputs\apk\release\*release*.apk 2^>nul') do (
  set "APK_CANDIDATE=%%F"
  goto :apk_found
)

:apk_found
set "APK=%APK_CANDIDATE%"

if "%APK%"=="" (
  echo [HATA] Release APK bulunamadı. Build çıktısında hata olabilir.
  pause
  exit /b 1
)

echo [OK] APK bulundu: %APK%
dir "%APK%"

echo.
echo [.] Telefondaki eski sürüm kaldırılıyor...
"%ADB%" -s %SERIAL% uninstall %PACKAGE% >nul 2>&1

:: Uninstall başarısız olursa (hata/izin), pm uninstall dene
%ADB% -s %SERIAL% shell pm uninstall %PACKAGE% >nul 2>&1

echo [.] Telefona kuruluyor (release)...
"%ADB%" -s %SERIAL% install -r "%APK%"
if errorlevel 1 (
  echo [HATA] Kurulum başarısız. USB kablo / hata ayıklama iznini kontrol edin.
  pause
  exit /b 1
)

echo [.] Uygulama açılıyor...
"%ADB%" -s %SERIAL% shell monkey -p %PACKAGE% -c android.intent.category.LAUNCHER 1 >nul 2>&1
if errorlevel 1 (
  "%ADB%" -s %SERIAL% shell am start -n %PACKAGE%/com.hedefkamu.hedef_kamu.MainActivity >nul 2>&1
)

echo.
echo [OK] Güncel uygulama telefona kuruldu ve açıldı.
echo     (Hedef Kamu)
echo.
pause
exit /b 0

:find_adb
set "ADB="
where adb >nul 2>&1
if not errorlevel 1 (
  for /f "delims=" %%A in ('where adb') do (
    set "ADB=%%A"
    goto :eof
  )
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
)