# Printer Share Toolkit v1.1.2
# Release v1.1.2
# Windows PowerShell 5.1+

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$ToolkitRoot = Split-Path -Parent $PSScriptRoot
$LogDir      = Join-Path $ToolkitRoot 'Logs'
$BackupDir   = Join-Path $ToolkitRoot 'Backup'
$ProfileDir  = Join-Path $ToolkitRoot 'Profiles'
foreach($d in @($LogDir,$BackupDir,$ProfileDir)){ if(-not (Test-Path $d)){ New-Item -ItemType Directory -Path $d -Force | Out-Null } }
$LogFile = Join-Path $LogDir ("PrinterToolkit-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
"Printer Share Toolkit v1.1.2 - $(Get-Date)" | Out-File $LogFile -Encoding utf8

$script:TechnicianMode = $false
$script:ActiveHostJournal = $null

function Write-Log {
    param([string]$Message,[ValidateSet('INFO','OK','WARN','ERROR')][string]$Level='INFO',[switch]$Quiet)
    $line='[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$Level,$Message
    Add-Content -Path $LogFile -Value $line -Encoding utf8
    if($Quiet){ return }
    $c = switch($Level){ 'OK'{'Green'} 'WARN'{'Yellow'} 'ERROR'{'Red'} default{'Cyan'} }
    $tag = switch($Level){ 'OK'{'[OK]'} 'WARN'{'[WARN]'} 'ERROR'{'[FAIL]'} default{'[INFO]'} }
    Write-Host ("{0} {1}" -f $tag,$Message) -ForegroundColor $c
}

function Write-UiLine {
    param([string]$Text='', [string]$Color='Gray')
    Write-Host $Text -ForegroundColor $Color
}
function Show-Section {
    param([string]$Title)
    Write-Host ''
    Write-Host ('-' * 56) -ForegroundColor DarkGray
    Write-Host (" {0}" -f $Title) -ForegroundColor Cyan
    Write-Host ('-' * 56) -ForegroundColor DarkGray
}
function Write-Step {
    param([int]$Current,[int]$Total,[string]$Title)
    Write-Host ''
    Write-Host ("[{0}/{1}] {2}" -f $Current,$Total,$Title) -ForegroundColor Cyan
}
function Write-UiStatus {
    param([ValidateSet('OK','WARN','FAIL','WORK','SKIP','INFO')][string]$Status,[string]$Text)
    $tag = switch($Status){'OK'{'[OK]'}'WARN'{'[WARN]'}'FAIL'{'[FAIL]'}'WORK'{'[..]'}'SKIP'{'[-]'}default{'[INFO]'}}
    $color = switch($Status){'OK'{'Green'}'WARN'{'Yellow'}'FAIL'{'Red'}'WORK'{'Cyan'}'SKIP'{'DarkGray'}default{'Gray'}}
    Write-Host ("{0} {1}" -f $tag,$Text) -ForegroundColor $color
}
function Write-Tech {
    param([string]$Text,[string]$Color='DarkGray')
    if($script:TechnicianMode){ Write-Host $Text -ForegroundColor $Color }
}
function Get-PrimaryIPv4 {
    try{
        $cfg=Get-NetIPConfiguration -ErrorAction SilentlyContinue |
            Where-Object {$_.IPv4Address -and $_.IPv4DefaultGateway} |
            Select-Object -First 1
        if($cfg -and $cfg.IPv4Address){ return [string]$cfg.IPv4Address.IPAddress }
        $ip=Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object {$_.IPAddress -notmatch '^127\.|^169\.254' -and $_.AddressState -eq 'Preferred'} |
            Select-Object -First 1
        if($ip){ return [string]$ip.IPAddress }
    }catch{}
    return '-'
}
function Show-ToolkitHeader {
    param([string]$Screen='MAIN MENU')
    Clear-Host
    Write-Host '========================================================' -ForegroundColor Cyan
    Write-Host '              PRINTER SHARE TOOLKIT v1.1.2' -ForegroundColor White
    Write-Host '========================================================' -ForegroundColor Cyan
    Write-Host (" Computer : {0}" -f $env:COMPUTERNAME)
    Write-Host (" User     : {0}\{1}" -f $env:USERDOMAIN,$env:USERNAME)
    Write-Host (" IP       : {0}" -f (Get-PrimaryIPv4))
    Write-Host (" View     : {0}" -f $(if($script:TechnicianMode){'TECHNICIAN'}else{'NORMAL'})) -ForegroundColor $(if($script:TechnicianMode){'Yellow'}else{'Gray'})
    Write-Host (" Screen   : {0}" -f $Screen) -ForegroundColor DarkGray
    Write-Host '========================================================' -ForegroundColor Cyan
}
function Show-ResultCard {
    param(
        [string]$Status,
        [string]$Printer='-',
        [string]$Method='-',
        [string]$Driver='-',
        [string]$Port='-'
    )
    Show-Section 'RESULT'
    $color=if($Status -match 'READY|VERIFIED|SUCCESS'){'Green'}elseif($Status -match 'DEGRADED|WARN'){'Yellow'}else{'Red'}
    Write-Host (" STATUS  : {0}" -f $Status) -ForegroundColor $color
    Write-Host (" PRINTER : {0}" -f $Printer)
    Write-Host (" METHOD  : {0}" -f $Method)
    Write-Host (" DRIVER  : {0}" -f $Driver)
    Write-Host (" PORT    : {0}" -f $Port)
    Write-Host (" LOG     : {0}" -f $LogFile) -ForegroundColor DarkGray
}

function Pause-Toolkit { Write-Host ''; [void](Read-Host 'ENTER = Main Menu') }
function Confirm-Action {
    param([string]$Message,[bool]$Default=$false)
    $s=if($Default){'[Y/n]'}else{'[y/N]'}
    $a=(Read-Host "$Message $s").Trim().ToLowerInvariant()
    if([string]::IsNullOrWhiteSpace($a)){ return $Default }
    return $a -in @('y','yes')
}

function Save-HostTransaction {
    param($Journal=$script:ActiveHostJournal)
    if(-not $Journal){return}
    $Journal.State.Updated=(Get-Date).ToString('o')
    $Journal.State | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Journal.Path -Encoding UTF8
}

function New-HostTransaction {
    $admin=Get-BuiltinAdmin
    $accountState=$null
    if($admin){
        $c=Get-AccountCim $admin.Name
        $accountState=[pscustomobject]@{
            Name=$admin.Name;SID=$admin.SID;Enabled=[bool]$admin.Enabled
            Locked=if($c){[bool]$c.Lockout}else{$null}
            PasswordLastSet=$admin.PasswordLastSet
            EnabledByToolkit=$false;UnlockedByToolkit=$false;PasswordChanged=$false
        }
    }
    $rules=@()
    try{
        $rules=@(Get-NetFirewallRule -ErrorAction Stop | Where-Object {$_.Name -match '^FPS-' -and $_.Direction -eq 'Inbound'} |
            Select-Object Name,Enabled)
    }catch{}
    $spooler=Get-Service Spooler -ErrorAction SilentlyContinue
    $dir=Join-Path $BackupDir ('HostTransaction-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,6))
    [void][IO.Directory]::CreateDirectory($dir)
    $state=[pscustomobject]@{
        Schema='PSTK.HostTransaction/1';Version='1.1.2';Computer=$env:COMPUTERNAME
        Created=(Get-Date).ToString('o');Updated=(Get-Date).ToString('o');Status='Started'
        Account=$accountState;Printer=$null;FirewallRules=$rules
        SpoolerWasRunning=[bool]($spooler -and $spooler.Status -eq 'Running')
        NonReversible=@();Completed=$false
    }
    $journal=[pscustomobject]@{Path=(Join-Path $dir 'state.json');State=$state}
    Save-HostTransaction $journal
    return $journal
}

function Set-HostTransactionPrinter {
    param($Printer,[string]$RegistryBackup)
    if(-not $script:ActiveHostJournal){return}
    $script:ActiveHostJournal.State.Printer=[pscustomobject]@{
        Name=$Printer.Name;Shared=[bool]$Printer.Shared;ShareName=$Printer.ShareName
        PermissionSDDL=$Printer.PermissionSDDL;RenderingMode=[string]$Printer.RenderingMode
        RegistryBackup=$RegistryBackup
    }
    Save-HostTransaction
}

function Complete-HostTransaction {
    if(-not $script:ActiveHostJournal){return}
    $script:ActiveHostJournal.State.Status='Completed'
    $script:ActiveHostJournal.State.Completed=$true
    Save-HostTransaction
}

function Get-LatestHostTransactionPath {
    $item=Get-ChildItem -LiteralPath $BackupDir -Directory -Filter 'HostTransaction-*' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if($item){return (Join-Path $item.FullName 'state.json')}
    return $null
}

function Restore-HostTransaction {
    param([string]$Path=(Get-LatestHostTransactionPath))
    Show-ToolkitHeader 'ROLLBACK HOST SETUP'
    if(-not $Path -or -not (Test-Path -LiteralPath $Path)){Write-Log 'HOST transaction backup was not found.' 'ERROR';Pause-Toolkit;return}
    $resolved=(Resolve-Path -LiteralPath $Path).Path
    $backupRoot=(Resolve-Path -LiteralPath $BackupDir).Path.TrimEnd('\')+'\'
    if(-not $resolved.StartsWith($backupRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Rollback accepts state.json only from the toolkit Backup folder.'}
    $state=Get-Content -LiteralPath $resolved -Raw | ConvertFrom-Json
    if($state.Schema -ne 'PSTK.HostTransaction/1' -or $state.Computer -ine $env:COMPUTERNAME){throw 'This transaction backup belongs to a different computer.'}
    Write-Host ('Transaction: '+$resolved)
    if($state.Account.PasswordChanged){Write-Host 'The Administrator password was changed and CANNOT be restored automatically.' -ForegroundColor Yellow}
    if($state.Account.UnlockedByToolkit){Write-Host 'The previous locked state cannot be restored safely.' -ForegroundColor Yellow}
    if(-not (Confirm-Action 'Restore the reversible printer, firewall, and Administrator Enabled-state changes?' $false)){return}
    $failures=@()
    if($state.Printer){
        try{
            $args=@{Name=$state.Printer.Name;Shared=[bool]$state.Printer.Shared;ErrorAction='Stop'}
            if($state.Printer.Shared -and $state.Printer.ShareName){$args.ShareName=$state.Printer.ShareName}
            if($state.Printer.PermissionSDDL){$args.PermissionSDDL=$state.Printer.PermissionSDDL}
            if($state.Printer.RenderingMode -in @('SSR','CSR','BranchOffice')){$args.RenderingMode=$state.Printer.RenderingMode}
            Set-Printer @args
            $check=Get-Printer -Name $state.Printer.Name -Full -ErrorAction Stop
            if($check.Shared -ne [bool]$state.Printer.Shared){throw 'Shared-state rollback verification failed.'}
        }catch{$failures+=$_.Exception.Message}
    }
    foreach($rule in @($state.FirewallRules)){
        try{
            $live=Get-NetFirewallRule -Name $rule.Name -ErrorAction SilentlyContinue
            if(-not $live){continue}
            if([string]$rule.Enabled -eq 'True'){Enable-NetFirewallRule -Name $rule.Name -ErrorAction Stop | Out-Null}
            else{Disable-NetFirewallRule -Name $rule.Name -ErrorAction Stop | Out-Null}
        }catch{$failures+=$_.Exception.Message}
    }
    if($state.Account -and $state.Account.EnabledByToolkit -and -not $state.Account.Enabled){
        try{
            if([string]$state.Account.SID -notmatch '-500$'){throw 'The backed-up Administrator SID is invalid.'}
            $admin=Get-BuiltinAdmin
            if(-not $admin -or $admin.SID -ne $state.Account.SID){throw 'The current Administrator SID differs from the backup; the account was not disabled.'}
            if(Get-Command Disable-LocalUser -ErrorAction SilentlyContinue){Disable-LocalUser -Name $admin.Name -ErrorAction Stop}
            else{& net.exe user $admin.Name /active:no | Out-Null;if($LASTEXITCODE -ne 0){throw 'Failed to disable the account.'}}
        }catch{$failures+=$_.Exception.Message}
    }
    $state.Status=if($failures.Count){'RollbackPartial'}else{'RolledBack'}
    $state.Updated=(Get-Date).ToString('o')
    $state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resolved -Encoding UTF8
    if($failures.Count){Write-Log ('Rollback is incomplete: '+($failures -join ' | ')) 'ERROR'}
    else{Write-Log 'HOST rollback completed for all reversible changes.' 'OK'}
    Pause-Toolkit
}
function Read-Required { param([string]$Prompt); do{$v=(Read-Host $Prompt).Trim()}while([string]::IsNullOrWhiteSpace($v)); return $v }


function Wait-SpoolerStateSafe {
    param(
        [ValidateSet('Running','Stopped')][string]$State,
        [int]$TimeoutSec=30
    )
    $deadline=(Get-Date).AddSeconds($TimeoutSec)
    do {
        $svc=Get-Service Spooler -ErrorAction SilentlyContinue
        if($svc -and ([string]$svc.Status -eq $State)){ return $true }
        Start-Sleep -Milliseconds 500
    } while((Get-Date) -lt $deadline)
    return $false
}

function Start-SpoolerSafe {
    param([int]$TimeoutSec=30,[switch]$Quiet)
    $svc=Get-Service Spooler -ErrorAction SilentlyContinue
    if($svc -and $svc.Status -eq 'Running'){ return $true }
    try { & sc.exe start Spooler 2>&1 | Out-Null } catch {}
    $ok=Wait-SpoolerStateSafe -State Running -TimeoutSec $TimeoutSec
    if(-not $ok -and -not $Quiet){
        $now=Get-Service Spooler -ErrorAction SilentlyContinue
        $st=if($now){[string]$now.Status}else{'NotFound'}
        Write-Log "Print Spooler did not reach Running within ${TimeoutSec}s. Status=$st" 'ERROR'
    }
    return $ok
}

function Stop-SpoolerSafe {
    param([int]$TimeoutSec=15,[switch]$Quiet)
    $svc=Get-Service Spooler -ErrorAction SilentlyContinue
    if(-not $svc -or $svc.Status -eq 'Stopped'){ return $true }
    try { & sc.exe stop Spooler 2>&1 | Out-Null } catch {}
    $ok=Wait-SpoolerStateSafe -State Stopped -TimeoutSec $TimeoutSec
    if(-not $ok -and -not $Quiet){
        $now=Get-Service Spooler -ErrorAction SilentlyContinue
        $st=if($now){[string]$now.Status}else{'NotFound'}
        Write-Log "Print Spooler did not stop within ${TimeoutSec}s. Status=$st" 'WARN'
    }
    return $ok
}

function Restart-SpoolerSafe {
    param([int]$TimeoutSec=30,[switch]$Quiet)
    if(-not $Quiet){ Write-UiStatus 'WORK' 'Restart Print Spooler' }
    [void](Stop-SpoolerSafe -TimeoutSec 15 -Quiet)
    $ok=Start-SpoolerSafe -TimeoutSec $TimeoutSec -Quiet
    if(-not $Quiet){
        if($ok){ Write-UiStatus 'OK' 'Print Spooler running' }
        else { Write-UiStatus 'FAIL' "Print Spooler is not Running after ${TimeoutSec}s" }
    }
    return $ok
}

function Test-IsAdmin {
    $id=[Security.Principal.WindowsIdentity]::GetCurrent()
    $p=New-Object Security.Principal.WindowsPrincipal($id)
    $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
if($env:PSTK_IMPORT_ONLY -ne '1' -and -not (Test-IsAdmin)){ Write-Host 'Run PrinterToolkit.bat as Administrator.' -ForegroundColor Red; Pause-Toolkit; exit 1 }

function Get-IPv4List {
    Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
      Where-Object {$_.IPAddress -notmatch '^127\.|^169\.254'} |
      Select-Object InterfaceAlias,IPAddress,PrefixLength
}

function Get-BuiltinAdmin {
    if(Get-Command Get-LocalUser -ErrorAction SilentlyContinue){
        try{
            $u=Get-LocalUser | Where-Object {$_.SID.Value -match '-500$'} | Select-Object -First 1
            if($u){ return [pscustomobject]@{Name=$u.Name;SID=$u.SID.Value;Enabled=[bool]$u.Enabled;PasswordLastSet=$u.PasswordLastSet;Source='Get-LocalUser'} }
        }catch{}
    }
    try{
        $u=Get-CimInstance Win32_UserAccount -Filter 'LocalAccount=True' | Where-Object {$_.SID -match '-500$'} | Select-Object -First 1
        if($u){ return [pscustomobject]@{Name=$u.Name;SID=$u.SID;Enabled=(-not [bool]$u.Disabled);PasswordLastSet=$null;Source='Win32_UserAccount'} }
    }catch{}
    try{
        $root=[ADSI]("WinNT://$env:COMPUTERNAME,computer")
        foreach($child in @($root.psbase.Children)){
            if($child.SchemaClassName -ne 'User'){continue}
            try{
                $raw=$child.psbase.InvokeGet('objectSID')
                if($raw){
                    $sid=New-Object System.Security.Principal.SecurityIdentifier($raw,0)
                    if($sid.Value -match '-500$'){
                        $name=[string]$child.Name
                        $c=Get-CimInstance Win32_UserAccount -Filter "LocalAccount=True AND Name='$($name.Replace("'","''"))'" -ErrorAction SilentlyContinue
                        return [pscustomobject]@{Name=$name;SID=$sid.Value;Enabled=if($c){-not [bool]$c.Disabled}else{$true};PasswordLastSet=$null;Source='ADSI WinNT'}
                    }
                }
            }catch{}
        }
    }catch{}
    $null
}
function Get-AccountCim { param([string]$Name); Get-CimInstance Win32_UserAccount -Filter "LocalAccount=True AND Name='$($Name.Replace("'","''"))'" -ErrorAction SilentlyContinue }

function Enable-BuiltinAdmin {
    param([string]$Name)
    if(Get-Command Enable-LocalUser -ErrorAction SilentlyContinue){ Enable-LocalUser -Name $Name -ErrorAction Stop }
    else { & net.exe user $Name /active:yes | Out-Null; if($LASTEXITCODE -ne 0){throw 'Failed to enable the account.'} }
    if($script:ActiveHostJournal -and $script:ActiveHostJournal.State.Account){
        $script:ActiveHostJournal.State.Account.EnabledByToolkit=$true
        Save-HostTransaction
    }
}
function Unlock-BuiltinAdmin {
    param([string]$Name)
    $u=[ADSI]("WinNT://{0}/{1},user" -f $env:COMPUTERNAME,$Name)
    $u.psbase.InvokeSet('IsAccountLocked',$false); $u.SetInfo()
    if($script:ActiveHostJournal -and $script:ActiveHostJournal.State.Account){
        $script:ActiveHostJournal.State.Account.UnlockedByToolkit=$true
        $script:ActiveHostJournal.State.NonReversible+=@('Account lock state cannot be safely restored.')
        Save-HostTransaction
    }
}
function Set-BuiltinAdminPassword {
    param([string]$Name)
    $p1=Read-Host "NEW password for $Name" -AsSecureString
    $p2=Read-Host 'Repeat the NEW password' -AsSecureString
    $b1=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($p1); $b2=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($p2)
    try{
        $s1=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($b1); $s2=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($b2)
        if($s1 -ne $s2){ throw 'The password confirmation does not match.' }
        if($script:ActiveHostJournal -and $script:ActiveHostJournal.State.Account){
            $script:ActiveHostJournal.State.Account.PasswordChanged=$true
            $script:ActiveHostJournal.State.NonReversible+=@('Administrator password was changed and cannot be rolled back.')
            Save-HostTransaction
        }
        if(Get-Command Set-LocalUser -ErrorAction SilentlyContinue){ Set-LocalUser -Name $Name -Password $p1 -ErrorAction Stop }
        else { $u=[ADSI]("WinNT://{0}/{1},user" -f $env:COMPUTERNAME,$Name); $u.SetPassword($s1); $u.SetInfo() }
    }finally{
        if($b1 -ne [IntPtr]::Zero){[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b1)}
        if($b2 -ne [IntPtr]::Zero){[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b2)}
        $s1=$null;$s2=$null
    }
}

function Test-BuiltinAdminPasswordReady {
    param($Admin)
    if($null -eq $Admin){ return $false }

    # Strict RID500 policy: a real password must have been set on the built-in account.
    # PasswordRequired from Win32_UserAccount is NOT used as the deciding signal because
    # it can remain False even after Set-LocalUser successfully sets a password.
    $p=$Admin.PSObject.Properties['PasswordLastSet']
    if($p -and $null -ne $p.Value){ return $true }

    if(Get-Command Get-LocalUser -ErrorAction SilentlyContinue){
        try{
            $u=Get-LocalUser -Name $Admin.Name -ErrorAction Stop
            if($null -ne $u.PasswordLastSet){ return $true }
        }catch{}
    }
    return $false
}

function Invoke-AdminReadiness {
    param([switch]$Repair)
    Show-Section 'BUILT-IN ADMINISTRATOR - RID 500'
    Write-UiStatus 'INFO' 'RID 500 is mandatory. Another local administrator does not replace RID 500.'

    $cs=Get-CimInstance Win32_ComputerSystem; $role=[int]$cs.DomainRole
    if($role -ge 4){ Write-Log 'A Domain Controller was detected. The local RID 500 workflow does not apply.' 'WARN'; return [pscustomobject]@{Ready=$false;Status='DC';Admin=$null} }

    $a=Get-BuiltinAdmin
    if(-not $a){
        Write-Log 'CRITICAL: Built-in Administrator RID 500 was not found.' 'ERROR'
        Write-Host 'The toolkit does not create a substitute user named Administrator.' -ForegroundColor Yellow
        Write-Host 'Another member of Administrators is not accepted as a replacement for RID 500.' -ForegroundColor Yellow
        Write-Host 'Use Windows/SAM Health Check. If RID 500 is still missing, Windows/SAM repair is required.' -ForegroundColor Yellow
        return [pscustomobject]@{Ready=$false;Status='RID500_NOT_FOUND';Admin=$null}
    }

    $c=Get-AccountCim $a.Name
    $locked=if($c){[bool]$c.Lockout}else{$false}
    $pr=if($c){[bool]$c.PasswordRequired}else{$null}
    $passReady=Test-BuiltinAdminPasswordReady $a

    # IMPORTANT: display only; Invoke-AdminReadiness must return exactly one readiness object.
    if($script:TechnicianMode){
        [pscustomobject]@{
            Computer=$env:COMPUTERNAME
            SID=$a.SID
            Name=$a.Name
            Enabled=$a.Enabled
            Locked=$locked
            PasswordReady=$passReady
            PasswordLastSet=$a.PasswordLastSet
            PasswordRequired=$pr
            DetectedBy=$a.Source
        } | Format-List | Out-Host
    } else {
        Write-Host (" Account  : {0}" -f $a.Name)
        Write-UiStatus $(if($a.Enabled){'OK'}else{'FAIL'}) 'RID500 Enabled'
        Write-UiStatus $(if(-not $locked){'OK'}else{'FAIL'}) 'RID500 Unlocked'
        Write-UiStatus $(if($passReady){'OK'}else{'WARN'}) 'RID500 Password Ready'
    }

    if($Repair){
        if(-not $a.Enabled){
            Write-Log 'Built-in Administrator RID 500 is disabled.' 'WARN'
            if(Confirm-Action 'RID 500 must be enabled. Enable it now?' $true){
                Enable-BuiltinAdmin $a.Name
                Write-Log 'Built-in Administrator RID 500 enabled.' 'OK'
            } else {
                Write-Log 'STOP: RID 500 must be enabled. Another local administrator is not accepted as a replacement.' 'ERROR'
                return [pscustomobject]@{Ready=$false;Status='RID500_DISABLED';Admin=$a}
            }
            $a=Get-BuiltinAdmin
            if(-not $a.Enabled){
                Write-Log 'STOP: RID 500 is still disabled after the enable operation.' 'ERROR'
                return [pscustomobject]@{Ready=$false;Status='RID500_ENABLE_FAILED';Admin=$a}
            }
        }

        $c=Get-AccountCim $a.Name
        if($c -and $c.Lockout){
            Write-Log 'Built-in Administrator RID 500 is locked.' 'WARN'
            if(Confirm-Action 'RID 500 must be unlocked. Unlock it now?' $true){
                Unlock-BuiltinAdmin $a.Name
                Write-Log 'Built-in Administrator RID 500 unlocked.' 'OK'
            } else {
                Write-Log 'STOP: RID 500 is still locked. HOST setup will not continue.' 'ERROR'
                return [pscustomobject]@{Ready=$false;Status='RID500_LOCKED';Admin=$a}
            }
            $c=Get-AccountCim $a.Name
            if($c -and $c.Lockout){
                Write-Log 'STOP: RID 500 is still locked after the unlock operation.' 'ERROR'
                return [pscustomobject]@{Ready=$false;Status='RID500_UNLOCK_FAILED';Admin=$a}
            }
        }

        $a=Get-BuiltinAdmin
        $passReady=Test-BuiltinAdminPasswordReady $a
        if(-not $passReady){
            Write-Log 'Built-in Administrator RID 500 does not have a password-ready state.' 'WARN'
            if(Confirm-Action 'RID 500 requires a password. Set or reset it now?' $true){
                Set-BuiltinAdminPassword $a.Name
                Write-Log 'The built-in Administrator RID 500 password was set or reset.' 'OK'
            } else {
                Write-Log 'STOP: The RID 500 password is not ready. HOST setup will not continue.' 'ERROR'
                return [pscustomobject]@{Ready=$false;Status='RID500_PASSWORD_NOT_READY';Admin=$a}
            }
            $a=Get-BuiltinAdmin
            $passReady=Test-BuiltinAdminPasswordReady $a
            if(-not $passReady){
                Write-Log 'STOP: The RID 500 password still cannot be verified after the set/reset operation.' 'ERROR'
                return [pscustomobject]@{Ready=$false;Status='RID500_PASSWORD_VERIFY_FAILED';Admin=$a}
            }
        } elseif(Confirm-Action 'Reset the built-in Administrator RID 500 password?' $false){
            Set-BuiltinAdminPassword $a.Name
            Write-Log 'The built-in Administrator RID 500 password was reset.' 'OK'
        }
    }

    $a=Get-BuiltinAdmin
    if(-not $a){ return [pscustomobject]@{Ready=$false;Status='RID500_NOT_FOUND';Admin=$null} }
    $c=Get-AccountCim $a.Name
    $locked=if($c){[bool]$c.Lockout}else{$false}
    $passReady=Test-BuiltinAdminPasswordReady $a
    $ready=$a.Enabled -and (-not $locked) -and $passReady

    if($ready){
        Write-Log 'ADMIN STATUS: READY TO GO (RID 500 Enabled + Unlocked + PasswordReady).' 'OK'
    } else {
        Write-Log "ADMIN STATUS: NOT READY. Enabled=$($a.Enabled); Locked=$locked; PasswordReady=$passReady" 'ERROR'
    }
    return [pscustomobject]@{Ready=$ready;Status=if($ready){'READY'}else{'NOT_READY'};Admin=$a;PasswordReady=$passReady}
}

function Init-NativePrintApi {
    if('PSTK.NativePrint' -as [type]){return}
    Add-Type @"
using System;
using System.Runtime.InteropServices;
namespace PSTK {
 public static class NativePrint {
  [StructLayout(LayoutKind.Sequential)] public struct PRINTER_DEFAULTS { public IntPtr pDatatype; public IntPtr pDevMode; public UInt32 DesiredAccess; }
  [DllImport("winspool.drv",EntryPoint="OpenPrinterW",SetLastError=true,CharSet=CharSet.Unicode)] [return:MarshalAs(UnmanagedType.Bool)] public static extern bool OpenPrinter(string n,out IntPtr h,ref PRINTER_DEFAULTS d);
  [DllImport("winspool.drv",EntryPoint="SetPrinterDataExW",SetLastError=true,CharSet=CharSet.Unicode)] public static extern UInt32 SetPrinterDataEx(IntPtr h,string k,string v,UInt32 t,byte[] d,UInt32 cb);
  [DllImport("winspool.drv",SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] public static extern bool ClosePrinter(IntPtr h);
 }
}
"@
}
function Set-PrinterSSR {
    param([string]$PrinterName)
    Init-NativePrintApi
    $d=New-Object PSTK.NativePrint+PRINTER_DEFAULTS; $d.DesiredAccess=0x000F000C; $h=[IntPtr]::Zero
    if(-not [PSTK.NativePrint]::OpenPrinter($PrinterName,[ref]$h,[ref]$d)){ throw "OpenPrinter failed. Error=$([Runtime.InteropServices.Marshal]::GetLastWin32Error())" }
    try{
        $r1=[PSTK.NativePrint]::SetPrinterDataEx($h,'PrinterDriverData','EMFDespoolingSetting',4,[BitConverter]::GetBytes([uint32]1),4)
        $r2=[PSTK.NativePrint]::SetPrinterDataEx($h,'PrinterDriverData','ForceClientSideRendering',4,[BitConverter]::GetBytes([uint32]0),4)
        if($r1 -ne 0 -or $r2 -ne 0){throw "SetPrinterDataEx failed. EMF=$r1 FCSR=$r2"}
    }finally{[void][PSTK.NativePrint]::ClosePrinter($h)}
    $reg="HKLM:\SYSTEM\CurrentControlSet\Control\Print\Printers\$PrinterName\PrinterDriverData"; $v=Get-ItemProperty $reg
    $fcsrProp=$v.PSObject.Properties['ForceClientSideRendering']
    $fcsr=if($fcsrProp){$fcsrProp.Value}else{$null}
    [pscustomobject]@{EMF=$v.EMFDespoolingSetting;ForceCSR=$fcsr}
}
function Set-ClientSSR {
    $p='HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers'; if(-not(Test-Path $p)){New-Item $p -Force|Out-Null}
    New-ItemProperty -Path $p -Name ForceCSREMFDespooling -PropertyType DWord -Value 1 -Force|Out-Null
    (Get-ItemProperty $p).ForceCSREMFDespooling
}
function Backup-PrinterReg {
    param([string]$Name)
    $safe=$Name -replace '[\\/:*?"<>|]','_'; $f=Join-Path $BackupDir ("$safe-{0}.reg" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    & reg.exe export "HKLM\SYSTEM\CurrentControlSet\Control\Print\Printers\$Name" $f /y|Out-Null; $f
}
function Save-HostProfile {
    param($Admin,$Printer)
    $o=[ordered]@{Version='1.1';Generated=(Get-Date).ToString('s');HostName=$env:COMPUTERNAME;HostIP=@((Get-IPv4List).IPAddress);Administrator=@{Name=$Admin.Name;SID=$Admin.SID;RID=500};Printer=@{Name=$Printer.Name;ShareName=$Printer.ShareName;DriverName=$Printer.DriverName;PortName=$Printer.PortName;SSR=$true;RenderingMode='SSR'}}
    $f=Join-Path $ProfileDir ("{0}-{1}.json" -f $env:COMPUTERNAME,($Printer.ShareName -replace '[\\/:*?"<>|]','_')); $o|ConvertTo-Json -Depth 6|Set-Content $f -Encoding UTF8; $f
}

function Invoke-HostSetup {
    Show-ToolkitHeader 'SETUP / REPAIR HOST'
    $script:ActiveHostJournal=New-HostTransaction
    Write-Tech ("Transaction backup: {0}" -f $script:ActiveHostJournal.Path)
    Write-Step 1 5 'RID500 CHECK'
    $arItems=@(Invoke-AdminReadiness -Repair | Where-Object {$_ -ne $null -and $_.PSObject.Properties['Ready']})
    if($arItems.Count -eq 0){Write-Log 'Host setup stopped: Administrator Readiness returned an invalid result.' 'ERROR';Pause-Toolkit;return}
    $ar=$arItems[-1]
    if(-not $ar.Ready){Write-Log 'Host setup stopped: the built-in Administrator is not READY.' 'ERROR';Pause-Toolkit;return}

    Write-Step 2 5 'SELECT PRINTER'
    Write-Tech 'NETWORK' 'Yellow'
    if($script:TechnicianMode){ Get-IPv4List|Format-Table -AutoSize|Out-Host }
    $ps=@(Get-Printer -Full -ErrorAction SilentlyContinue|Where-Object{$_.Type -eq 'Local' -and $_.Name -notmatch 'Microsoft Print to PDF|Microsoft XPS|Fax|OneNote'}|Sort-Object Name)
    if(!$ps){Write-Log 'No local printer was found.' 'ERROR';Pause-Toolkit;return}
    for($i=0;$i -lt $ps.Count;$i++){Write-Host ("[{0}] {1} | Driver={2} | Port={3} | Shared={4} | Status={5}" -f ($i+1),$ps[$i].Name,$ps[$i].DriverName,$ps[$i].PortName,$ps[$i].Shared,$ps[$i].PrinterStatus)}
    $n=0
    if((-not [int]::TryParse((Read-Host 'Select a printer number'),[ref]$n)) -or $n -lt 1 -or $n -gt $ps.Count){Write-Log 'Invalid selection.' 'ERROR';Pause-Toolkit;return}
    $p=$ps[$n-1]
    if($p.Type -ne 'Local'){Write-Log 'Re-sharing a Type=Connection printer is not allowed.' 'ERROR';Pause-Toolkit;return}

    $def=if($p.ShareName){$p.ShareName}else{($p.Name -replace '[\\/:*?"<>|,]','-' -replace '\s+','-')}
    $share=Read-Host "ShareName [$def]"
    if(!$share){$share=$def}
    if($share -match '[\\/:*?"<>|,]'){Write-Log 'ShareName contains unsupported characters.' 'ERROR';Pause-Toolkit;return}

    Write-Step 3 5 'SHARE + SSR'
    $bk=Backup-PrinterReg $p.Name
    Set-HostTransactionPrinter -Printer $p -RegistryBackup $bk
    Write-Log 'Registry backup created.' 'OK'
    Write-Tech "Backup: $bk"
    Set-Printer -Name $p.Name -Shared $true -ShareName $share -RenderingMode SSR
    Write-Log "Sharing enabled: $share" 'OK'
    $ssr=Set-PrinterSSR $p.Name
    Write-Log "SSR: EMF=$($ssr.EMF), ForceCSR=$($ssr.ForceCSR)" 'OK'
    try{Get-NetFirewallRule -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '^FPS-' -and $_.Direction -eq 'Inbound'}|Enable-NetFirewallRule -ErrorAction SilentlyContinue}catch{}
    if(-not (Restart-SpoolerSafe -TimeoutSec 30)){
        Write-Log 'HOST setup stopped: the Print Spooler failed to reach Running state.' 'ERROR'
        Pause-Toolkit
        return
    }
    Start-Sleep 2

    Write-Step 4 5 'VERIFY HOST'
    # FINAL VERIFY + ONE CORRECTION PASS
    $f=Get-Printer -Name $p.Name -Full -ErrorAction SilentlyContinue
    if(-not $f -or -not $f.Shared -or $f.ShareName -ne $share){
        Write-Log 'Final verification: sharing is not correct. Applying one correction pass.' 'WARN'
        Set-Printer -Name $p.Name -Shared $true -ShareName $share -RenderingMode SSR
        [void](Restart-SpoolerSafe -TimeoutSec 30 -Quiet);Start-Sleep 2
        $f=Get-Printer -Name $p.Name -Full -ErrorAction SilentlyContinue
    }
    $reg="HKLM:\SYSTEM\CurrentControlSet\Control\Print\Printers\$($p.Name)\PrinterDriverData"
    $rv=Get-ItemProperty $reg -ErrorAction SilentlyContinue
    $emf=if($rv){$rv.EMFDespoolingSetting}else{$null}
    $fcProp=if($rv){$rv.PSObject.Properties['ForceClientSideRendering']}else{$null}
    $fcsr=if($fcProp){$fcProp.Value}else{$null}
    if($emf -ne 1 -or $fcsr -eq 1){
        Write-Log 'Final verification: HOST SSR is not healthy. Applying one correction pass.' 'WARN'
        $ssr=Set-PrinterSSR $p.Name
        [void](Restart-SpoolerSafe -TimeoutSec 30 -Quiet);Start-Sleep 2
        $rv=Get-ItemProperty $reg -ErrorAction SilentlyContinue
        $emf=if($rv){$rv.EMFDespoolingSetting}else{$null}
        $fcProp=if($rv){$rv.PSObject.Properties['ForceClientSideRendering']}else{$null}
        $fcsr=if($fcProp){$fcProp.Value}else{$null}
    }
    if($f -and $f.PrinterStatus -ne 'Normal'){
        Write-Log "PrinterStatus=$($f.PrinterStatus). Restarting the Print Spooler before rechecking." 'WARN'
        [void](Restart-SpoolerSafe -TimeoutSec 30 -Quiet);Start-Sleep 3
        $f=Get-Printer -Name $p.Name -Full -ErrorAction SilentlyContinue
    }
    if(-not $f){Write-Log 'HOST final verification failed: the printer queue was not found after the changes.' 'ERROR';Pause-Toolkit;return}
    $spool=Get-Service Spooler -ErrorAction SilentlyContinue
    $tcp445=$false
    try{$tcp445=Test-NetConnection 127.0.0.1 -Port 445 -WarningAction SilentlyContinue -InformationLevel Quiet}catch{}
    $driverOk=[bool](Get-PrinterDriver -Name $f.DriverName -ErrorAction SilentlyContinue)
    $portOk=[bool](Get-PrinterPort -Name $f.PortName -ErrorAction SilentlyContinue)
    $hostChecks=[ordered]@{
        'Built-in Admin RID500 READY'=$ar.Ready
        'RID500 PasswordReady'=[bool]$ar.PasswordReady
        'Printer Type Local'=($f.Type -eq 'Local')
        'Driver installed'=$driverOk
        'Port exists'=$portOk
        'Shared=True'=[bool]$f.Shared
        'ShareName correct'=($f.ShareName -eq $share)
        'RenderingMode authoritative SSR'=([string]$f.RenderingMode -eq 'SSR')
        'SSR EMF=1'=($emf -eq 1)
        'ForceCSR not 1'=($fcsr -ne 1)
        'Spooler running'=($spool -and $spool.Status -eq 'Running')
        'SMB TCP445 listening'=[bool]$tcp445
        'Printer Normal'=($f.PrinterStatus -eq 'Normal')
    }
    Write-Step 5 5 'FINAL CHECK'
    $hostFailed=@()
    foreach($kv in $hostChecks.GetEnumerator()){
        $ok=[bool]$kv.Value
        if(-not $ok){$hostFailed+=$kv.Key}
        $tag=if($ok){'[OK]'}else{'[FAIL]'}
        $clr=if($ok){'Green'}else{'Red'}
        Write-Host ("$tag $($kv.Key)") -ForegroundColor $clr
    }

    $profile=Save-HostProfile (Get-BuiltinAdmin) $f
    Write-Log 'Host profile saved.' 'OK'
    Write-Tech "Profile: $profile"
    if($script:TechnicianMode){$f|Select Name,DriverName,PortName,Shared,ShareName,PrinterStatus|Format-List|Out-Host}
    foreach($ip in @((Get-IPv4List).IPAddress)){Write-Host " UNC     : \\$ip\$($f.ShareName)" -ForegroundColor Green}
    if($hostFailed.Count -eq 0){
        Complete-HostTransaction
        Show-ResultCard -Status 'READY TO SHARE' -Printer $f.Name -Method 'Native Share + SSR' -Driver $f.DriverName -Port $f.PortName
        Write-Log 'HOST STATUS: READY TO SHARE.' 'OK'
    }else{
        Show-ResultCard -Status 'DEGRADED' -Printer $f.Name -Method 'Native Share + SSR' -Driver $f.DriverName -Port $f.PortName
        Write-Log ("HOST STATUS: DEGRADED - "+($hostFailed -join ', ')) 'ERROR'
    }
    Pause-Toolkit
}

function Remove-NetUseSafe {
    param([Parameter(Mandatory)][string]$Target)
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = (Join-Path $env:SystemRoot 'System32\net.exe')
        $psi.Arguments = 'use "' + $Target + '" /delete /y'
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        [void]$proc.Start()
        [void]$proc.StandardOutput.ReadToEnd()
        [void]$proc.StandardError.ReadToEnd()
        $proc.WaitForExit()
    } catch {
        # The absence of an SMB session is normal; do not stop the workflow.
    }
}

function Clear-SmbServerSessions {
    param([string]$Server)
    $connections = @()
    try { $connections = @(Get-SmbConnection -ServerName $Server -ErrorAction SilentlyContinue) } catch {}
    foreach($c in $connections){
        if($c.ShareName){ Remove-NetUseSafe -Target "\\$Server\$($c.ShareName)" }
    }
    Remove-NetUseSafe -Target "\\$Server\IPC$"
    # The absence of an old connection is normal.
}

function Remove-CmdKeySafe {
    param([Parameter(Mandatory)][string]$Target)
    $oldEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'SilentlyContinue'
        & cmdkey.exe "/delete:$Target" 2>$null | Out-Null
    } catch {} finally {
        $ErrorActionPreference = $oldEap
    }
}

function Add-CmdKeySafe {
    param([Parameter(Mandatory)][string]$Target,[Parameter(Mandatory)][string]$User,[Parameter(Mandatory)][string]$Password)
    $oldEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & cmdkey.exe "/add:$Target" "/user:$User" "/pass:$Password" 2>&1 | Out-Null
        return $LASTEXITCODE
    } catch {
        return 1
    } finally {
        $ErrorActionPreference = $oldEap
    }
}

function Resolve-RemoteHostName {
    param([Parameter(Mandatory)][string]$Server)

    if($Server -notmatch '^\d{1,3}(?:\.\d{1,3}){3}$'){
        $short=(($Server -split '\.')[0]).Trim()
        if($short -and $short -notmatch '^\d+$'){ return $short.ToUpperInvariant() }
    }

    # Reverse DNS may return the IP itself (for example 192.168.1.83).
    # Never accept a numeric/IP-like first label as a hostname.
    try {
        $entry = [System.Net.Dns]::GetHostEntry($Server)
        if($entry -and $entry.HostName){
            $full=[string]$entry.HostName
            $ipObj=$null
            $isIp=[System.Net.IPAddress]::TryParse($full,[ref]$ipObj)
            $n=(($full -split '\.')[0]).Trim()
            if((-not $isIp) -and $n -and $n -notmatch '^\d+$' -and $n -ne $Server){
                return $n.ToUpperInvariant()
            }
        }
    } catch {}

    # Fallback to NetBIOS name. Prefer workstation/server <00> UNIQUE entry.
    try {
        $nbt = (& nbtstat.exe -A $Server 2>$null | Out-String)
        foreach($line in ($nbt -split "`r?`n")){
            if($line -match '^\s*([^\s<]+)\s+<00>\s+UNIQUE'){
                $n=$matches[1].Trim()
                if($n -and $n -notmatch '^\d+$'){ return $n.ToUpperInvariant() }
            }
        }
    } catch {}

    return $null
}

function Get-PrinterSharesFromNetView {
    param([Parameter(Mandatory)][string]$Text)

    # Windows PowerShell 5.1 compatibility:
    # Avoid @($genericList). On some PS 5.1 builds a Generic List wrapped in
    # an array-subexpression can throw: "Argument types do not match".
    $found = @()
    foreach($line in ($Text -split "`r?`n")){
        # NET VIEW columns are separated by 2+ spaces. Capture the Share name
        # before the Type column. Handles share names containing normal spaces.
        if($line -match '^\s*(.+?)\s{2,}Print(?:\s{2,}|\s*$)'){
            $name=$matches[1].Trim()
            if($name -and -not ($found -contains $name)){ $found += $name }
        }
    }
    return $found
}
function Test-SmbOnce {
    param([string]$Server,[string]$User,[string]$Password)
    $oldEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $out=(& net.exe use "\\$Server\IPC$" $Password "/user:$User" 2>&1|Out-String)
        $code=$LASTEXITCODE
    } catch {
        $out = $_.Exception.Message
        $code = if($LASTEXITCODE){$LASTEXITCODE}else{1}
    } finally {
        $ErrorActionPreference = $oldEap
    }
    [pscustomobject]@{Success=($code -eq 0);Code=$code;Output=$out.Trim();Locked=($out -match '1909|locked out');Bad=($out -match '1326|password or user name is invalid|user name or password is incorrect');Conflict=($out -match '1219|multiple connections')}
}
function Wait-NetworkPrinter {
    param([string]$Server,[int]$Seconds=120)
    $st=Get-Date; do{$p=Get-Printer -Full -ErrorAction SilentlyContinue|Where-Object{$_.Type -eq 'Connection' -and ($_.ComputerName -eq $Server -or $_.Name -like "\\$Server\*")};if($p){return @($p)};Start-Sleep 3}while(((Get-Date)-$st).TotalSeconds -lt $Seconds);$null
}


function Get-PrinterShareRecordsFromNetView {
    param([Parameter(Mandatory)][string]$Text)

    # Windows PowerShell 5.1 compatibility:
    # Plain PowerShell arrays are intentional here. Wrapping List[object] in
    # @() can fail on PS 5.1 with "Argument types do not match".
    $records = @()
    foreach($line in ($Text -split "`r?`n")){
        if($line -match '^\s*(.+?)\s{2,}Print(?:\s{2,}(.*?))?\s*$'){
            $shareName=$matches[1].Trim()
            $comment=if($matches.Count -ge 3 -and $matches[2]){$matches[2].Trim()}else{''}
            $duplicate=$false
            foreach($existing in $records){
                if($existing.ShareName -ieq $shareName){ $duplicate=$true; break }
            }
            if($shareName -and -not $duplicate){
                $records += [pscustomobject]@{ShareName=$shareName;Comment=$comment;RawLine=$line}
            }
        }
    }
    return $records
}

function Get-MachinePrintConnections {
    param([string]$Server)
    $path='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Connections'
    if(-not (Test-Path $path)){ return @() }
    $out=@()
    foreach($k in @(Get-ChildItem $path -ErrorAction SilentlyContinue)){
        $v=Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue
        if(-not $v){ continue }
        if($Server -and $v.Server -and (($v.Server -replace '^\\\\','') -ine $Server)){ continue }
        $out += [pscustomobject]@{
            Key=$k.PSChildName
            PSPath=$k.PSPath
            Server=[string]$v.Server
            Printer=[string]$v.Printer
            Provider=[string]$v.Provider
            LocalConnection=$v.LocalConnection
            Attribute=$v.Attribute
        }
    }
    return @($out)
}

function Remove-StaleMachineConnections {
    param(
        [Parameter(Mandatory)][string]$Server,
        [Parameter(Mandatory)][object[]]$ValidShareRecords
    )
    $validKeys=@{}
    foreach($r in @($ValidShareRecords)){
        if($r.ShareName){ $validKeys[(($r.ShareName -replace '[^A-Za-z0-9]','').ToLowerInvariant())]=$true }
    }
    $removed=0
    foreach($mc in @(Get-MachinePrintConnections -Server $Server)){
        if(-not $mc.Printer){ continue }
        $prefix="\\$Server\"
        if(-not $mc.Printer.StartsWith($prefix,[System.StringComparison]::OrdinalIgnoreCase)){ continue }
        $sharePart=$mc.Printer.Substring($prefix.Length)
        $k=(($sharePart -replace '[^A-Za-z0-9]','').ToLowerInvariant())
        if($validKeys.ContainsKey($k)){ continue }

        Write-Log "Stale /ga connection detected: $($mc.Printer)" 'WARN'
        try { & rundll32.exe printui.dll,PrintUIEntry /gd /n "$($mc.Printer)" | Out-Null } catch {}
        Start-Sleep 1
        $still=@(Get-MachinePrintConnections -Server $Server | Where-Object {$_.Printer -ieq $mc.Printer})
        if($still.Count -gt 0){
            try {
                Remove-Item $mc.PSPath -Recurse -Force -ErrorAction Stop
                Write-Log "Stale /ga registry entry removed: $($mc.Printer)" 'OK'
                $removed++
            } catch {
                Write-Log "Failed to remove stale /ga connection: $($mc.Printer) - $($_.Exception.Message)" 'WARN'
            }
        } else {
            Write-Log "Stale /ga connection removed: $($mc.Printer)" 'OK'
            $removed++
        }
    }
    return $removed
}

function Get-TargetConnection {
    param(
        [Parameter(Mandatory)][string]$Server,
        [string]$ExpectedDisplayName,
        [string[]]$BeforeNames=@()
    )
    $connections=@(Get-Printer -Full -ErrorAction SilentlyContinue | Where-Object {
        $_.Type -eq 'Connection' -and ($_.ComputerName -ieq $Server -or $_.Name -like "\\$Server\*")
    })
    if($connections.Count -eq 0){ return $null }

    if($ExpectedDisplayName){
        $exactName="\\$Server\$ExpectedDisplayName"
        $p=@($connections | Where-Object {$_.Name -ieq $exactName}) | Select-Object -First 1
        if($p){ return $p }
    }

    $new=@($connections | Where-Object {$BeforeNames -notcontains $_.Name})
    if($new.Count -eq 1){ return $new[0] }
    if($connections.Count -eq 1){ return $connections[0] }
    return $null
}

function Get-NormalizedPrinterToken {
    param([string]$Text)
    if([string]::IsNullOrWhiteSpace($Text)){ return '' }
    return (($Text -replace '[^A-Za-z0-9]','').ToLowerInvariant())
}

function Resolve-LocalPrinterDriverName {
    param([string]$ExpectedDisplayName)
    if([string]::IsNullOrWhiteSpace($ExpectedDisplayName)){ return $null }

    $drivers=@(Get-PrinterDriver -ErrorAction SilentlyContinue)
    $exact=@($drivers | Where-Object {$_.Name -ieq $ExpectedDisplayName}) | Select-Object -First 1
    if($exact){ return [string]$exact.Name }

    # /in can stage the package but fail before registering the queue. If the
    # package is already in DriverStore, Add-PrinterDriver can register it.
    try { Add-PrinterDriver -Name $ExpectedDisplayName -ErrorAction Stop } catch {}
    $drivers=@(Get-PrinterDriver -ErrorAction SilentlyContinue)
    $exact=@($drivers | Where-Object {$_.Name -ieq $ExpectedDisplayName}) | Select-Object -First 1
    if($exact){ return [string]$exact.Name }

    $needle=Get-NormalizedPrinterToken $ExpectedDisplayName
    if(-not $needle){ return $null }
    $matches=@()
    foreach($d in $drivers){
        $dn=Get-NormalizedPrinterToken ([string]$d.Name)
        if(-not $dn){ continue }
        if($dn -eq $needle -or (($dn.Length -ge 6) -and ($needle.Contains($dn) -or $dn.Contains($needle)))){
            $matches += $d
        }
    }
    if($matches.Count -eq 1){ return [string]$matches[0].Name }
    return $null
}

function Invoke-SafeDriverReregister {
    param([Parameter(Mandatory)][string]$DriverName)

    $inUse=@(Get-Printer -Full -ErrorAction SilentlyContinue | Where-Object {$_.DriverName -ieq $DriverName})
    if($inUse.Count -gt 0){
        Write-Log "Driver '$DriverName' is used by another queue; destructive re-registration was skipped." 'WARN'
        return $true
    }

    $safeName=$DriverName.Replace("'","''")
    $child="Import-Module PrintManagement -ErrorAction SilentlyContinue; Remove-PrinterDriver -Name '$safeName' -ErrorAction SilentlyContinue"
    $bytes=[Text.Encoding]::Unicode.GetBytes($child)
    $encoded=[Convert]::ToBase64String($bytes)
    $proc=$null
    try {
        $proc=Start-Process -FilePath powershell.exe -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded) -WindowStyle Hidden -PassThru
        if(-not $proc.WaitForExit(30000)){
            Write-Log "Remove-PrinterDriver timed out for '$DriverName'; releasing PrintIsolationHost before continuing." 'WARN'
            try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}
            [void](Stop-SpoolerSafe -TimeoutSec 15 -Quiet)
            try { Get-Process PrintIsolationHost -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue } catch {}
            Start-Sleep 2
            [void](Start-SpoolerSafe -TimeoutSec 30 -Quiet)
        }
    } catch {
        Write-Log "Soft driver re-registration could not be started: $($_.Exception.Message)" 'WARN'
    }

    [void](Restart-SpoolerSafe -TimeoutSec 30 -Quiet); Start-Sleep 2
    try {
        Add-PrinterDriver -Name $DriverName -ErrorAction Stop
        Write-Log "Native driver re-registered: $DriverName" 'OK'
        return $true
    } catch {
        # It may already be registered and healthy even if Add-PrinterDriver reports an error.
        $d=@(Get-PrinterDriver -ErrorAction SilentlyContinue | Where-Object {$_.Name -ieq $DriverName}) | Select-Object -First 1
        if($d){
            Write-Log "Native driver remains registered: $DriverName" 'OK'
            return $true
        }
        Write-Log "Driver '$DriverName' could not be re-registered: $($_.Exception.Message)" 'ERROR'
        return $false
    }
}

function Get-NativeLocalFallbackPrinter {
    param(
        [Parameter(Mandatory)][string]$UncPort,
        [string]$DriverName,
        [switch]$IncludePendingDeletion
    )
    $items=@(Get-Printer -Full -ErrorAction SilentlyContinue | Where-Object {
        $_.Type -eq 'Local' -and $_.PortName -ieq $UncPort
    })
    if($DriverName){
        $items=@($items | Where-Object {$_.DriverName -ieq $DriverName})
    }
    if($items.Count -eq 0){ return $null }

    # A queue in PendingDeletion is not reusable. Prefer a stable queue when a
    # stale pending-delete queue and a newly-created replacement coexist.
    $stable=@($items | Where-Object {$_.PrinterStatus -ne 'PendingDeletion'})
    if($stable.Count -gt 0){ return $stable[0] }
    if($IncludePendingDeletion){ return $items[0] }
    return $null
}

function Invoke-PendingDeletionQueueCleanup {
    param([Parameter(Mandatory)][string]$PrinterName)

    Write-Log "Queue '$PrinterName' is in PendingDeletion state. Completing stale deletion before continuing with fallback." 'WARN'

    # Best effort: release print jobs/driver-host handles, then cycle Spooler so
    # Windows can finalize a deletion that is already pending. We deliberately
    # do NOT purge the global spool directory or remove driver packages here.
    try {
        $safe=[WildcardPattern]::Escape($PrinterName)
        Get-PrintJob -PrinterName $safe -ErrorAction SilentlyContinue |
            Remove-PrintJob -ErrorAction SilentlyContinue
    } catch {}

    [void](Stop-SpoolerSafe -TimeoutSec 15 -Quiet)
    try { Get-Process PrintIsolationHost -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue } catch {}
    try { Get-Process splwow64 -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue } catch {}
    Start-Sleep 2
    [void](Start-SpoolerSafe -TimeoutSec 30 -Quiet)
    Start-Sleep 4

    $after=@(Get-Printer -Full -ErrorAction SilentlyContinue | Where-Object {$_.Name -ieq $PrinterName}) | Select-Object -First 1
    if(-not $after){
        Write-Log "PendingDeletion completed; the stale queue is gone: $PrinterName" 'OK'
        return
    }
    if($after.PrinterStatus -ne 'PendingDeletion'){
        Write-Log "Queue recovered from PendingDeletion: $PrinterName ($($after.PrinterStatus))" 'OK'
        return
    }

    # If Windows still exposes the stale object, request deletion once more and
    # cycle Spooler. The fallback can then create a fresh queue with a unique name
    # if the old object still needs a reboot/logoff to disappear completely.
    try {
        $safe=[WildcardPattern]::Escape($PrinterName)
        Remove-Printer -Name $safe -ErrorAction SilentlyContinue
    } catch {}
    [void](Restart-SpoolerSafe -TimeoutSec 30 -Quiet)
    Start-Sleep 4

    $left=@(Get-Printer -Full -ErrorAction SilentlyContinue | Where-Object {$_.Name -ieq $PrinterName}) | Select-Object -First 1
    if($left -and $left.PrinterStatus -eq 'PendingDeletion'){
        Write-Log 'The stale queue is still PendingDeletion; the toolkit will ignore it and create a replacement queue with a unique name.' 'WARN'
    } elseif($left) {
        Write-Log "The stale queue changed state to $($left.PrinterStatus)." 'OK'
    } else {
        Write-Log 'The stale PendingDeletion queue was removed.' 'OK'
    }
}

function Invoke-NativeLocalPortFallback {
    param(
        [Parameter(Mandatory)][string]$Server,
        [Parameter(Mandatory)][string]$Share,
        [string]$ExpectedDisplayName
    )

    Write-Host ''
    Show-Section 'FALLBACK - NATIVE LOCAL PORT'
    $unc="\\$Server\$Share"

    $driverName=Resolve-LocalPrinterDriverName -ExpectedDisplayName $ExpectedDisplayName
    if(-not $driverName){
        Write-Log "A native driver for '$ExpectedDisplayName' is not available on the CLIENT. Local-port fallback was not forced." 'ERROR'
        Write-Host 'Install the correct vendor/native driver on the CLIENT, then run Menu 2 again.' -ForegroundColor Yellow
        return $null
    }
    Write-Log "Native driver CLIENT: $driverName" 'OK'

    $existing=Get-NativeLocalFallbackPrinter -UncPort $unc -DriverName $driverName
    if($existing){
        Write-Log "A stable native local-port queue already exists: $($existing.Name)" 'OK'
        return $existing
    }

    $pending=Get-NativeLocalFallbackPrinter -UncPort $unc -DriverName $driverName -IncludePendingDeletion
    if($pending -and $pending.PrinterStatus -eq 'PendingDeletion'){
        Invoke-PendingDeletionQueueCleanup -PrinterName $pending.Name
        $existing=Get-NativeLocalFallbackPrinter -UncPort $unc -DriverName $driverName
        if($existing){
            Write-Log "The native local-port queue is stable again: $($existing.Name)" 'OK'
            return $existing
        }
    }

    # The failed /in may leave a V3 driver registered but not loadable. Re-register
    # it only when no queue currently depends on the driver.
    [void](Invoke-SafeDriverReregister -DriverName $driverName)

    $port=@(Get-PrinterPort -ErrorAction SilentlyContinue | Where-Object {$_.Name -ieq $unc}) | Select-Object -First 1
    if(-not $port){
        try {
            Add-PrinterPort -Name $unc -ErrorAction Stop
            Write-Log "Local Port created: $unc" 'OK'
        } catch {
            Write-Log "Failed to create Local Port '$unc': $($_.Exception.Message)" 'ERROR'
            return $null
        }
    }

    $base=if($ExpectedDisplayName){"$ExpectedDisplayName on $Server"}else{"$Share on $Server"}
    $queueName=$base
    $n=2
    while(@(Get-Printer -ErrorAction SilentlyContinue | Where-Object {$_.Name -ieq $queueName}).Count -gt 0){
        $queueName="$base ($n)"; $n++
    }

    try {
        Add-Printer -Name $queueName -DriverName $driverName -PortName $unc -ErrorAction Stop
        Start-Sleep 3
    } catch {
        Write-Log "Native Local Port installation failed: $($_.Exception.Message)" 'ERROR'
        return $null
    }

    $p=Get-NativeLocalFallbackPrinter -UncPort $unc -DriverName $driverName
    if(-not $p){
        $pending=Get-NativeLocalFallbackPrinter -UncPort $unc -DriverName $driverName -IncludePendingDeletion
        if($pending -and $pending.PrinterStatus -eq 'PendingDeletion'){
            Invoke-PendingDeletionQueueCleanup -PrinterName $pending.Name
            $p=Get-NativeLocalFallbackPrinter -UncPort $unc -DriverName $driverName
        }
    }
    if($p){ Write-Log "Native Local Port is installed and stable: $($p.Name)" 'OK' }
    return $p
}

function Get-NativeLocalPortHealthReport {
    param(
        [Parameter(Mandatory)][string]$Server,
        [Parameter(Mandatory)][string]$Share,
        [Parameter(Mandatory)]$Printer,
        [bool]$ShareVerified=$false
    )
    $unc="\\$Server\$Share"
    $tcp445=$false
    try { $tcp445=(Test-NetConnection $Server -Port 445 -WarningAction SilentlyContinue -InformationLevel Quiet) } catch {}
    $spool=Get-Service Spooler -ErrorAction SilentlyContinue
    $driverOk=$false
    if($Printer){ $driverOk=[bool](@(Get-PrinterDriver -ErrorAction SilentlyContinue | Where-Object {$_.Name -ieq $Printer.DriverName}).Count -gt 0) }
    $portOk=[bool](@(Get-PrinterPort -ErrorAction SilentlyContinue | Where-Object {$_.Name -ieq $unc}).Count -gt 0)
    $checks=[ordered]@{
        'TCP 445'            = [bool]$tcp445
        'Share verified'     = [bool]$ShareVerified
        'Spooler running'    = [bool]($spool -and $spool.Status -eq 'Running')
        'Native driver'      = [bool]$driverOk
        'UNC Local Port'     = [bool]$portOk
        'Printer Type Local' = [bool]($Printer -and $Printer.Type -eq 'Local')
        'Correct UNC port'   = [bool]($Printer -and $Printer.PortName -ieq $unc)
        'Printer Normal'     = [bool]($Printer -and $Printer.PrinterStatus -eq 'Normal')
    }
    $failed=@($checks.GetEnumerator() | Where-Object {-not $_.Value} | ForEach-Object {$_.Key})
    [pscustomobject]@{Ready=($failed.Count -eq 0);Checks=$checks;Failed=$failed}
}

function Get-ClientHealthReport {
    param(
        [Parameter(Mandatory)][string]$Server,
        [Parameter(Mandatory)][string]$Share,
        [Parameter(Mandatory)]$Printer,
        [Parameter(Mandatory)][object[]]$ValidShareRecords,
        [bool]$ShareVerified=$false
    )
    $policyPath='HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers'
    $policy=if(Test-Path $policyPath){ (Get-ItemProperty $policyPath -ErrorAction SilentlyContinue).ForceCSREMFDespooling }else{$null}
    $tcp445=$false
    try { $tcp445=(Test-NetConnection $Server -Port 445 -WarningAction SilentlyContinue -InformationLevel Quiet) } catch {}
    $spool=(Get-Service Spooler -ErrorAction SilentlyContinue)

    $validKeys=@{}
    foreach($r in @($ValidShareRecords)){
        if($r.ShareName){$validKeys[(($r.ShareName -replace '[^A-Za-z0-9]','').ToLowerInvariant())]=$true}
    }
    $invalidGa=0
    foreach($mc in @(Get-MachinePrintConnections -Server $Server)){
        if(-not $mc.Printer){continue}
        $prefix="\\$Server\"
        if(-not $mc.Printer.StartsWith($prefix,[System.StringComparison]::OrdinalIgnoreCase)){continue}
        $sp=$mc.Printer.Substring($prefix.Length)
        $key=(($sp -replace '[^A-Za-z0-9]','').ToLowerInvariant())
        if(-not $validKeys.ContainsKey($key)){$invalidGa++}
    }

    $checks=[ordered]@{
        'TCP 445'          = [bool]$tcp445
        'Share verified'   = [bool]$ShareVerified
        'Spooler running'  = [bool]($spool -and $spool.Status -eq 'Running')
        'SSR policy = 1'   = [bool]($policy -eq 1)
        'Native Connection'= [bool]($Printer -and $Printer.Type -eq 'Connection')
        'Correct server'   = [bool]($Printer -and ($Printer.ComputerName -ieq $Server -or $Printer.Name -like "\\$Server\*"))
        'Rendering = SSR'  = [bool]($Printer -and $Printer.RenderingMode -eq 'SSR')
        'Printer Normal'   = [bool]($Printer -and $Printer.PrinterStatus -eq 'Normal')
        'No invalid /ga'   = [bool]($invalidGa -eq 0)
    }
    $failed=@($checks.GetEnumerator() | Where-Object {-not $_.Value} | ForEach-Object {$_.Key})
    [pscustomobject]@{Ready=($failed.Count -eq 0);Checks=$checks;Failed=$failed}
}

function Show-HealthReport {
    param([Parameter(Mandatory)]$Report,[string]$Title='FINAL HEALTH CHECK')
    Show-Section $Title
    foreach($kv in $Report.Checks.GetEnumerator()){
        $tag=if($kv.Value){'[OK]'}else{'[FAIL]'}
        $color=if($kv.Value){'Green'}else{'Red'}
        Write-Host ("{0} {1}" -f $tag,$kv.Key) -ForegroundColor $color
    }
}

function Invoke-ClientSelfCorrection {
    param(
        [Parameter(Mandatory)][string]$Server,
        [Parameter(Mandatory)][string]$Share,
        [Parameter(Mandatory)][object[]]$ShareRecords,
        [string]$ExpectedDisplayName,
        [string[]]$BeforeNames=@(),
        $Printer
    )
    Write-Host ''
    Write-Host '=== AUTO-CORRECTION PASS ===' -ForegroundColor Yellow

    $policy=Set-ClientSSR
    if($policy -eq 1){ Write-Log 'SSR policy confirmed at 1.' 'OK' }

    [void](Remove-StaleMachineConnections -Server $Server -ValidShareRecords $ShareRecords)

    $spool=Get-Service Spooler -ErrorAction SilentlyContinue
    if(-not $spool -or $spool.Status -ne 'Running'){
        [void](Start-SpoolerSafe -TimeoutSec 30 -Quiet)
    }

    if($Printer -and $Printer.Type -eq 'Connection' -and $Printer.RenderingMode -ne 'SSR'){
        Write-Log "Connection is still using $($Printer.RenderingMode). Recreating it once after applying the SSR policy." 'WARN'
        try { Remove-Printer -Name $Printer.Name -ErrorAction Stop } catch { Write-Log "Failed to remove the connection for repair: $($_.Exception.Message)" 'WARN' }
        [void](Restart-SpoolerSafe -TimeoutSec 30 -Quiet)
        Start-Sleep 2
        $Printer=$null
    }

    if(-not $Printer){
        $unc="\\$Server\$Share"
        Write-Log "One repair installation attempt with /in: $unc" 'INFO'
        $repairProc=$null
        try { $repairProc=Start-Process -FilePath rundll32.exe -ArgumentList @('printui.dll,PrintUIEntry','/in','/n',"`"$unc`"") -PassThru } catch {}
        $deadline=(Get-Date).AddSeconds(120)
        do {
            $Printer=Get-TargetConnection -Server $Server -ExpectedDisplayName $ExpectedDisplayName -BeforeNames $BeforeNames
            $repairExited=$true
            if($repairProc){try{$repairProc.Refresh()}catch{};$repairExited=$repairProc.HasExited}
            if($Printer -and $repairExited){ break }
            Start-Sleep 3
        } while((Get-Date) -lt $deadline)
        if($repairProc){
            try{$repairProc.Refresh()}catch{}
            if(-not $repairProc.HasExited){
                Write-Log 'The repair installer is still running after 120 seconds; stopping it to prevent overlapping installers.' 'WARN'
                try{Stop-Process -Id $repairProc.Id -Force -ErrorAction SilentlyContinue}catch{}
                Start-Sleep 2
            }
        }
        if(-not $Printer){$Printer=Get-TargetConnection -Server $Server -ExpectedDisplayName $ExpectedDisplayName -BeforeNames $BeforeNames}
    }

    if($Printer -and $Printer.PrinterStatus -ne 'Normal'){
        Write-Log "PrinterStatus=$($Printer.PrinterStatus). Restarting the Print Spooler before rechecking." 'WARN'
        [void](Restart-SpoolerSafe -TimeoutSec 30 -Quiet)
        Start-Sleep 3
        $Printer=Get-TargetConnection -Server $Server -ExpectedDisplayName $ExpectedDisplayName -BeforeNames $BeforeNames
    }
    return $Printer
}

function Invoke-ClientConnect {
    Show-ToolkitHeader 'CONNECT / REPAIR CLIENT'
    $server=Read-Required 'Host IP / hostname'
    $share=Read-Required 'Printer ShareName'
    $unc="\\$server\$share"

    Write-Step 1 5 'PREFLIGHT'
    $t445=Test-NetConnection $server -Port 445 -WarningAction SilentlyContinue
    Write-UiStatus $(if($t445.TcpTestSucceeded){'OK'}else{'FAIL'}) "TCP 445"
    if(-not $t445.TcpTestSucceeded){Write-Log 'STOP: TCP 445 failed.' 'ERROR';Pause-Toolkit;return}
    $t135=Test-NetConnection $server -Port 135 -WarningAction SilentlyContinue
    Write-UiStatus $(if($t135.TcpTestSucceeded){'OK'}else{'WARN'}) "TCP 135"
    if(-not $t135.TcpTestSucceeded){Write-Log 'RPC 135 failed. Continuing, but the printer connection may not work correctly.' 'WARN'}
    Write-Log "ForceCSREMFDespooling=$(Set-ClientSSR)" 'OK'

    $profile=$null
    foreach($pf in @(Get-ChildItem $ProfileDir -Filter *.json -ErrorAction SilentlyContinue)){
        try{ $x=Get-Content $pf.FullName -Raw|ConvertFrom-Json; if($x.HostIP -contains $server){$profile=$x;break} }catch{}
    }
    if($profile){
        $defAdmin="$($profile.HostName)\$($profile.Administrator.Name)"
    } else {
        $remoteHost=Resolve-RemoteHostName -Server $server
        $defAdmin=if($remoteHost){"$remoteHost\Administrator"}else{'Administrator'}
    }
    Write-Step 2 5 'AUTHENTICATION'
    Write-UiStatus 'INFO' 'Credential HOST: Built-in Administrator RID 500.'
    $admin=Read-Host "HOST Built-in Administrator RID500 logon [$defAdmin]"
    if(!$admin){$admin=$defAdmin}
    if($profile -and ($admin -ine $defAdmin)){
        Write-Log "STOP: the Host Profile specifies RID500 account '$defAdmin'. Other accounts are not accepted by this strict workflow." 'ERROR'
        Pause-Toolkit;return
    }

    Write-UiStatus 'INFO' 'Credential test: 1 attempt (lockout guard).'
    $sec=Read-Host "Password HOST account '$admin'" -AsSecureString
    $b=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try{
        $plain=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($b)
        Clear-SmbServerSessions $server
        Remove-CmdKeySafe -Target $server
        $cmdKeyCode=Add-CmdKeySafe -Target $server -User $admin -Password $plain
        if($cmdKeyCode -ne 0){throw 'cmdkey failed'}
        $auth=Test-SmbOnce $server $admin $plain
        if(-not $auth.Success){
            Write-Host $auth.Output -ForegroundColor Red
            if($auth.Locked){Write-Log 'ACCOUNT LOCKED (1909). Retries stopped.' 'ERROR'}
            elseif($auth.Bad){Write-Log 'Credentials rejected (1326). Retries stopped.' 'ERROR'}
            elseif($auth.Conflict){Write-Log 'SMB conflict (1219).' 'ERROR'}
            else{Write-Log "SMB authentication failed with code=$($auth.Code)" 'ERROR'}
            Pause-Toolkit;return
        }
    }finally{
        if($b -ne [IntPtr]::Zero){[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b)}
        $plain=$null
    }
    Write-Log 'SMB AUTH = OK' 'OK'
    Write-Step 3 5 'SHARE CHECK'

    $oldEap=$ErrorActionPreference
    try { $ErrorActionPreference='Continue'; $view=(& net.exe view "\\$server" 2>&1|Out-String); $viewCode=$LASTEXITCODE }
    catch { $view=$_.Exception.Message; $viewCode=1 }
    finally { $ErrorActionPreference=$oldEap }
    if($script:TechnicianMode){ Write-Host $view }
    if($viewCode -ne 0){Write-Log "NET VIEW failed. ExitCode=$viewCode" 'ERROR';Pause-Toolkit;return}

    $shareRecords=@(Get-PrinterShareRecordsFromNetView -Text $view)
    $shareKey=(($share -replace '[^A-Za-z0-9]','').ToLowerInvariant())
    $record=@($shareRecords | Where-Object {(($_.ShareName -replace '[^A-Za-z0-9]','').ToLowerInvariant()) -eq $shareKey}) | Select-Object -First 1
    if(-not $record){
        Write-Log "Share '$share' does not match a HOST print share." 'WARN'
        if($shareRecords.Count -eq 0){Write-Log 'No print shares were detected. STOP.' 'ERROR';Pause-Toolkit;return}
        Write-Host 'Available print shares:' -ForegroundColor Yellow
        for($i=0;$i -lt $shareRecords.Count;$i++){
            Write-Host ("[{0}] {1} | {2}" -f ($i+1),$shareRecords[$i].ShareName,$shareRecords[$i].Comment)
        }
        $pick=Read-Host 'Select the correct share number'
        $idx=0
        if((-not [int]::TryParse($pick,[ref]$idx)) -or $idx -lt 1 -or $idx -gt $shareRecords.Count){Write-Log 'Invalid share selection.' 'ERROR';Pause-Toolkit;return}
        $record=$shareRecords[$idx-1]
        $share=$record.ShareName
        $unc="\\$server\$share"
        Write-Log "Target share corrected to: $share" 'OK'
    } else {
        $share=$record.ShareName
        $unc="\\$server\$share"
        Write-Log "Printer share verified: $share" 'OK'
    }

    $expectedDisplayName=[string]$record.Comment
    if($expectedDisplayName){Write-Host "HOST queue/display name: $expectedDisplayName" -ForegroundColor Cyan}

    # Clean only invalid per-machine entries that point to non-existent shares on THIS host.
    [void](Remove-StaleMachineConnections -Server $server -ValidShareRecords $shareRecords)

    $before=@(Get-Printer -Full -ErrorAction SilentlyContinue | Where-Object {$_.Type -eq 'Connection' -and ($_.ComputerName -ieq $server -or $_.Name -like "\\$server\*")})

    # Windows PowerShell 5.1 + Set-StrictMode compatibility:
    # Property enumeration on an EMPTY array (e.g. $before.Name) can throw
    # "The property 'Name' cannot be found on this object". Build the name
    # list explicitly so a client with zero existing connections is valid.
    $beforeNames=@()
    foreach($bp in $before){
        if($null -eq $bp){ continue }
        $nameProp=$bp.PSObject.Properties['Name']
        if($nameProp){
            $bn=[string]$nameProp.Value
            if(-not [string]::IsNullOrWhiteSpace($bn)){ $beforeNames += $bn }
        }
    }

    Write-Step 4 5 'INSTALL'
    $usingLocalFallback=$false
    $existing=Get-TargetConnection -Server $server -ExpectedDisplayName $expectedDisplayName -BeforeNames @()
    if($existing -and $existing.Type -eq 'Connection' -and $existing.RenderingMode -eq 'SSR' -and $existing.PrinterStatus -eq 'Normal'){
        Write-Log "Target connection is already healthy: $($existing.Name)" 'OK'
        $final=$existing
        $method='Existing healthy connection'
    } else {
        # Avoid automatic /ga when the current process belongs to another account.
        # /ga is handled only as an explicit fallback after exact duplicate checks.
        $interactive=(Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).UserName
        $current="$env:USERDOMAIN\$env:USERNAME"
        if($interactive -and ($interactive -ine $current)){
            Write-Log "Interactive user '$interactive' differs from elevated context '$current'." 'WARN'
            $exactGa=@(Get-MachinePrintConnections -Server $server | Where-Object {$_.Printer -ieq $unc})
            if($exactGa.Count -eq 0){
                if(Confirm-Action 'Create a per-computer /ga connection for the interactive user? Sign-out and sign-in will be required.' $false){
                    & rundll32.exe printui.dll,PrintUIEntry /ga /n "$unc"
                    Start-Sleep 2
                    $exactGa=@(Get-MachinePrintConnections -Server $server | Where-Object {$_.Printer -ieq $unc})
                }
            }
            if($exactGa.Count -gt 0){
                Write-Log "Per-machine connection registered: $unc" 'WARN'
                Write-Host "STATUS: PENDING LOGON - Sign out, sign in as '$interactive', then run Menu 2 for final verification." -ForegroundColor Yellow
            } else {
                Write-Log 'The /ga connection was not created. Run the toolkit from the account that will use the printer.' 'ERROR'
            }
            Pause-Toolkit;return
        }

        if($existing -and ($existing.RenderingMode -ne 'SSR')){
            Write-Log "The existing connection is not using SSR ($($existing.RenderingMode)). Applying a correction." 'WARN'
            try { Remove-Printer -Name $existing.Name -ErrorAction Stop; Start-Sleep 2 } catch { Write-Log "Failed to remove the existing connection: $($_.Exception.Message)" 'WARN' }
        }

        if(-not (Restart-SpoolerSafe -TimeoutSec 30)){
            Write-Log 'CLIENT installation stopped: the Print Spooler failed to reach Running state.' 'ERROR'
            Pause-Toolkit
            return
        }
        Start-Sleep 2
        Write-UiStatus 'WORK' 'Primary: SSR / Point-and-Print (PrintUIEntry /in)'
        Write-Tech 'No second installer is running in parallel.'
        $method='PrintUIEntry /in'
        try { $proc=Start-Process -FilePath rundll32.exe -ArgumentList @('printui.dll,PrintUIEntry','/in','/n',"`"$unc`"") -PassThru }
        catch { $proc=$null; Write-Log "Failed to start /in: $($_.Exception.Message)" 'ERROR' }

        $deadline=(Get-Date).AddSeconds(180)
        $final=$null
        do {
            $final=Get-TargetConnection -Server $server -ExpectedDisplayName $expectedDisplayName -BeforeNames $beforeNames
            $procExited=$true
            if($proc){try{$proc.Refresh()}catch{};$procExited=$proc.HasExited}
            if($final -and $procExited){break}
            if((-not $final) -and $procExited){break}
            Start-Sleep 3
        } while((Get-Date) -lt $deadline)

        if($proc){
            try{$proc.Refresh()}catch{}
            if(-not $proc.HasExited -and (Get-Date) -ge $deadline){
                Write-Log 'The /in installer is still running after 180 seconds; stopping it before the correction pass.' 'WARN'
                try{Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue}catch{}
                Start-Sleep 2
            }
        }
        if(-not $final){$final=Get-TargetConnection -Server $server -ExpectedDisplayName $expectedDisplayName -BeforeNames $beforeNames}

        if(-not $final){
            Write-Log 'PrintUIEntry /in did not create a connection. The installer will not be repeated; trying native Local Port fallback.' 'WARN'
            $final=Invoke-NativeLocalPortFallback -Server $server -Share $share -ExpectedDisplayName $expectedDisplayName
            if($final){
                $usingLocalFallback=$true
                $method='Native Local Port fallback'
            }
        }
    }

    if(-not $final){
        Write-Log 'FAILED: the target connection could not be created.' 'ERROR'
        if($script:TechnicianMode){
            Show-Section 'PRINTSERVICE EVENTS - LAST 10 MINUTES'
            $since=(Get-Date).AddMinutes(-10)
            Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-PrintService/Admin';StartTime=$since} -ErrorAction SilentlyContinue |
                Where-Object {$_.LevelDisplayName -in @('Error','Warning')} |
                Select-Object TimeCreated,Id,LevelDisplayName,Message | Format-List|Out-Host
        } else {
            Write-UiStatus 'INFO' 'Error details were saved to the log. Press T on the Main Menu for Technician View.'
        }
        Pause-Toolkit;return
    }

    # Re-run share check and remove invalid /ga before final verdict.
    [void](Remove-StaleMachineConnections -Server $server -ValidShareRecords $shareRecords)
    if($usingLocalFallback){
        $driverForFinal=[string]$final.DriverName
        $final=Get-NativeLocalFallbackPrinter -UncPort $unc -DriverName $driverForFinal
        if(-not $final){
            $pending=Get-NativeLocalFallbackPrinter -UncPort $unc -DriverName $driverForFinal -IncludePendingDeletion
            if($pending -and $pending.PrinterStatus -eq 'PendingDeletion'){
                Invoke-PendingDeletionQueueCleanup -PrinterName $pending.Name
                $final=Get-NativeLocalFallbackPrinter -UncPort $unc -DriverName $driverForFinal
            }
        }
        $report=Get-NativeLocalPortHealthReport -Server $server -Share $share -Printer $final -ShareVerified:$true
    } else {
        $final=Get-TargetConnection -Server $server -ExpectedDisplayName $expectedDisplayName -BeforeNames $beforeNames
        $report=Get-ClientHealthReport -Server $server -Share $share -Printer $final -ValidShareRecords $shareRecords -ShareVerified:$true

        if(-not $report.Ready){
            Show-HealthReport -Report $report -Title 'HEALTH CHECK BEFORE CORRECTION'
            $final=Invoke-ClientSelfCorrection -Server $server -Share $share -ShareRecords $shareRecords -ExpectedDisplayName $expectedDisplayName -BeforeNames $beforeNames -Printer $final
            [void](Remove-StaleMachineConnections -Server $server -ValidShareRecords $shareRecords)
            $final=Get-TargetConnection -Server $server -ExpectedDisplayName $expectedDisplayName -BeforeNames $beforeNames
            $report=Get-ClientHealthReport -Server $server -Share $share -Printer $final -ValidShareRecords $shareRecords -ShareVerified:$true
        }
    }

    Write-Step 5 5 'FINAL CHECK'
    if($final){
        if($script:TechnicianMode){$final | Select Name,ComputerName,DriverName,PortName,Type,RenderingMode,PrinterStatus | Format-List|Out-Host}
        Write-UiStatus 'INFO' "Install method: $method"
    }
    Show-HealthReport -Report $report

    if($report.Ready){
        Show-ResultCard -Status 'READY TO PRINT' -Printer $final.Name -Method $method -Driver $final.DriverName -Port $final.PortName
        if($usingLocalFallback){
            Write-Log 'Native Local Port fallback is healthy.' 'OK'
        } else {
            Write-Log 'SSR connection is healthy.' 'OK'
        }
        if(Confirm-Action 'Send a Windows Test Page for physical verification?' $true){
            & rundll32.exe printui.dll,PrintUIEntry /k /n "$($final.Name)"
            Write-Log 'Test page command sent.' 'INFO'
            Start-Sleep 3
            if(Confirm-Action 'Did the physical test page print successfully?' $false){
                Write-Log 'STATUS: FULLY VERIFIED - healthy configuration and successful physical print.' 'OK'
            } else {
                Write-Log 'STATUS: CONFIGURATION READY, but the physical print result is not confirmed.' 'WARN'
            }
        }
    } else {
        Show-ResultCard -Status 'DEGRADED / FAILED' -Printer $(if($final){$final.Name}else{'-'}) -Method $method -Driver $(if($final){$final.DriverName}else{'-'}) -Port $(if($final){$final.PortName}else{'-'})
        Write-Log ("STATUS: DEGRADED/FAILED - " + ($report.Failed -join ', ')) 'ERROR'
        if($usingLocalFallback){
            Write-Host 'Native Local Port fallback is not healthy. Check the CLIENT driver, SMB credentials, and HOST share.' -ForegroundColor Yellow
        } else {
            Write-Host 'The toolkit did not create /ga automatically because the per-user connection is not healthy.' -ForegroundColor Yellow
        }
    }
    Pause-Toolkit
}

function Invoke-FullDiagnostic {
    Show-ToolkitHeader 'FULL DIAGNOSTIC'
    Show-Section 'SYSTEM + PRINT DIAGNOSTIC'
    Write-Host "Computer: $env:COMPUTERNAME"; Write-Host "User: $env:USERDOMAIN\$env:USERNAME"; Get-IPv4List|Format-Table -AutoSize
    Write-Host '[BUILT-IN ADMIN]' -ForegroundColor Yellow; $a=Get-BuiltinAdmin;if($a){$c=Get-AccountCim $a.Name;[pscustomobject]@{Name=$a.Name;SID=$a.SID;Enabled=$a.Enabled;Locked=if($c){$c.Lockout}else{$null};PasswordRequired=if($c){$c.PasswordRequired}else{$null}}|Format-List}else{Write-Host 'RID 500 NOT FOUND' -ForegroundColor Red}
    Write-Host '[SERVICES]' -ForegroundColor Yellow; Get-Service Spooler,LanmanServer,LanmanWorkstation -ErrorAction SilentlyContinue|Select Name,Status,StartType|Format-Table -AutoSize
    Write-Host '[PRINTERS]' -ForegroundColor Yellow; Get-Printer -Full -ErrorAction SilentlyContinue|Select Name,ComputerName,DriverName,PortName,Type,Shared,ShareName,RenderingMode,PrinterStatus|Format-Table -AutoSize
    Write-Host '[SMB CONNECTIONS]' -ForegroundColor Yellow; Get-SmbConnection -ErrorAction SilentlyContinue|Select ServerName,ShareName,UserName,Dialect,NumOpens|Format-Table -AutoSize
    Write-Host '[PRINTSERVICE ERRORS]' -ForegroundColor Yellow; Get-WinEvent -LogName 'Microsoft-Windows-PrintService/Admin' -MaxEvents 10 -ErrorAction SilentlyContinue|Where-Object{$_.LevelDisplayName -in @('Error','Warning')}|Select TimeCreated,Id,LevelDisplayName,Message|Format-List
    $target=Read-Host 'Optional target HOST IP (ENTER=skip)'; if($target){foreach($pt in 445,135){$r=Test-NetConnection $target -Port $pt -WarningAction SilentlyContinue;Write-Host "TCP ${pt}: $($r.TcpTestSucceeded)"}; & net.exe view "\\$target"}
    Write-Log 'Full diagnostic completed.' 'OK'; Pause-Toolkit
}
function Invoke-Cleanup {
    Show-ToolkitHeader 'CLEANUP PRINTER QUEUE'
    $all=@(Get-Printer -Full -ErrorAction SilentlyContinue|Sort-Object Name); if(!$all){Pause-Toolkit;return}; for($i=0;$i -lt $all.Count;$i++){Write-Host ("[{0}] {1} | {2} | {3} | {4}" -f ($i+1),$all[$i].Name,$all[$i].DriverName,$all[$i].Type,$all[$i].RenderingMode)}
    $n=0;if((-not [int]::TryParse((Read-Host 'Printer number (0=Cancel)'),[ref]$n)) -or $n -eq 0){return};if($n -lt 1 -or $n -gt $all.Count){return};$p=$all[$n-1];if(Confirm-Action "Remove '$($p.Name)'?" $false){try{Remove-Printer -Name $p.Name -ErrorAction Stop;Write-Log "Removed: $($p.Name)" 'OK'}catch{Write-Log $_.Exception.Message 'ERROR'}};Pause-Toolkit
}
function Invoke-TestPrint {
    Show-ToolkitHeader 'TEST PRINT'
    $all=@(Get-Printer -Full -ErrorAction SilentlyContinue|Sort-Object Name);for($i=0;$i -lt $all.Count;$i++){Write-Host ("[{0}] {1} | {2} | {3}" -f ($i+1),$all[$i].Name,$all[$i].Type,$all[$i].PrinterStatus)};$n=0;if((-not [int]::TryParse((Read-Host 'Printer number (0=Cancel)'),[ref]$n)) -or $n -eq 0){return};if($n -lt 1 -or $n -gt $all.Count){return};& rundll32.exe printui.dll,PrintUIEntry /k /n "$($all[$n-1].Name)";Write-Log 'Test page sent.' 'INFO';Pause-Toolkit
}
function Invoke-HealthCheck { Show-ToolkitHeader 'WINDOWS / SAM HEALTH CHECK'; Write-UiStatus 'INFO' 'READ ONLY: SFC /verifyonly + DISM /ScanHealth'; & sfc.exe /verifyonly; & dism.exe /Online /Cleanup-Image /ScanHealth; Pause-Toolkit }

# MAIN MENU
function Start-PSTKMenu {
while($true){
    Show-ToolkitHeader 'MAIN MENU'
    Write-Host ''
    Write-Host ' [1] Setup / Repair Printer HOST'
    Write-Host ' [2] Connect / Repair Printer CLIENT'
    Write-Host ' [3] Built-in Administrator Readiness'
    Write-Host ' [4] Full Diagnostic'
    Write-Host ' [5] Cleanup Printer Queue'
    Write-Host ' [6] Test Print'
    Write-Host ' [7] Windows/SAM Health Check (Read Only)'
    Write-Host ' [8] Rollback Last HOST Setup'
    Write-Host ''
    Write-Host (" [T] Technician View : {0}" -f $(if($script:TechnicianMode){'ON'}else{'OFF'})) -ForegroundColor $(if($script:TechnicianMode){'Yellow'}else{'Gray'})
    Write-Host ' [L] Open Logs Folder' -ForegroundColor Gray
    Write-Host ' [0] Exit'
    Write-Host ''
    Write-Host ('-' * 56) -ForegroundColor DarkGray
    $m=(Read-Host ' Select').Trim()
    try{
        switch($m.ToUpperInvariant()){
            '1'{Invoke-HostSetup}
            '2'{Invoke-ClientConnect}
            '3'{Show-ToolkitHeader 'BUILT-IN ADMINISTRATOR READINESS';[void](Invoke-AdminReadiness -Repair);Pause-Toolkit}
            '4'{Invoke-FullDiagnostic}
            '5'{Invoke-Cleanup}
            '6'{Invoke-TestPrint}
            '7'{Invoke-HealthCheck}
            '8'{Restore-HostTransaction}
            'T'{$script:TechnicianMode=-not $script:TechnicianMode}
            'L'{Start-Process explorer.exe $LogDir}
            '0'{break}
            default{Write-UiStatus 'WARN' 'Invalid menu option.';Start-Sleep 1}
        }
    }catch{
        Write-Log "Unhandled error: $($_.Exception.Message)" 'ERROR'
        if($script:TechnicianMode){Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray}
        else{Write-UiStatus 'INFO' 'Stack trace details are available in Technician View or the log.'}
        Pause-Toolkit
    }
    if($m -eq '0'){break}
}
}

if($env:PSTK_IMPORT_ONLY -ne '1'){Start-PSTKMenu}
