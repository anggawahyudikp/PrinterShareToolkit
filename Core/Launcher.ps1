[CmdletBinding()]
param(
    [string]$MainScript = '',
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'

function Test-PSTKPowerShellFile {
    param([Parameter(Mandatory)][string]$Path)
    $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($resolved,[ref]$tokens,[ref]$errors)
    if($errors.Count){
        $errors | ForEach-Object {
            Write-Host ('PARSE ERROR: {0} at line {1}' -f $_.Message,$_.Extent.StartLineNumber) -ForegroundColor Red
        }
        return $false
    }
    return $true
}

function Test-PSTKAdministrator {
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    $principal=New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

try{
    if([string]::IsNullOrWhiteSpace($MainScript)){$MainScript=Join-Path $PSScriptRoot 'Toolkit.ps1'}
    $resolvedMain=(Resolve-Path -LiteralPath $MainScript -ErrorAction Stop).Path
    if(-not (Test-PSTKPowerShellFile -Path $resolvedMain)){exit 99}
    if($ValidateOnly){Write-Host 'Launcher and toolkit syntax OK';exit 0}

    if(-not (Test-PSTKAdministrator)){
        Write-Host 'Requesting Administrator privileges...'
        $arguments=@('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$resolvedMain+'"'))
        try{
            $child=Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -Verb RunAs -Wait -PassThru -ErrorAction Stop
            exit $child.ExitCode
        }catch [System.ComponentModel.Win32Exception]{
            Write-Host 'Administrator approval was cancelled or unavailable.' -ForegroundColor Yellow
            exit 1
        }
    }

    & $resolvedMain
    if($null -ne $LASTEXITCODE){exit $LASTEXITCODE}
    exit 0
}catch{
    Write-Host ('Startup failed: '+$_.Exception.Message) -ForegroundColor Red
    exit 98
}
