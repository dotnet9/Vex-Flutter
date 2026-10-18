param(
    [Parameter(Mandatory=$true)][string]$Executable,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$executablePath = (Resolve-Path -LiteralPath $Executable).Path
$outputPath = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($outputPath) | Out-Null
$started = Get-Date
$results = @()
$previousMode = $env:VEX_CLOSE_MODE
$previousResult = $env:VEX_CLOSE_RESULT
try {
    foreach ($mode in @('clean', 'draft')) {
        $resultFile = Join-Path $outputPath "$mode.json"
        if (Test-Path -LiteralPath $resultFile) {
            throw "Use a fresh output directory; $resultFile already exists."
        }
        $env:VEX_CLOSE_MODE = $mode
        $env:VEX_CLOSE_RESULT = $resultFile
        $timer = [Diagnostics.Stopwatch]::StartNew()
        $process = Start-Process -FilePath $executablePath -PassThru -WindowStyle Hidden
        if (!$process.WaitForExit(45000)) {
            throw "Probe process $($process.Id) did not exit within 45 seconds."
        }
        $timer.Stop()
        if ($process.ExitCode -ne 0) {
            throw "Probe exited with code $($process.ExitCode); inspect $resultFile.error."
        }
        $result = Get-Content -LiteralPath $resultFile -Raw | ConvertFrom-Json
        if (!$result.recoveryFlushed -or $result.mode -ne $mode) {
            throw 'Missing recovery checkpoint for this run.'
        }
        if ($mode -eq 'clean' -and $result.documents.Count -ne 0) {
            throw 'Clean close unexpectedly persisted a dirty document.'
        }
        if ($mode -eq 'draft' -and (
            !$result.cancelVerified -or $result.documents.Count -ne 1 -or
            $result.documents[0].text -cne "# Release 关闭草稿🧵`r`n保留内容`n"
        )) {
            throw 'Draft content or close cancellation did not match.'
        }
        $results += [PSCustomObject]@{
            mode=$mode; exitCode=$process.ExitCode
            processLifetimeMs=[Math]::Round($timer.Elapsed.TotalMilliseconds,1)
            recoveryFlushed=$result.recoveryFlushed; cancelVerified=$result.cancelVerified
        }
    }
} finally {
    $env:VEX_CLOSE_MODE = $previousMode
    $env:VEX_CLOSE_RESULT = $previousResult
}
Start-Sleep -Seconds 2
$events = @(Get-WinEvent -FilterHashtable @{
    LogName='Application'; Id=@(1000,1001); StartTime=$started
} -ErrorAction SilentlyContinue | Where-Object {
    $_.Message -match 'vex\.exe|flutter_windows\.dll'
})
if ($events.Count -gt 0) { throw 'A Vex crash event was recorded during the probe.' }
[PSCustomObject]@{completed=$true; closes=$results; crashEvents=$events.Count} |
    ConvertTo-Json -Depth 4 |
    Tee-Object -FilePath (Join-Path $outputPath 'summary.json')
