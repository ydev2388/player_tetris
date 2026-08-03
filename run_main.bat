@echo off
setlocal
set "GAME_EXE=%~dp0build\kungfu_tetris_main.exe"

if not exist "%GAME_EXE%" (
    echo [ERROR] build\kungfu_tetris_main.exe was not found.
    echo Run build_main.ps1 first.
    pause
    exit /b 1
)

start "" "%GAME_EXE%"
endlocal
