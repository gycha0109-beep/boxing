@echo off
setlocal
cd /d "%~dp0"
set "GODOT=D:\cha\.toolcache\godot\4.7.2\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" set "GODOT=D:\cha\.toolcache\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT%" (
  echo Godot 4.7.2 executable not found.
  pause
  exit /b 1
)
start "Twelve Count - Live UI" "%GODOT%" --editor --path "%~dp0"
endlocal
