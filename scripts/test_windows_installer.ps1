[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Installer,
    [Parameter(Mandatory)] [string] $Version,
    [switch] $InstallerTest
)
$ErrorActionPreference = 'Stop'
$appId = '{51E79E85-AD4C-4D48-92EC-C1EA09FB4E56}'
if ($InstallerTest) { $appId = 'Texweft.Installer.Test' }
$registryPath = "Software\Microsoft\Windows\CurrentVersion\Uninstall\${appId}_is1"
foreach ($hive in @('HKCU:', 'HKLM:')) {
    if (Test-Path -LiteralPath "$hive\$registryPath") { throw 'An existing installation was found. Run this smoke test on a clean account or runner.' }
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
$registration = Get-ItemProperty -LiteralPath "HKCU:\$registryPath"
$expectedName = '维刻 Vex'
if ($InstallerTest) { $expectedName = 'Vex Installer Test' }
if ($registration.DisplayName -ne $expectedName -or $registration.DisplayVersion -ne $Version) { throw 'Installed brand or version registration mismatch.' }
# Reinstall the same package to restore a missing application file without touching documents.
$preserved = Join-Path $directory 'user-document.md'
Set-Content -LiteralPath $preserved -Value '# keep this document' -Encoding utf8
$repairedFile = Join-Path $app 'data/app.so'
$repairedHash = (Get-FileHash -LiteralPath $repairedFile -Algorithm SHA256).Hash
Remove-Item -LiteralPath $repairedFile
$repair = Start-Process -FilePath (Resolve-Path -LiteralPath $Installer).Path -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', ('/DIR="' + $app + '"'), ('/LOG="' + $directory + '/repair.log"')) -WindowStyle Hidden -Wait -PassThru
if ($repair.ExitCode -ne 0 -or (Get-FileHash -LiteralPath $repairedFile -Algorithm SHA256).Hash -ne $repairedHash) { throw "Repair did not restore application files; evidence: $directory" }
$uninstall = Start-Process -FilePath (Join-Path $app 'unins000.exe') -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', ('/LOG="' + $directory + '/uninstall.log"')) -WindowStyle Hidden -Wait -PassThru
if ($uninstall.ExitCode -ne 0) { throw "Uninstaller failed: $($uninstall.ExitCode)" }
if (Test-Path -LiteralPath (Join-Path $app 'texweft.exe')) { throw 'Uninstaller left the executable behind.' }
if (Test-Path -LiteralPath "HKCU:\$registryPath") { throw 'Uninstaller left its product registration behind.' }
if ((Get-Content -LiteralPath $preserved -Raw).Trim() -ne '# keep this document') { throw 'The independent document was changed.' }
Write-Output "Installer / brand / files / version / repair / uninstaller / document preservation passed; evidence: $directory"
