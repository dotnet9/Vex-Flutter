[CmdletBinding()]
param(
    [string] $Flutter = '',
    [string] $Compiler = '',
    [string] $OutputDirectory = '',
    [switch] $SkipTests,
    [switch] $NoOpenFolder,
    [switch] $CheckOnly
)
$ErrorActionPreference = 'Stop'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$releaseTools = Join-Path $root 'scripts/packaging/shared/release_tools.py'

function Invoke-Checked {
    param([string] $Executable, [string[]] $Arguments)
    & $Executable @Arguments | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed ($LASTEXITCODE): $Executable $($Arguments -join ' ')"
    }
}

function Find-Flutter {
    param([string] $ExplicitPath)
    if (-not $ExplicitPath) { $ExplicitPath = $env:VEX_FLUTTER }
    if (-not $ExplicitPath -and $env:FLUTTER_ROOT) {
        $ExplicitPath = Join-Path $env:FLUTTER_ROOT 'bin/flutter.bat'
    }
    if ($ExplicitPath) {
        if (-not (Test-Path -LiteralPath $ExplicitPath -PathType Leaf)) {
            throw "Flutter was not found: $ExplicitPath"
        }
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }
    $command = Get-Command flutter.bat -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }

    # A previously resolved workspace can locate its SDK without a machine path in Git.
    $configPath = Join-Path $root '.dart_tool/package_config.json'
    if (Test-Path -LiteralPath $configPath -PathType Leaf) {
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        $entry = $config.packages | Where-Object name -eq 'flutter' | Select-Object -First 1
        if ($entry) {
            $uri = [Uri]::new([Uri]$configPath, [string]$entry.rootUri)
            if ($uri.IsFile) {
                $candidate = [IO.Path]::GetFullPath((Join-Path $uri.LocalPath '../../bin/flutter.bat'))
                if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
            }
        }
    }
    throw 'Install the pinned Flutter SDK and add its bin to PATH, or pass -Flutter C:\tools\flutter\bin\flutter.bat.'
}

