@echo off
rem 성냥갑 AI (Godot) 실행. 전체화면으로 시작하고, F11로 창 모드와 바꾼다.
rem Godot는 winget install GodotEngine.GodotEngine 으로 설치한 것을 쓴다.
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe
if not exist "%GODOT%" (
  echo Godot not found: %GODOT%
  pause
  exit /b 1
)
start "" "%GODOT%" --path "%~dp0" --fullscreen
