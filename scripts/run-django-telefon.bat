@echo off
rem Launcher: avoids nested quotes when PY path has spaces.
rem Usage: run-django-telefon.bat "C:\path\to\python.exe"
setlocal EnableExtensions
chcp 65001 >nul

if "%~1"=="" goto :no_py
set "PY=%~1"
if not exist "%PY%" goto :bad_py

cd /d "%~dp0..\backend"
if errorlevel 1 goto :bad_backend
if not exist "manage.py" goto :no_manage

echo [.] Django baslatiliyor...
echo [.] "%PY%" manage.py runserver 0.0.0.0:8000
echo.
"%PY%" manage.py runserver 0.0.0.0:8000
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" echo [HATA] Django cikti kod %RC%. Yukaridaki hataya bakin.
if "%RC%"=="0" echo [!] Django normal cikti kod %RC%.
echo [BITTI] Pencereyi kapatmak icin bir tusa basin.
pause
exit /b %RC%

:no_py
echo [HATA] Python yolu verilmedi.
goto :fail

:bad_py
echo [HATA] Python bulunamadi: %PY%
goto :fail

:bad_backend
echo [HATA] backend klasorune girilemedi.
goto :fail

:no_manage
echo [HATA] backend\manage.py bulunamadi.
goto :fail

:fail
echo.
echo [BITTI] Pencereyi kapatmak icin bir tusa basin.
pause
exit /b 1
