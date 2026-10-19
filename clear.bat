@echo off
setlocal
rem 一键清理所有可再生的生成物。源代码、.git、签名、文档、字体资产不受影响。
rem 注意：artifacts 下的可运行构建也会删除；正在运行的 Vex 会锁住其文件，
rem 请先退出应用再执行，否则对应文件将被跳过。
set "ROOT=%~dp0"

echo [1/6] Flutter 构建输出（build/）...
if exist "%ROOT%apps\vex\build" rmdir /s /q "%ROOT%apps\vex\build"
if exist "%ROOT%build" rmdir /s /q "%ROOT%build"
for /d %%D in ("%ROOT%packages\*\build") do rmdir /s /q "%%~D"

echo [2/6] Dart 工具缓存（.dart_tool，pub get 自动重建）...
if exist "%ROOT%.dart_tool" rmdir /s /q "%ROOT%.dart_tool"
if exist "%ROOT%apps\vex\.dart_tool" rmdir /s /q "%ROOT%apps\vex\.dart_tool"

echo [3/6] 平台宿主生成物（ephemeral）...
if exist "%ROOT%apps\vex\windows\flutter\ephemeral" rmdir /s /q "%ROOT%apps\vex\windows\flutter\ephemeral"

echo [4/6] 测试与覆盖率输出...
if exist "%ROOT%apps\vex\coverage" rmdir /s /q "%ROOT%apps\vex\coverage"
for /d %%D in ("%ROOT%packages\*\coverage") do rmdir /s /q "%%~D"
del /q "%ROOT%apps\vex\flutter_*.log" 2>nul

echo [5/6] 生成的内嵌文档资产（sync_builtin_documents.py 可重建）...
if exist "%ROOT%apps\vex\assets\generated\documents" rmdir /s /q "%ROOT%apps\vex\assets\generated\documents"
if exist "%ROOT%design\assets\generated" rmdir /s /q "%ROOT%design\assets\generated"

echo [6/6] artifacts 本地产物（安装包、预览构建、日志）...
if exist "%ROOT%artifacts" rmdir /s /q "%ROOT%artifacts"

echo.
echo 清理完成（若上方有“拒绝访问”，请关闭正在运行的 Vex 后重跑）。
echo 下次构建前按顺序执行：
echo   1. flutter pub get
echo   2. python scripts\sync_builtin_documents.py
echo   3. powershell -ExecutionPolicy Bypass -File scripts\packaging\win-x64\Fix-PluginDirs.ps1
echo   4. flutter build windows --release --no-pub
echo   5. powershell -ExecutionPolicy Bypass -File scripts\packaging\win-x64\Fix-PluginDirs.ps1 -Restore
endlocal
