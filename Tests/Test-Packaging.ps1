param([string]$OutputDirectory)
$ErrorActionPreference='Stop'
[void][IO.Directory]::CreateDirectory($OutputDirectory)
$root=Split-Path -Parent $PSScriptRoot
$result=& (Join-Path $root 'scripts\Build-Release.ps1') -OutputDirectory $OutputDirectory
if(-not (Test-Path -LiteralPath $result.Path)){throw 'Release ZIP missing.'}
if(-not (Test-Path -LiteralPath ($result.Path+'.sha256'))){throw 'Release SHA256 sidecar missing.'}
if((Get-FileHash -LiteralPath $result.Path -Algorithm SHA256).Hash -ne $result.SHA256){throw 'Release SHA256 mismatch.'}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive=[IO.Compression.ZipFile]::OpenRead($result.Path)
try{
    $entryNames=@($archive.Entries | ForEach-Object {$_.FullName.Replace('\','/')})
    if(-not @($entryNames | Where-Object {$_ -like '*/MANIFEST.sha256'}).Count){throw 'Manifest missing in archive.'}
    if(@($entryNames | Where-Object {$_ -match '(^|/)(Logs|Profiles|Backup)/.+(?<!\.keep)$'}).Count){throw 'Runtime data leaked into package.'}
}finally{$archive.Dispose()}
$refused=$false
try{& (Join-Path $root 'scripts\Build-Release.ps1') -OutputDirectory $OutputDirectory | Out-Null}catch{$refused=$true}
if(-not $refused){throw 'Builder overwrote an existing release.'}
Write-Host 'PASS: allowlisted release, manifest, SHA256, no runtime data, no overwrite.'
return 5
