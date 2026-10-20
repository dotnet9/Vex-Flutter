@echo off
setlocal
call "%~dp0scripts\packaging\win-x64\build.bat" %*
exit /b %ERRORLEVEL%
