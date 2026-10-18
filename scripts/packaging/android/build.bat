@echo off
setlocal
python "%~dp0..\build.py" android %*
set "VEX_BUILD_EXIT=%ERRORLEVEL%"
if not defined VEX_NO_PAUSE pause
exit /b %VEX_BUILD_EXIT%
