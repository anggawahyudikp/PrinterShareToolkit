@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Printer Share Toolkit v1.1.2

rem Paths are passed as data to -File, never interpolated into PowerShell code.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Core\Launcher.ps1"
set "PSTK_EXIT=%errorlevel%"

if not "%PSTK_EXIT%"=="0" (
  echo.
  echo Toolkit exited with code %PSTK_EXIT%.
)
exit /b %PSTK_EXIT%
