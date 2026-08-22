@echo off
chcp 65001 >nul
title HEDEF Kamu - Telegram Zamanlayici Kurulumu

set "ROOT=D:\HEDEFKAMU"
set "PS1=%ROOT%\scripts\register-telegram-scheduled-task.ps1"

if not exist "%PS1%" (
  echo [HATA] Script bulunamadi: %PS1%
  pause
  exit /b 1
)

echo.
echo  ============================================================
echo   Otomatik Telegram aktarimi (PC acilinca)
echo  ============================================================
echo.
echo   IS YERINDEN:
echo     Telefon/Telegram ile @hedefkamubot'a soru fotografi gonderin.
echo     PC acik olmasi gerekmez — Telegram ~24 saat kuyrukta tutar.
echo.
echo   EVDE:
echo     Windows oturumu acilinca (sifre girisinden ~45 sn sonra)
echo     TELEGRAM.bat /auto sessizce calisir, kuyrugu isler, kapanir.
echo     Panel: Onay bekleyen sorular
echo.
echo   LOG: %ROOT%\logs\telegram-auto.log
echo.
echo   Not: Uyku modundan uyandirma oturum acilisi sayilmaz;
echo        o zaman TELEGRAM.bat'i bir kez elle calistirin.
echo.
echo   Kurulum icin Yonetici gerekmez; basarisiz olursa sag tik
echo   -^> Yonetici olarak calistir deneyin.
echo.
pause

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Register
set "RC=%ERRORLEVEL%"

echo.
if not "%RC%"=="0" (
  echo [HATA] Kurulum basarisiz (kod %RC%).
  echo        KUR-TELEGRAM-ZAMANLAYICI.bat -^> sag tik -^> Yonetici olarak calistir
) else (
  echo [OK] Otomatik aktarim kuruldu.
  echo.
  echo Yontemlerden biri aktif olur:
  echo   A^) Gorev Zamanlayicisi ^(HEDEFKamu-TelegramDrain^) — yonetici ile
  echo   B^) Baslangic klasoru ^(Startup^) — yonetici gerekmez
  echo.
  echo Kontrol: Gorev Zamanlayicisi veya
  echo   %%APPDATA%%\Microsoft\Windows\Start Menu\Programs\Startup\
  echo   icinde HEDEFKamu-Telegram-Auto.bat
  echo.
  echo Test: PC yeniden baslat / oturumu kapat-ac
  echo Log : %ROOT%\logs\telegram-auto.log
  echo Kaldir: KALDIR-TELEGRAM-ZAMANLAYICI.bat
)
echo.
pause
exit /b %RC%
