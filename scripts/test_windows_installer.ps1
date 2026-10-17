[CmdletBinding()]
param([Parameter(Mandatory)] [string] $Installer, [Parameter(Mandatory)] [string] $Version)
$ErrorActionPreference = 'Stop'
foreach ($key in @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{51E79E85-AD4C-4D48-92EC-C1EA09FB4E56}_is1', 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{51E79E85-AD4C-4D48-92EC-C1EA09FB4E56}_is1')) {
    if (Test-Path -LiteralPath $key) { throw 'An existing Texweft installation was found. Run this smoke test on a clean account or runner.' }
}
$directory = Join-Path ([IO.Path]::GetTempPath()) ('texweft-install-test-' + [guid]::NewGuid().ToString('N'))
$app = Join-Path $directory 'app'
New-Item -ItemType Directory -Path $directory | Out-Null
$install = Start-Process -FilePath (Resolve-Path -LiteralPath $Installer).Path -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', ('/DIR="' + $app + '"'), ('/LOG="' + $directory + '/install.log"')) -WindowStyle Hidden -Wait -PassThru
if ($install.ExitCode -ne 0) { throw "Installer failed: $($install.ExitCode); evidence: $directory" }
foreach ($file in @('texweft.exe', 'flutter_windows.dll', 'vcruntime140.dll', 'msvcp140.dll', 'data/app.so', 'data/icudtl.dat', 'data/flutter_assets/AssetManifest.bin', 'LICENSE.txt', 'unins000.exe')) {
    if (-not (Test-Path -LiteralPath (Join-Path $app $file))) { throw "Installed file missing: $file; evidence: $directory" }
}
if ((Get-Item -LiteralPath (Join-Path $app 'texweft.exe')).VersionInfo.ProductVersion.Split('+')[0] -ne $Version) { throw 'Installed executable version mismatch.' }
$uninstall = Start-Process -FilePath (Join-Path $app 'unins000.exe') -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', ('/LOG="' + $directory + '/uninstall.log"')) -WindowStyle Hidden -Wait -PassThru
if ($uninstall.ExitCode -ne 0) { throw "Uninstaller failed: $($uninstall.ExitCode)" }
if (Test-Path -LiteralPath (Join-Path $app 'texweft.exe')) { throw 'Uninstaller left the executable behind.' }
Write-Output "Installer / files / version / uninstaller passed; evidence: $directory"
