# Work around Windows 11 24H2+ "untrusted mount point" traversal blocks that
# break Flutter's .plugin_symlinks on non-elevated shells without Developer
# Mode: copy each Windows plugin package into .plugin_symlinks as real
# directories and empty the windows plugin list so `flutter build` skips
# symlink creation entirely. Run before `flutter build windows --no-pub`.
#
# Usage:  powershell -File Fix-PluginDirs.ps1 [-AppDir apps\vex] [-Restore]
# Restore puts the original .flutter-plugins-dependencies back (use after
# building, or before running flutter pub get again).
param(
    [string] $AppDir = 'apps/vex',
    [switch] $Restore
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$pluginsFile = Join-Path $root "$AppDir/.flutter-plugins-dependencies"
$backup = "$pluginsFile.fix-backup"
$linkDir = Join-Path $root "$AppDir/windows/flutter/ephemeral/.plugin_symlinks"

if ($Restore) {
    if (Test-Path $backup) {
        Copy-Item $backup $pluginsFile -Force
        Remove-Item $backup -Force
        Write-Host "Restored $pluginsFile"
    } else {
        Write-Warning "No backup found at $backup"
    }
    exit 0
}

$cfg = Get-Content $pluginsFile -Raw | ConvertFrom-Json
$windowsPlugins = @($cfg.plugins.windows | ForEach-Object { $_ })
if ($windowsPlugins.Count -eq 0 -and (Test-Path $linkDir)) {
    Write-Host 'Windows plugin list already empty; nothing to do.'
    exit 0
}

if (-not (Test-Path $backup)) { Copy-Item $pluginsFile $backup -Force }
$cfg.plugins.windows = @()
$cfg | ConvertTo-Json -Depth 20 | Set-Content $pluginsFile -Encoding UTF8

New-Item -ItemType Directory -Path $linkDir -Force | Out-Null
foreach ($plugin in $windowsPlugins) {
    $dest = Join-Path $linkDir $plugin.name
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    robocopy $plugin.path $dest /E /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed for $($plugin.name)" }
    Write-Host "Copied $($plugin.name)"
}
Write-Host "Plugin dirs ready. Build with: flutter build windows --release --no-pub"
Write-Host "Afterwards restore: powershell -File Fix-PluginDirs.ps1 -Restore"
