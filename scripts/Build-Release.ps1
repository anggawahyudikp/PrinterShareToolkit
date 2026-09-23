[CmdletBinding()]
param([string]$OutputDirectory=(Join-Path $PSScriptRoot '..\dist'))

$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$Version=(Get-Content -LiteralPath (Join-Path $RepoRoot 'VERSION') -Raw).Trim()
if($Version -notmatch '^\d+\.\d+\.\d+(-[A-Za-z0-9.-]+)?$'){throw 'VERSION format is invalid.'}

$ReleaseFiles=@(
    'PrinterToolkit.bat','Core/Launcher.ps1','Core/Toolkit.ps1','VERSION','README.md',
    'CHANGELOG.md','LICENSE','SECURITY.md','CONTRIBUTING.md','Docs/PROVENANCE.md',
    'Docs/PANDUAN_PENGGUNAAN.md','Docs/TROUBLESHOOTING.md','Docs/FLOWCHART.md',
    'Docs/images/flowchart.png'
)
$OutputPath=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
[void][IO.Directory]::CreateDirectory($OutputPath)
$PackageName="PrinterShareToolkit_v$Version"
$ZipPath=Join-Path $OutputPath ($PackageName+'.zip')
if(Test-Path -LiteralPath $ZipPath){throw "Release already exists and will not be overwritten: $ZipPath"}

$stage=Join-Path ([IO.Path]::GetTempPath()) ('PSTK-release-'+[guid]::NewGuid().ToString('N'))
$packageRoot=Join-Path $stage $PackageName
[void][IO.Directory]::CreateDirectory($packageRoot)
try{
    $manifest=New-Object 'System.Collections.Generic.List[string]'
    foreach($relative in $ReleaseFiles){
        if($relative -notmatch '^[A-Za-z0-9_.\/-]+$' -or $relative -match '(^|/)\.\.(/|$)'){throw "Unsafe release path: $relative"}
        $source=[IO.Path]::GetFullPath((Join-Path $RepoRoot ($relative -replace '/','\')))
        if(-not $source.StartsWith($RepoRoot+'\',[StringComparison]::OrdinalIgnoreCase)){throw "Release path escaped root: $relative"}
        $item=Get-Item -LiteralPath $source -ErrorAction Stop
        if($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw "Release entry is unsafe: $relative"}
        $destination=Join-Path $packageRoot ($relative -replace '/','\')
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
        Copy-Item -LiteralPath $source -Destination $destination
        $manifest.Add(((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash+'  '+$relative))
    }
    foreach($folder in @('Backup','Logs','Profiles')){
        $target=Join-Path $packageRoot $folder
        [void][IO.Directory]::CreateDirectory($target)
        [IO.File]::WriteAllText((Join-Path $target '.keep'),'',[Text.UTF8Encoding]::new($false))
        $manifest.Add(((Get-FileHash -LiteralPath (Join-Path $target '.keep') -Algorithm SHA256).Hash+'  '+$folder+'/.keep'))
    }
    [IO.File]::WriteAllLines((Join-Path $packageRoot 'MANIFEST.sha256'),$manifest,[Text.UTF8Encoding]::new($false))
    Compress-Archive -LiteralPath $packageRoot -DestinationPath $ZipPath -CompressionLevel Optimal
}finally{
    if(Test-Path -LiteralPath $stage){Remove-Item -LiteralPath $stage -Recurse -Force}
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive=[IO.Compression.ZipFile]::OpenRead($ZipPath)
try{
    $entriesByName=@{}
    foreach($archiveEntry in $archive.Entries){
        $entriesByName[$archiveEntry.FullName.Replace('\','/')]= $archiveEntry
    }
    $expected=@($ReleaseFiles)+@('Backup/.keep','Logs/.keep','Profiles/.keep','MANIFEST.sha256')
    foreach($relative in $expected){
        $entryName=$PackageName+'/'+$relative
        if(-not $entriesByName.ContainsKey($entryName)){throw "Archive validation failed; missing: $entryName"}
    }
    $manifestEntry=$entriesByName[$PackageName+'/MANIFEST.sha256']
    $reader=New-Object IO.StreamReader($manifestEntry.Open(),[Text.Encoding]::UTF8)
    try{$manifestLines=@(($reader.ReadToEnd() -split "`r?`n") | Where-Object {$_})}finally{$reader.Dispose()}
    foreach($line in $manifestLines){
        if($line -notmatch '^([A-F0-9]{64})  (.+)$'){throw 'Archive manifest format is invalid.'}
        $expectedHash=$matches[1];$relative=$matches[2]
        $entry=$entriesByName[$PackageName+'/'+$relative]
        if(-not $entry){throw "Manifest entry missing from archive: $relative"}
        $stream=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create()
        try{$actual=[BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','')}finally{$stream.Dispose();$sha.Dispose()}
        if($actual -ne $expectedHash){throw "Archived hash mismatch: $relative"}
    }
}finally{$archive.Dispose()}

$hash=(Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash
($hash+'  '+[IO.Path]::GetFileName($ZipPath)) | Set-Content -LiteralPath ($ZipPath+'.sha256') -Encoding ASCII
[pscustomobject]@{Path=$ZipPath;SHA256=$hash;Files=$ReleaseFiles.Count+4}
