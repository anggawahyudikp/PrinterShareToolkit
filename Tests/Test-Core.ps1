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
if((ConvertTo-MachineSid 'S-1-5-21-100-200-300-500') -ne 'S-1-5-21-100-200-300'){throw 'RID500-to-machine-SID conversion regression.'}
if(ConvertTo-MachineSid 'S-1-5-21-100-200-300-1001'){throw 'Non-RID500 SID must not be treated as a machine SID source.'}
$duplicateProfile=[pscustomobject]@{HostName='PRINT-HOST';HostMachineSid='S-1-5-21-100-200-300'}
if(-not (Test-DuplicateMachineSidProfile -Profile $duplicateProfile -LocalMachineSid 'S-1-5-21-100-200-300')){throw 'Duplicate profile/client machine SID was not detected.'}
$uniqueProfile=[pscustomobject]@{HostName='PRINT-HOST';HostMachineSid='S-1-5-21-400-500-600'}
if(Test-DuplicateMachineSidProfile -Profile $uniqueProfile -LocalMachineSid 'S-1-5-21-100-200-300'){throw 'Unique machine SIDs were classified as duplicates.'}
$legacyProfile=[pscustomobject]@{HostName='PRINT-HOST'}
if(Test-DuplicateMachineSidProfile -Profile $legacyProfile -LocalMachineSid 'S-1-5-21-100-200-300'){throw 'A legacy profile without HostMachineSid must not be classified as a duplicate.'}
$invalidProfile=[pscustomobject]@{HostMachineSid='not-a-sid'}
if(Test-DuplicateMachineSidProfile -Profile $invalidProfile -LocalMachineSid 'S-1-5-21-100-200-300'){throw 'An invalid profile machine SID must not be classified as a duplicate.'}

$source=Get-Content -LiteralPath (Join-Path $root 'Core\Toolkit.ps1') -Raw
foreach($contract in @('Schema=''PSTK.HostTransaction/1''','function Restore-HostTransaction','-RenderingMode SSR','RenderingMode authoritative SSR','PasswordChanged=$true','HostMachineSid','Id=6167','Credential input was skipped')){
    if($source -notlike ('*'+$contract+'*')){throw "Missing safety contract: $contract"}
}
if($source -match '(?i)ConvertTo-Json[^\r\n]*(password|secret)'){throw 'Potential password serialization contract violation.'}
Write-Host 'PASS: share parsers, duplicate-SID preflight, and host transaction/SSR contracts.'
return 12

