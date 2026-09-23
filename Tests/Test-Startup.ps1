param([string]$OutputDirectory)
$ErrorActionPreference='Stop'
[void][IO.Directory]::CreateDirectory($OutputDirectory)
$root=Split-Path -Parent $PSScriptRoot
$fixture=Join-Path $OutputDirectory "Printer Tools (QA) & O'Brien !\测试"
[void][IO.Directory]::CreateDirectory((Join-Path $fixture 'Core'))
Copy-Item -LiteralPath (Join-Path $root 'Core\Launcher.ps1') -Destination (Join-Path $fixture 'Core\Launcher.ps1')
Copy-Item -LiteralPath (Join-Path $root 'Core\Toolkit.ps1') -Destination (Join-Path $fixture 'Core\Toolkit.ps1')
$validationOutput=& powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fixture 'Core\Launcher.ps1') -ValidateOnly
if($LASTEXITCODE -ne 0){throw "Special-path launcher validation failed: $LASTEXITCODE"}
if(($validationOutput -join "`n") -notmatch 'syntax OK'){throw 'Launcher validation did not reach the toolkit parser.'}
$bat=Get-Content -LiteralPath (Join-Path $root 'PrinterToolkit.bat') -Raw
if($bat -match '-Command'){throw 'BAT must not interpolate its path into PowerShell -Command.'}
Write-Host 'PASS: launcher validates from apostrophe, ampersand, spaces, exclamation and Unicode path.'
return 2
