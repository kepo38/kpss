@echo off
chcp 65001 >nul
title KPSS Odak — Telefon (otomatik guncelle)
cd /d "%~dp0"

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
