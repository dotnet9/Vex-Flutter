[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Version,
    [Parameter(Mandatory)] [string] $Compiler,
    [string] $BundleDirectory = '',
    [string] $OutputDirectory = '',
    [switch] $InstallerTest,
    [ValidatePattern('^Texweft\.Installer\.Test(?:[.-][A-Za-z0-9_-]+)*$')]
    [ValidateLength(1, 100)]
    [string] $InstallerTestId = 'Texweft.Installer.Test'
)
$ErrorActionPreference = 'Stop'
if (-not $InstallerTest -and $InstallerTestId -ne 'Texweft.Installer.Test') {
    throw 'A custom test identity requires -InstallerTest.'
}
$root = Split-Path -Parent $PSScriptRoot
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Version must be x.y.z.' }
if (-not $BundleDirectory) { $BundleDirectory = Join-Path $root 'apps/texweft/build/windows/x64/runner/Release' }
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $root 'artifacts/release' }
$bundle = (Resolve-Path -LiteralPath $BundleDirectory).Path
$output = [IO.Path]::GetFullPath($OutputDirectory)
if ($InstallerTest -and $output -eq [IO.Path]::GetFullPath((Join-Path $root 'artifacts/release'))) {
    throw 'Test installers must use a separate output directory.'
}
foreach ($required in @('texweft.exe', 'flutter_windows.dll', 'data/app.so', 'data/icudtl.dat', 'data/flutter_assets/AssetManifest.bin')) {
    if (-not (Test-Path -LiteralPath (Join-Path $bundle $required) -PathType Leaf)) { throw "Release bundle is incomplete: $required" }
}
$binaryVersion = (Get-Item -LiteralPath (Join-Path $bundle 'texweft.exe')).VersionInfo.ProductVersion.Split('+')[0]
if ($binaryVersion -ne $Version) { throw "Executable version $binaryVersion does not match $Version." }
# App-local Microsoft runtime: a fresh machine must not rely on a developer's VS installation.
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$vs = & $vswhere -latest -prerelease -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ($LASTEXITCODE -ne 0 -or -not $vs) { throw 'Visual C++ redistributable location is unavailable.' }
$crt = Get-ChildItem -Path (Join-Path $vs 'VC/Redist/MSVC/*/x64/Microsoft.VC*.CRT') -Directory | Sort-Object FullName -Descending | Select-Object -First 1
if (-not $crt) { throw 'Visual C++ app-local runtime was not found.' }
Copy-Item -Path (Join-Path $crt.FullName '*.dll') -Destination $bundle -Force
Copy-Item -LiteralPath (Join-Path $root 'LICENSE') -Destination (Join-Path $bundle 'LICENSE.txt') -Force
New-Item -ItemType Directory -Path $output -Force | Out-Null
$defines = @("/DAppVersion=$Version", "/DSourceDir=$bundle", "/DOutputDir=$output")
if ($InstallerTest) { $defines += @('/DInstallerTest', "/DInstallerTestId=$InstallerTestId") }
& $Compiler @defines (Join-Path $PSScriptRoot 'installer/Texweft.iss')
if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed: $LASTEXITCODE" }
$installer = Join-Path $output "Vex-v$Version-windows-x64-setup.exe"
if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) { throw 'Windows installer was not produced.' }
Write-Output $installer