$exitCode = 0
$transcribing = $false
Push-Location $root
try {
    if ($env:OS -ne 'Windows_NT') { throw 'This entry builds Windows installers on Windows only.' }
    $hostArchitecture = $env:PROCESSOR_ARCHITECTURE
    if ($env:PROCESSOR_ARCHITEW6432) { $hostArchitecture = $env:PROCESSOR_ARCHITEW6432 }
    if ($hostArchitecture -ne 'AMD64') { throw 'win-x64 requires an x64 Windows host; ARM64 cross-compilation is not configured.' }
    $logDirectory = Join-Path $root 'artifacts/build-logs'
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    $log = Join-Path $logDirectory ("windows-{0:yyyyMMdd-HHmmss-fff}.log" -f (Get-Date))
    Start-Transcript -LiteralPath $log | Out-Null
    $transcribing = $true
    Write-Host 'Vex local Windows installer build. No Git push, upload or application installation.'
    Write-Host "Log: $log"

    $flutterPath = Find-Flutter $Flutter
    $pythonCommand = Get-Command python -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $pythonCommand) { throw 'Install Python 3.11+ and enable its python command in PATH.' }
    $python = $pythonCommand.Source
    Invoke-Checked -Executable $python -Arguments @('-c', 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)')
    $metadataJson = & $python $releaseTools metadata
    if ($LASTEXITCODE -ne 0) { throw 'Unable to read application version metadata.' }
    $metadata = $metadataJson | ConvertFrom-Json
    $sdkJson = & $flutterPath --suppress-analytics --version --machine
    if ($LASTEXITCODE -ne 0) { throw 'Flutter SDK could not start.' }
    $sdk = $sdkJson | ConvertFrom-Json
    if ($sdk.frameworkVersion -ne $metadata.flutter) {
        throw "Flutter $($metadata.flutter) is required; found $($sdk.frameworkVersion). This script does not upgrade the SDK."
    }
    $dart = Join-Path $sdk.flutterRoot 'bin/dart.bat'
    if (-not (Test-Path -LiteralPath $dart -PathType Leaf)) { throw 'The Flutter SDK has no bundled Dart executable.' }
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) {
        throw 'Install Visual Studio with Desktop development with C++ (including the Windows SDK).'
    }
    $visualStudio = & $vswhere -latest -prerelease -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($LASTEXITCODE -ne 0 -or -not $visualStudio) { throw 'Visual Studio C++ desktop tools were not found.' }
    if ($Compiler -and -not (Test-Path -LiteralPath $Compiler -PathType Leaf)) {
        throw "Inno Setup compiler was not found: $Compiler"
    }
    Write-Host "Flutter: $flutterPath ($($sdk.frameworkVersion))"
    Write-Host "Application: $($metadata.version)+$($metadata.build)"
    Write-Host "Visual Studio: $visualStudio"
    if ($CheckOnly) {
        Write-Host 'Prerequisites checked. Inno Setup will be obtained by the pinned, checksum-verified helper when building.'
    } else {
        $env:PUB_HOSTED_URL = 'https://pub.dev'
        if (-not $env:CMAKE_BUILD_PARALLEL_LEVEL) { $env:CMAKE_BUILD_PARALLEL_LEVEL = '2' }
        if (-not $env:CL) { $env:CL = '/MP1' }
        Invoke-Checked -Executable $flutterPath -Arguments @('pub', 'get', '--enforce-lockfile')
        if ($SkipTests) {
            Write-Warning 'Tests were explicitly skipped. This local installer is not a substitute for CI validation.'
        } else {
            Invoke-Checked -Executable $flutterPath -Arguments @('analyze', '--no-pub')
            Push-Location (Join-Path $root 'packages/vex_markdown_core')
            try { Invoke-Checked -Executable $dart -Arguments @('test', '--concurrency=2') } finally { Pop-Location }
            foreach ($project in @('packages/vex_editor', 'packages/vex_mindmap', 'apps/vex')) {
                Push-Location (Join-Path $root $project)
                try { Invoke-Checked -Executable $flutterPath -Arguments @('test', '--no-pub', '--concurrency=2') } finally { Pop-Location }
            }
            Invoke-Checked -Executable $python -Arguments @('-m', 'unittest', 'discover', '-s', 'scripts/tests', '-v')
        }
        if (-not $Compiler) { $Compiler = & (Join-Path $PSScriptRoot 'install_inno.ps1') }
        Push-Location (Join-Path $root 'apps/vex')
        try {
            Invoke-Checked -Executable $flutterPath -Arguments @('build', 'windows', '--release', '--target', 'lib/main.dart')
        } finally { Pop-Location }

        $output = Join-Path $root "artifacts/local/win-x64/v$($metadata.version)-build$($metadata.build)"
        if ($OutputDirectory) {
            $output = [IO.Path]::GetFullPath($OutputDirectory)
        }
        & (Join-Path $PSScriptRoot 'package.ps1') -Version $metadata.version -Compiler $Compiler -OutputDirectory $output | Out-Host
        if (-not $?) { throw 'Windows installer packaging failed.' }
        Invoke-Checked -Executable $python -Arguments @($releaseTools, 'checksums', '--directory', $output, '--targets', 'windows-x64')
        Invoke-Checked -Executable $python -Arguments @($releaseTools, 'verify', '--directory', $output, '--targets', 'windows-x64')
        $installerPath = Join-Path $output "Vex-v$($metadata.version)-windows-x64-setup.exe"
        Write-Host "READY: $installerPath"
        Write-Host 'Double-click this setup file to install. The build script does not install or launch Vex.'
        if (-not $NoOpenFolder) { Invoke-Item -LiteralPath $output }
    }
} catch {
    $exitCode = 1
    Write-Host "BUILD FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
    if ($log) { Write-Host "See log: $log" }
} finally {
    if ($transcribing) { Stop-Transcript | Out-Null }
    Pop-Location
}
exit $exitCode
