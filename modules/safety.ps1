Set-StrictMode -Version Latest

$script:ScudoTranscriptPath = $null
$script:ScudoTranscriptStarted = $false

function Get-ScudoDataDirectory {
    param(
        [string]$BaseDirectory
    )

    if (-not [string]::IsNullOrWhiteSpace($BaseDirectory)) {
        return $BaseDirectory
    }

    $root = if (Test-ScudoWindows) {
        Join-Path -Path $env:USERPROFILE -ChildPath 'Documents'
    }
    else {
        $PWD.Path
    }

    return Join-Path -Path $root -ChildPath 'Scudo'
}

function Get-ScudoLogDirectory {
    param(
        [string]$BaseDirectory
    )

    return Join-Path -Path (Get-ScudoDataDirectory -BaseDirectory $BaseDirectory) -ChildPath 'Logs'
}

function Get-ScudoStateDirectory {
    param(
        [string]$BaseDirectory
    )

    return Join-Path -Path (Get-ScudoDataDirectory -BaseDirectory $BaseDirectory) -ChildPath 'State'
}

function Get-ScudoOperationsDirectory {
    param(
        [string]$BaseDirectory
    )

    return Join-Path -Path (Get-ScudoStateDirectory -BaseDirectory $BaseDirectory) -ChildPath 'Operations'
}

function Get-ScudoLatestStateDirectory {
    param(
        [string]$BaseDirectory
    )

    return Join-Path -Path (Get-ScudoStateDirectory -BaseDirectory $BaseDirectory) -ChildPath 'Latest'
}

function Get-ScudoSafeFileName {
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    $safeValue = $Value.ToLowerInvariant() -replace '[^a-z0-9\-]+', '-'
    $safeValue = $safeValue.Trim('-')

    if ([string]::IsNullOrWhiteSpace($safeValue)) {
        return 'item'
    }

    return $safeValue
}

function Start-ScudoTranscript {
    param(
        [string]$BaseDirectory
    )

    if (-not (Test-ScudoWindows)) {
        return $null
    }

    if (-not (Test-ScudoCommandAvailable -Name 'Start-Transcript')) {
        return $null
    }

    if (-not [string]::IsNullOrWhiteSpace($script:ScudoTranscriptPath)) {
        return $script:ScudoTranscriptPath
    }

    $logDirectory = Get-ScudoLogDirectory -BaseDirectory $BaseDirectory
    New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $transcriptPath = Join-Path -Path $logDirectory -ChildPath "scudo-$stamp-$PID.log"

    try {
        Start-Transcript -Path $transcriptPath -Append -ErrorAction Stop | Out-Null
        $script:ScudoTranscriptPath = $transcriptPath
        $script:ScudoTranscriptStarted = $true
        return $transcriptPath
    }
    catch {
        $script:ScudoTranscriptPath = $null
        $script:ScudoTranscriptStarted = $false
        return $null
    }
}

function Stop-ScudoTranscript {
    if (-not $script:ScudoTranscriptStarted) {
        return
    }

    try {
        Stop-Transcript | Out-Null
    }
    catch {
    }
    finally {
        $script:ScudoTranscriptStarted = $false
    }
}

function Get-ScudoTranscriptPath {
    return $script:ScudoTranscriptPath
}

function Test-ScudoPendingReboot {
    if (-not (Test-ScudoWindows)) {
        return $false
    }

    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootInProgress',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\PackagesPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\PostRebootReporting',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )

    foreach ($path in $paths) {
        if (Test-Path -Path $path) {
            return $true
        }
    }

    return $false
}

function Get-ScudoPreflightStatus {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Control,

        [ValidateSet('apply', 'rollback')]
        [string]$Action = 'apply'
    )

    $notes = @()

    if (-not (Test-ScudoWindows)) {
        return [pscustomobject]@{
            Blocked = $true
            Summary = 'Scudo safety checks only support Windows.'
            Notes   = $notes
        }
    }

    if (Test-ScudoPendingReboot) {
        $notes += 'A pending reboot was detected. Restart Windows before making more hardening changes or rollbacks.'
        return [pscustomobject]@{
            Blocked = $true
            Summary = 'Pending reboot detected.'
            Notes   = $notes
        }
    }

    if ($Action -in @('apply', 'rollback') -and -not (Test-ScudoAdministrator)) {
        $notes += 'Administrator rights are required for this action.'
        return [pscustomobject]@{
            Blocked = $true
            Summary = 'Administrator rights are required.'
            Notes   = $notes
        }
    }

    return [pscustomobject]@{
        Blocked = $false
        Summary = 'Preflight checks passed.'
        Notes   = $notes
    }
}

function Test-ScudoControlRollbackSupported {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Control
    )

    return $null -ne $Control.PSObject.Properties['RollbackFunction'] -and $null -ne $Control.RollbackFunction
}

function Get-ScudoControlSnapshotPath {
    param(
        [Parameter(Mandatory)]
        [string]$ControlId,

        [string]$BaseDirectory
    )

    $latestDirectory = Get-ScudoLatestStateDirectory -BaseDirectory $BaseDirectory
    New-Item -Path $latestDirectory -ItemType Directory -Force | Out-Null

    $fileName = '{0}.json' -f (Get-ScudoSafeFileName -Value $ControlId)
    return Join-Path -Path $latestDirectory -ChildPath $fileName
}

function Get-ScudoControlSnapshot {
    param(
        [Parameter(Mandatory)]
        [string]$ControlId,

        [string]$BaseDirectory
    )

    $snapshotPath = Get-ScudoControlSnapshotPath -ControlId $ControlId -BaseDirectory $BaseDirectory
    if (-not (Test-Path -Path $snapshotPath)) {
        return $null
    }

    try {
        return Get-Content -Path $snapshotPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        return $null
    }
}

function Save-ScudoOperationState {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Control,

        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [pscustomobject]$BeforeStatus,

        [Parameter(Mandatory)]
        [pscustomobject]$ResultStatus,

        [string]$BaseDirectory
    )

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $safeControlId = Get-ScudoSafeFileName -Value $Control.Id
    $operationsDirectory = Get-ScudoOperationsDirectory -BaseDirectory $BaseDirectory
    New-Item -Path $operationsDirectory -ItemType Directory -Force | Out-Null

    $payload = [pscustomobject]@{
        formatVersion     = 1
        savedAt           = (Get-Date).ToString('o')
        action            = $Action
        controlId         = $Control.Id
        title             = $Control.Title
        rollbackSupported = (Test-ScudoControlRollbackSupported -Control $Control)
        transcriptPath    = Get-ScudoTranscriptPath
        beforeStatus      = $BeforeStatus
        resultStatus      = $ResultStatus
    }

    $operationPath = Join-Path -Path $operationsDirectory -ChildPath "$stamp-$safeControlId.json"
    $payload | ConvertTo-Json -Depth 10 | Set-Content -Path $operationPath -Encoding UTF8

    if ($payload.rollbackSupported -and $Action -eq 'apply' -and $ResultStatus.State -ne 'error') {
        $latestPath = Get-ScudoControlSnapshotPath -ControlId $Control.Id -BaseDirectory $BaseDirectory
        $payload | ConvertTo-Json -Depth 10 | Set-Content -Path $latestPath -Encoding UTF8
    }

    if ($payload.rollbackSupported -and $Action -eq 'rollback' -and $ResultStatus.State -ne 'error') {
        $latestPath = Get-ScudoControlSnapshotPath -ControlId $Control.Id -BaseDirectory $BaseDirectory
        if (Test-Path -Path $latestPath) {
            Remove-Item -Path $latestPath -Force
        }
    }

    return $operationPath
}
