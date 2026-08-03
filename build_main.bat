@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_main.ps1" %*
set "BUILD_EXIT_CODE=%ERRORLEVEL%"
endlocal & exit /b %BUILD_EXIT_CODE%
