param([string]$OutputDirectory)
$ErrorActionPreference='Stop'
[void][IO.Directory]::CreateDirectory($OutputDirectory)
$root=Split-Path -Parent $PSScriptRoot
$fixture=Join-Path $OutputDirectory 'fixture'
Copy-Item -LiteralPath (Join-Path $root 'Core') -Destination $fixture -Recurse
$old=$env:PSTK_IMPORT_ONLY;$env:PSTK_IMPORT_ONLY='1'
try{. (Join-Path $fixture 'Toolkit.ps1')}finally{$env:PSTK_IMPORT_ONLY=$old}

# Every Windows printer operation is mocked. Names deliberately include characters
# that must be treated literally rather than as patterns or shell commands.
$script:selectedName="A Selected [USB] & O'Brien"
$script:otherName='B Other Printer'
function Reset-CleanupFixture {
    $script:printers=@(
        [pscustomobject]@{Name=$script:selectedName;DriverName='Vendor Driver';Type='Local';PortName='USB001';Preferences='custom-label';Shared=$true},
        [pscustomobject]@{Name=$script:otherName;DriverName='Other Driver';Type='Connection';PortName='OtherPort';Preferences='keep';Shared=$false}
    )
    $script:originalPrinters=$script:printers | ConvertTo-Json -Depth 4 -Compress
    $script:jobRows=@(
        [pscustomobject]@{ID=11;PrinterName=$script:selectedName;DocumentName='First document';JobStatus='Error'},
        [pscustomobject]@{ID=22;PrinterName=$script:selectedName;DocumentName='Second document';JobStatus='Printing'},
        [pscustomobject]@{ID=11;PrinterName=$script:otherName;DocumentName='Other printer document';JobStatus='Printing'}
    )
    $script:answers=@('1','A');$script:answerIndex=0;$script:confirmed=$true
    $script:logs=@();$script:jobRemovals=@();$script:printerRemovals=@()
    $script:jobReads=0;$script:failEnumeration=$false;$script:failRead=$false
    $script:failVerification=$false;$script:failJobId=-1;$script:pending=$false
    $script:newArrival=$false;$script:disappear=$false
    $script:pendingRemoval=$false;$script:failPrinterRemoval=$false
}
function Read-Host {
    param($Prompt)
    if($script:answerIndex -ge $script:answers.Count){throw "Unexpected prompt: $Prompt"}
    $answer=$script:answers[$script:answerIndex];$script:answerIndex++
    return $answer
}
function Show-ToolkitHeader {param($Screen)}
function Pause-Toolkit {}
function Confirm-Action {param($Message,$Default) return $script:confirmed}
function Write-UiStatus {param($Status,$Text) $script:logs+=@([pscustomobject]@{Level=$Status;Message=$Text})}
function Write-Log {param($Message,$Level) $script:logs+=@([pscustomobject]@{Level=$Level;Message=$Message})}
function Get-Printer {
    param([switch]$Full,$ErrorAction)
    if($script:failEnumeration){throw 'Simulated printer enumeration failure'}
    if($script:disappear -and $script:jobRemovals.Count){return @($script:printers | Where-Object Name -eq $script:otherName)}
    return $script:printers
}
function Get-PrintJob {
    param($PrinterName,$ErrorAction)
    $script:jobReads++
    if($script:failRead -or ($script:failVerification -and $script:jobReads -gt 1)){throw 'Simulated access denied reading print jobs'}
    if($script:newArrival -and $script:jobReads -eq 2){
        $script:jobRows+=@([pscustomobject]@{ID=33;PrinterName=$script:selectedName;DocumentName='New arrival';JobStatus='Printing'})
    }
    return @($script:jobRows | Where-Object PrinterName -eq $PrinterName)
}
function Remove-PrintJob {
    param($PrinterName,$ID,$ErrorAction)
    if($PrinterName -ne $script:selectedName){throw 'Attempted to cancel a job on another printer'}
    $script:jobRemovals+=@([pscustomobject]@{PrinterName=$PrinterName;ID=$ID})
    if($ID -eq $script:failJobId){throw 'Simulated cancellation access denied'}
    if(-not $script:pending){$script:jobRows=@($script:jobRows | Where-Object {-not ($_.PrinterName -eq $PrinterName -and $_.ID -eq $ID)})}
}
function Remove-Printer {
    param($InputObject,$Name,$ErrorAction)
    if($Name -or -not $InputObject){throw 'Printer removal must use the selected printer object'}
    $script:printerRemovals+=@($InputObject.Name)
    if($script:failPrinterRemoval){throw 'Simulated printer removal access denied'}
    if(-not $script:pendingRemoval){$script:printers=@($script:printers | Where-Object Name -ne $InputObject.Name)}
}
function Remove-PrinterDriver {throw 'Driver removal is forbidden during cleanup'}
function Remove-PrinterPort {throw 'Port removal is forbidden during cleanup'}
function Restart-SpoolerSafe {throw 'Global Spooler restart is forbidden during cleanup'}
function Stop-SpoolerSafe {throw 'Global Spooler stop is forbidden during cleanup'}
function Set-Printer {throw 'Printer settings must not change during cleanup'}
function Assert-Cleanup {
    param([bool]$Condition,[string]$Message)
    if(-not $Condition){throw $Message}
}
function Assert-PrintersPreserved {
    Assert-Cleanup ($script:printerRemovals.Count -eq 0) 'Job cleanup tried to remove an installed printer.'
    $actual=$script:printers | ConvertTo-Json -Depth 4 -Compress
    Assert-Cleanup ($actual -eq $script:originalPrinters) 'Printer installation or settings changed.'
    $otherJobs=@($script:jobRows | Where-Object PrinterName -eq $script:otherName)
    Assert-Cleanup ($otherJobs.Count -eq 1 -and $otherJobs[0].ID -eq 11) 'Another printer job was affected.'
}
function Assert-NoSuccess {
    Assert-Cleanup (@($script:logs | Where-Object Level -eq 'OK').Count -eq 0) 'Cleanup reported success without verification.'
}
function Assert-NoMutations {
    Assert-PrintersPreserved
    Assert-Cleanup ($script:jobRemovals.Count -eq 0) 'Cancellation or failed reads changed print jobs.'
}

