@echo off
setlocal DisableDelayedExpansion
rem No downloads, installs, administrator access, or security-policy changes.
set "ENGINE="
if not "%~1"=="" set "ENGINE=%~f1"
if defined ENGINE goto engine_found
for /f "delims=" %%G in ('where godot.exe 2^>nul') do if not defined ENGINE set "ENGINE=%%G"
if defined ENGINE goto engine_found
for /f "delims=" %%G in ('where godot4.exe 2^>nul') do if not defined ENGINE set "ENGINE=%%G"
if defined ENGINE goto engine_found
echo Godot 4.6.3 was not found.
echo Run this launcher with the full path to your Godot executable:
echo   Play-MOKSHA.cmd "C:\Tools\Godot\Godot_v4.6.3-stable_win64_console.exe"
echo Or import project.godot in the Godot 4.6.3 editor and press F5.
echo See campaign\docs\PC_QUICKSTART.md.
exit /b 2
:engine_found
if not exist "%ENGINE%" (
  echo Godot executable not found: "%ENGINE%"
  exit /b 2
)
set "VERSION="
for /f "delims=" %%V in ('""%ENGINE%" --version 2^>nul"') do if not defined VERSION set "VERSION=%%V"
if not "%VERSION:~0,6%"=="4.6.3." (
  echo This checkpoint requires Godot 4.6.3. Detected: %VERSION%
  echo Choose the official Godot 4.6.3 executable. No engine was installed or changed.
  exit /b 3
)
echo Importing project assets with Godot %VERSION%...
"%ENGINE%" --headless --editor --path "%~dp0." --import
if errorlevel 1 (
  echo Asset import failed. Read the error above; the game was not started.
  exit /b 4
)
echo Starting MOKSHA...
"%ENGINE%" --path "%~dp0."
set "RESULT=%ERRORLEVEL%"
if not "%RESULT%"=="0" echo MOKSHA exited with code %RESULT%.
exit /b %RESULT%
