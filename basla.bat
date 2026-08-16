@echo off
chcp 65001 >nul
title KPSS Odak — Panel
cd /d "%~dp0"

echo.
echo  ========================================
echo   KPSS Odak — Icerik Paneli baslatiliyor
echo  ========================================
echo.
echo   Telefonu guncellemek icin:  basla-telefon.bat
echo   (USB bagla, sil-kur yok — uzerine yazar)
echo.

cd backend
if not exist manage.py (
  echo [HATA] backend\manage.py bulunamadi.
  pause
  exit /b 1
)

echo [1/2] Veritabani guncelleniyor...
python manage.py migrate --noinput
if errorlevel 1 (
  echo [HATA] migrate basarisiz.
  pause
  exit /b 1
)

echo [2/3] Admin kullanici kontrol ediliyor...
python manage.py ensure_admin
if errorlevel 1 (
  echo [HATA] admin kullanici olusturulamadi.
  pause
  exit /b 1
)

echo [3/3] Sunucu: http://127.0.0.1:8000/panel/
echo       Telefon API: http://192.168.1.109:8000  (PC IP degisirse api_config.dart guncelle)
echo       Admin : http://127.0.0.1:8000/admin/
echo.
echo  Durdurmak icin bu pencerede Ctrl+C
echo.

start "" "http://127.0.0.1:8000/panel/"
python manage.py runserver 0.0.0.0:8000

pause
