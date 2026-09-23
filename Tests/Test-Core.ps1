param([string]$OutputDirectory)
$ErrorActionPreference='Stop'
[void][IO.Directory]::CreateDirectory($OutputDirectory)
$root=Split-Path -Parent $PSScriptRoot
$fixture=Join-Path $OutputDirectory 'fixture'
Copy-Item -LiteralPath (Join-Path $root 'Core') -Destination $fixture -Recurse
$old=$env:PSTK_IMPORT_ONLY;$env:PSTK_IMPORT_ONLY='1'
try{. (Join-Path $fixture 'Toolkit.ps1')}finally{$env:PSTK_IMPORT_ONLY=$old}

$shares=@(Get-PrinterSharesFromNetView "EPSON L3210 Series  Print  Office`r`nXprinter XP-D4601B  Print  Receipt")
if($shares.Count -ne 2 -or $shares[0] -ne 'EPSON L3210 Series'){throw 'NET VIEW share parser regression.'}
$records=@(Get-PrinterShareRecordsFromNetView "EPSON-L3210  Print  EPSON L3210 Series")
if($records.Count -ne 1 -or $records[0].Comment -ne 'EPSON L3210 Series'){throw 'Share-record parser regression.'}

$source=Get-Content -LiteralPath (Join-Path $root 'Core\Toolkit.ps1') -Raw
foreach($contract in @('Schema=''PSTK.HostTransaction/1''','function Restore-HostTransaction','-RenderingMode SSR','RenderingMode authoritative SSR','PasswordChanged=$true')){
    if($source -notlike ('*'+$contract+'*')){throw "Missing safety contract: $contract"}
}
if($source -match '(?i)ConvertTo-Json[^\r\n]*(password|secret)'){throw 'Potential password serialization contract violation.'}
Write-Host 'PASS: share parsers and host transaction/SSR contracts.'
return 6

