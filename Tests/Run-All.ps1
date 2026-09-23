[CmdletBinding()]
param([string]$OutputDirectory=(Join-Path $env:TEMP ('PSTK-tests-'+[guid]::NewGuid().ToString('N'))))
$ErrorActionPreference='Stop'
[void][IO.Directory]::CreateDirectory($OutputDirectory)
$total=0
foreach($name in @('Test-Parse.ps1','Test-Startup.ps1','Test-Core.ps1','Test-Rollback.ps1','Test-Packaging.ps1')){
    Write-Host ('Running '+$name) -ForegroundColor Cyan
    $result=& (Join-Path $PSScriptRoot $name) -OutputDirectory (Join-Path $OutputDirectory ([IO.Path]::GetFileNameWithoutExtension($name)))
    $total += [int]$result
}
Write-Host ("All $total checks passed. Results: $OutputDirectory") -ForegroundColor Green
