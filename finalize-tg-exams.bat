@echo off
REM TG denemeleri — süresi dolan oturumların sonuçlarini yayinlar (Task Scheduler ile).
cd /d "%~dp0backend"
python manage.py finalize_tg_exams
pause
