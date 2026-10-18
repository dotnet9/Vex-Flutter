@echo off
setlocal
python "%~dp0scripts\packaging\publish.py" %*
set "VEX_PUBLISH_EXIT=%ERRORLEVEL%"
if not defined VEX_NO_PAUSE pause
exit /b %VEX_PUBLISH_EXIT%
