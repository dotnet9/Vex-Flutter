[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Installer,
    [switch] $InstallerTest
)
$ErrorActionPreference = 'Stop'
if (-not $InstallerTest) { throw 'Run only against an isolated -InstallerTest package.' }
$path = (Resolve-Path -LiteralPath $Installer).Path
$token = [guid]::NewGuid().ToString('N')
$base = 'Local\Vex.Update.' + $token
$ready = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, "$base.Ready")
$proceed = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, "$base.Proceed")
$cancel = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, "$base.Cancel")
$process = $null
try {
    $process = Start-Process -FilePath $path -ArgumentList @('/SP-', "/VEXUPDATEREADY=$base.Ready", "/VEXUPDATEPROCEED=$base.Proceed", "/VEXUPDATECANCEL=$base.Cancel") -WindowStyle Hidden -PassThru
    if (-not $ready.WaitOne(20000)) { throw 'The real installer did not acknowledge readiness.' }
    if ($process.HasExited) { throw 'The installer exited before the save decision.' }
    Start-Sleep -Milliseconds 250
    # Simulate cancelling Vex's unsaved-document prompt. No files are installed.
    $cancel.Set() | Out-Null
    if (-not $process.WaitForExit(15000)) { throw 'The pending installer ignored cancellation.' }
    if ($proceed.WaitOne(0)) { throw 'The installer approved itself without the app.' }
    Write-Output 'Native Windows update readiness / pending save decision / cancellation passed. No installation was started.'
} finally {
    $cancel.Set() | Out-Null
    if ($null -ne $process -and -not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
    $ready.Dispose()
    $proceed.Dispose()
    $cancel.Dispose()
}