$checks=0
Reset-CleanupFixture
$script:answers=@('1','2')
Invoke-Cleanup
Assert-PrintersPreserved
Assert-Cleanup ($script:jobRemovals.Count -eq 1 -and $script:jobRemovals[0].ID -eq 22) 'Single-job selection removed the wrong job.'
Assert-Cleanup (@($script:jobRows | Where-Object PrinterName -eq $script:selectedName).Count -eq 1) 'An unselected job was removed.'
Assert-Cleanup (@($script:logs | Where-Object Level -eq 'OK').Count -eq 1) 'Verified cancellation did not report success.'
$checks++

Reset-CleanupFixture
Invoke-Cleanup
Assert-PrintersPreserved
Assert-Cleanup ($script:jobRemovals.Count -eq 2) 'All-listed selection did not cancel both jobs.'
Assert-Cleanup (@($script:jobRows | Where-Object PrinterName -eq $script:selectedName).Count -eq 0) 'Selected jobs remain.'
$checks++

Reset-CleanupFixture
$script:newArrival=$true
Invoke-Cleanup
Assert-PrintersPreserved
Assert-Cleanup ($script:jobRemovals.Count -eq 2) 'A newly arrived job was included in cancellation.'
Assert-Cleanup (@($script:jobRows | Where-Object {$_.PrinterName -eq $script:selectedName -and $_.ID -eq 33}).Count -eq 1) 'A newly arrived job was lost.'
$checks++

Reset-CleanupFixture
$script:jobRows=@($script:jobRows | Where-Object PrinterName -eq $script:otherName)
Invoke-Cleanup
Assert-NoMutations
$checks++

Reset-CleanupFixture
$script:printers=@();$script:originalPrinters=$null
Invoke-Cleanup
Assert-NoMutations
$checks++

foreach($caseAnswers in @(@('0'),@('99'),@('invalid'),@('1','0'),@('1',''),@('1','99'),@('1','invalid'))){
    Reset-CleanupFixture
    $script:answers=@($caseAnswers)
    Invoke-Cleanup
    Assert-NoMutations
    Assert-NoSuccess
    $checks++
}

Reset-CleanupFixture
$script:confirmed=$false
Invoke-Cleanup
Assert-NoMutations
$checks++

foreach($failure in @('failEnumeration','failRead','failVerification','disappear')){
    Reset-CleanupFixture
    Set-Variable -Name $failure -Value $true -Scope Script
    Invoke-Cleanup
    Assert-PrintersPreserved
    Assert-NoSuccess
    Assert-Cleanup (@($script:logs | Where-Object Level -eq 'ERROR').Count -ge 1) 'Read or verification failure was not reported.'
    if($failure -in @('failEnumeration','failRead')){Assert-NoMutations}
    $checks++
}

Reset-CleanupFixture
$script:failJobId=11
Invoke-Cleanup
Assert-PrintersPreserved
Assert-NoSuccess
Assert-Cleanup ($script:jobRemovals.Count -eq 2) 'A failed job cancellation prevented other selected jobs from being processed.'
Assert-Cleanup (@($script:logs | Where-Object Level -eq 'WARN').Count -eq 1) 'Partial cleanup was not reported.'
$checks++

Reset-CleanupFixture
$script:pending=$true
Invoke-Cleanup
Assert-PrintersPreserved
Assert-NoSuccess
Assert-Cleanup (@($script:logs | Where-Object Level -eq 'WARN').Count -eq 1) 'Pending cancellation was reported as successful.'
$checks++

foreach($answer in @('', 'wrong printer', $script:selectedName.ToLowerInvariant())){
    Reset-CleanupFixture
    $script:answers=@('1',$answer)
    Invoke-RemoveInstalledPrinter
    Assert-NoMutations
    $checks++
}

Reset-CleanupFixture
$script:answers=@('1',$script:selectedName)
Invoke-RemoveInstalledPrinter
Assert-Cleanup ($script:printerRemovals.Count -eq 1 -and $script:printerRemovals[0] -ceq $script:selectedName) 'Explicit removal targeted the wrong installed printer.'
Assert-Cleanup ($script:printers.Count -eq 1 -and $script:printers[0].Name -eq $script:otherName) 'Explicit removal affected another printer.'
Assert-Cleanup ($script:jobRemovals.Count -eq 0) 'Printer removal unexpectedly called job cleanup.'
Assert-Cleanup (@($script:logs | Where-Object Level -eq 'OK').Count -eq 1) 'Explicit printer removal was not verified.'
$checks++

foreach($failure in @('pendingRemoval','failPrinterRemoval')){
    Reset-CleanupFixture
    $script:answers=@('1',$script:selectedName)
    Set-Variable -Name $failure -Value $true -Scope Script
    Invoke-RemoveInstalledPrinter
    Assert-NoSuccess
    Assert-Cleanup (@($script:logs | Where-Object {$_.Level -in @('WARN','ERROR')}).Count -ge 1) 'Unverified printer removal was not reported.'
    $checks++
}

Write-Host "PASS: $checks mocked cleanup/removal scenarios; printer settings, other printers, unselected jobs, and new arrivals are preserved."
return $checks
