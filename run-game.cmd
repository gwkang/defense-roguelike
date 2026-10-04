@echo off
setlocal

rem Anchor the game path to this script, not the caller's current directory.
set "GAME_DIR=%~dp0."
set "LOVE_DIR=C:\Program Files\LOVE"

if not exist "%GAME_DIR%\main.lua" goto missing_game
if /I "%~1"=="--smoke" goto smoke

if not exist "%LOVE_DIR%\love.exe" goto missing_love
start "" /D "%GAME_DIR%" "%LOVE_DIR%\love.exe" "%GAME_DIR%"
exit /b %ERRORLEVEL%

:smoke
if not exist "%LOVE_DIR%\lovec.exe" goto missing_love
"%LOVE_DIR%\lovec.exe" "%GAME_DIR%" --smoke
exit /b %ERRORLEVEL%

:missing_game
>&2 echo [ERROR] main.lua not found beside run-game.cmd: "%GAME_DIR%"
exit /b 1

:missing_love
>&2 echo [ERROR] LOVE not found in "%LOVE_DIR%". Install LOVE 11.5 or update LOVE_DIR in run-game.cmd.
exit /b 1
