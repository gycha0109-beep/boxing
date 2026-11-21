@echo off
cd /d "%~dp0"
powershell -NoProfile -Command "try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 'http://127.0.0.1:8766/my-league/index.html' | Out-Null; exit 0 } catch { exit 1 }" >nul 2>nul
if errorlevel 1 (
  start "Twelve Count Web Server" /min python "%~dp0serve_preview.py"
  timeout /t 2 /nobreak >nul
)
start "" "http://127.0.0.1:8766/my-league/index.html"
