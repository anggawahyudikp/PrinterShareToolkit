param([string]$OutputDirectory)
$ErrorActionPreference='Stop'
[void][IO.Directory]::CreateDirectory($OutputDirectory)
$root=Split-Path -Parent $PSScriptRoot
$count=0
foreach($file in @(Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object Extension -in '.ps1','.psm1','.psd1')){
    if($file.FullName -match '\\(dist|test-results[^\\]*)\\'){continue}
    $tokens=$null;$errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    if($errors.Count){throw "Parse failed: $($file.FullName): $($errors.Message -join ' | ')"}
    $count++
}
if($count -lt 8){throw 'Expected toolkit and test PowerShell files.'}
$count | Set-Content -LiteralPath (Join-Path $OutputDirectory 'passed.txt')
Write-Host "PASS: $count PowerShell files parse on Windows PowerShell."
return 1
