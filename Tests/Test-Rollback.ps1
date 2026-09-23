param([string]$OutputDirectory)
$ErrorActionPreference='Stop'
[void][IO.Directory]::CreateDirectory($OutputDirectory)
$root=Split-Path -Parent $PSScriptRoot
$fixture=Join-Path $OutputDirectory 'fixture'
Copy-Item -LiteralPath (Join-Path $root 'Core') -Destination $fixture -Recurse
$old=$env:PSTK_IMPORT_ONLY;$env:PSTK_IMPORT_ONLY='1'
try{. (Join-Path $fixture 'Toolkit.ps1')}finally{$env:PSTK_IMPORT_ONLY=$old}

$script:printer=[pscustomobject]@{Name='Fixture Printer';Shared=$true;ShareName='new-share';PermissionSDDL='NEW';RenderingMode='SSR'}
$script:disabled=$false;$script:enabledRules=@();$script:disabledRules=@()
function Show-ToolkitHeader {}
function Pause-Toolkit {}
function Confirm-Action {$true}
function Get-BuiltinAdmin {[pscustomobject]@{Name='Administrator';SID='S-1-5-21-100-200-300-500';Enabled=$true}}
function Get-Printer {param($Name,[switch]$Full,$ErrorAction) $script:printer.PSObject.Copy()}
function Set-Printer {
    param($Name,$Shared,$ShareName,$PermissionSDDL,$RenderingMode,$ErrorAction)
    $script:printer.Shared=[bool]$Shared
    if($PSBoundParameters.ContainsKey('ShareName')){$script:printer.ShareName=$ShareName}
    if($PSBoundParameters.ContainsKey('PermissionSDDL')){$script:printer.PermissionSDDL=$PermissionSDDL}
    if($PSBoundParameters.ContainsKey('RenderingMode')){$script:printer.RenderingMode=$RenderingMode}
}
function Get-NetFirewallRule {param($Name,$ErrorAction) [pscustomobject]@{Name=$Name}}
function Enable-NetFirewallRule {param($Name,$ErrorAction) $script:enabledRules+=@($Name)}
function Disable-NetFirewallRule {param($Name,$ErrorAction) $script:disabledRules+=@($Name)}
function Disable-LocalUser {param($Name,$ErrorAction) $script:disabled=($Name -eq 'Administrator')}

$tx=Join-Path (Split-Path -Parent $fixture) 'Backup\HostTransaction-fixture'
[void][IO.Directory]::CreateDirectory($tx)
$state=[pscustomobject]@{
    Schema='PSTK.HostTransaction/1';Version='1.1.2';Computer=$env:COMPUTERNAME;Status='Completed';Updated=(Get-Date).ToString('o')
    Account=[pscustomobject]@{Name='Administrator';SID='S-1-5-21-100-200-300-500';Enabled=$false;EnabledByToolkit=$true;UnlockedByToolkit=$false;PasswordChanged=$false}
    Printer=[pscustomobject]@{Name='Fixture Printer';Shared=$false;ShareName='';PermissionSDDL='OLD';RenderingMode='CSR'}
    FirewallRules=@([pscustomobject]@{Name='FPS-Enabled';Enabled='True'},[pscustomobject]@{Name='FPS-Disabled';Enabled='False'})
}
$path=Join-Path $tx 'state.json';$state|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $path -Encoding UTF8
Restore-HostTransaction -Path $path
$saved=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
if($saved.Status -ne 'RolledBack'){throw 'Rollback journal did not reach RolledBack.'}
if($script:printer.Shared -or $script:printer.PermissionSDDL -ne 'OLD' -or $script:printer.RenderingMode -ne 'CSR'){throw 'Printer state was not restored.'}
if(-not $script:disabled){throw 'RID-500 enabled by the transaction was not disabled.'}
if($script:enabledRules -notcontains 'FPS-Enabled' -or $script:disabledRules -notcontains 'FPS-Disabled'){throw 'Firewall state was not restored.'}
if((Get-Content -LiteralPath $path -Raw) -match '(?i)password\s*[:=]\s*"(?!false|null)'){throw 'Rollback journal appears to contain password material.'}
Write-Host 'PASS: mocked rollback restores printer, firewall, and transaction-owned RID-500 Enabled state.'
return 5
