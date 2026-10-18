[CmdletBinding()]
param([string] $Destination = (Join-Path ([IO.Path]::GetTempPath()) 'vex-inno-6.7.2'))
$ErrorActionPreference = 'Stop'
$compiler = Join-Path $Destination 'ISCC.exe'
if (-not (Test-Path -LiteralPath $compiler)) {
    $download = Join-Path ([IO.Path]::GetTempPath()) 'vex-innosetup-6.7.2.exe'
    $expected = '9f27f8386e554eb093336a1ca5c2dcacb7dbf04ab020889491d7ac53c38a12ff'
    $cached = (Test-Path -LiteralPath $download -PathType Leaf) -and
        ((Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash -eq $expected)
    if (-not $cached) {
        Invoke-WebRequest 'https://github.com/jrsoftware/issrc/releases/download/is-6_7_2/innosetup-6.7.2.exe' -UseBasicParsing -TimeoutSec 60 -OutFile $download
    }
    if ((Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash -ne $expected) { throw 'Inno Setup download checksum mismatch.' }
    if ((Get-AuthenticodeSignature -LiteralPath $download).Status -ne 'Valid') { throw 'Inno Setup publisher signature is invalid.' }
    $process = Start-Process -FilePath $download -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CURRENTUSER', ('/DIR="' + $Destination + '"')) -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "Inno Setup installation failed: $($process.ExitCode)" }
}
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) { throw 'ISCC.exe was not installed.' }
Write-Output $compiler
