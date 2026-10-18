@echo off
setlocal
rem Use Windows PowerShell modules even when launched from a PowerShell 7 terminal.
set "PSModulePath=%SystemRoot%\System32\WindowsPowerShell\v1.0\Modules"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" %*
set "VEX_BUILD_EXIT=%ERRORLEVEL%"
if not defined VEX_NO_PAUSE pause
exit /b %VEX_BUILD_EXIT%
