@echo off
REM Mini deneme haftalik/aylik odul finalize (Task Scheduler icin).
REM Onerilen: her gun 00:15 (Europe/Istanbul) calistir.
REM Ornek: schtasks /Create /TN "HedefKamuMiniOdul" /SC DAILY /ST 00:15 /TR "D:\HEDEFKAMU\finalize-mini-oduller.bat"

setlocal
cd /d "D:\HEDEFKAMU\backend" || exit /b 1

if exist "D:\HEDEFKAMU\.venv\Scripts\python.exe" (
  set "PY=D:\HEDEFKAMU\.venv\Scripts\python.exe"
) else if exist "D:\HEDEFKAMU\backend\.venv\Scripts\python.exe" (
  set "PY=D:\HEDEFKAMU\backend\.venv\Scripts\python.exe"
) else (
  set "PY=python"
)

"%PY%" manage.py finalize_daily_mini_ranking --auto
set ERR=%ERRORLEVEL%
echo [%DATE% %TIME%] finalize_daily_mini_ranking --auto exit=%ERR%
exit /b %ERR%
