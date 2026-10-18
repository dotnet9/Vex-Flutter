@echo off
setlocal
rem Compatibility entry. The platform entry owns module isolation and pause.
call "%~dp0scripts\packaging\win-x64\build.bat" %*
exit /b %ERRORLEVEL%
