param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CliArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ScudoVersion = '0.2.0'
$script:ScudoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

. (Join-Path -Path $script:ScudoRoot -ChildPath 'modules/control-actions.ps1')
. (Join-Path -Path $script:ScudoRoot -ChildPath 'modules/safety.ps1')
. (Join-Path -Path $script:ScudoRoot -ChildPath 'modules/control-catalog.ps1')
. (Join-Path -Path $script:ScudoRoot -ChildPath 'modules/reporting.ps1')

function Write-ScudoText {
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )

    if (Test-ScudoWindows) {
        Write-Host $Text -ForegroundColor $Color
    }
    else {
        Write-Host $Text
    }
}

function Write-ScudoBanner {
    Clear-Host
    Write-ScudoText 'scudo' Green
    Write-ScudoText 'Windows 11 hardening menu' DarkGray
    Write-ScudoText ''
}

function Get-ScudoParsedArguments {
    param(
        [string[]]$Arguments
    )

    $parsed = [ordered]@{
        Help      = $false
        Version   = $false
        CheckAll  = $false
        Export    = $false
        Action    = $null
        ControlId = $null
        NoPause   = $false
    }

    for ($index = 0; $index -lt $Arguments.Count; $index += 1) {
        switch ($Arguments[$index]) {
            '--help' {
                $parsed.Help = $true
            }
            '--version' {
                $parsed.Version = $true
            }
            '--check-all' {
                $parsed.CheckAll = $true
            }
            '--export' {
                $parsed.Export = $true
            }
            '--action' {
                $index += 1
                $parsed.Action = $Arguments[$index]
            }
            '--control-id' {
                $index += 1
                $parsed.ControlId = $Arguments[$index]
            }
            '--no-pause' {
                $parsed.NoPause = $true
            }
        }
    }

    return [pscustomobject]$parsed
}

function Get-ScudoStatusBadge {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Status
    )

    switch ($Status.State) {
        'already-configured' { return '[ok]' }
        'needs-action' { return '[todo]' }
        'pending-reboot' { return '[reboot]' }
        'advisory' { return '[info]' }
        'unsupported' { return '[skip]' }
        'error' { return '[err]' }
        default { return '[?]' }
    }
}

function Get-ScudoStatusColor {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Status
    )

    switch ($Status.State) {
        'already-configured' { return [ConsoleColor]::Green }
        'needs-action' { return [ConsoleColor]::Yellow }
        'pending-reboot' { return [ConsoleColor]::Yellow }
        'advisory' { return [ConsoleColor]::Cyan }
        'unsupported' { return [ConsoleColor]::DarkGray }
        'error' { return [ConsoleColor]::Red }
        default { return [ConsoleColor]::Gray }
    }
}

function Get-ScudoControlMap {
    $controls = Get-ScudoControlCatalog
    $map = @{}
    foreach ($control in $controls) {
        $map[$control.Id] = $control
    }

    return $map
}

function Get-ScudoStatusMap {
    $statusMap = @{}
    foreach ($control in Get-ScudoControlCatalog) {
        $statusMap[$control.Id] = Invoke-ScudoControlDetection -Control $control
    }

    return $statusMap
}

function Get-ScudoReportEntries {
    $controls = Get-ScudoControlCatalog
    $statusMap = Get-ScudoStatusMap

    return foreach ($control in $controls) {
        [pscustomobject]@{
            id             = $control.Id
            title          = $control.Title
            category       = $control.Category
            kind           = $control.Kind
            requiresAdmin  = $control.RequiresAdmin
            requiresReboot = $control.RequiresReboot
            rollbackSupported = (Test-ScudoControlRollbackSupported -Control $control)
            guidance       = $control.Guidance
            status         = $statusMap[$control.Id]
        }
    }
}

function Show-ScudoMenu {
    param(
        [Parameter(Mandatory)]
        [hashtable]$StatusMap
    )

    Write-ScudoBanner

    $menuControls = Get-ScudoControlCatalog | Where-Object { $null -ne $_.MenuNumber } | Sort-Object MenuNumber

    Write-ScudoText '[1] Check all controls' Green

    foreach ($control in $menuControls) {
        $status = $StatusMap[$control.Id]
        $line = ('[{0}] {1} {2}' -f $control.MenuNumber, (Get-ScudoStatusBadge -Status $status), $control.Title)
        Write-ScudoText $line (Get-ScudoStatusColor -Status $status)
    }

    Write-ScudoText '[13] Check firmware and boot items' Cyan
    Write-ScudoText '[14] Install recommended apps' Green
    Write-ScudoText '[15] Show browser and account steps' Cyan
    Write-ScudoText '[16] Export report' Green
    Write-ScudoText '[17] Roll back a saved control state' Yellow
    Write-ScudoText '[0] Exit' Gray
    Write-ScudoText ''

    if (Test-ScudoAdministrator) {
        Write-ScudoText 'Session: elevated' DarkGray
    }
    else {
        Write-ScudoText 'Session: not elevated' DarkGray
    }
}

function Pause-Scudo {
    param(
        [bool]$SkipPause = $false
    )

    if (-not $SkipPause) {
        [void](Read-Host 'Press Enter to continue')
    }
}

function Confirm-ScudoSelection {
    param(
        [Parameter(Mandatory)]
        [string]$Prompt
    )

    $choice = Read-Host "$Prompt [Y/N]"
    return $choice -match '^(?i)y(es)?$'
}

function Show-ScudoControlPreview {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Control,

        [Parameter(Mandatory)]
        [pscustomobject]$Status
    )

    Write-ScudoBanner
    Write-ScudoText $Control.Title Green
    Write-ScudoText ''
    Write-ScudoText "Current state: $($Status.State)" (Get-ScudoStatusColor -Status $Status)
    Write-ScudoText "Summary: $($Status.Summary)" Gray
    Write-ScudoText "Action: $($Control.Guidance)" Gray
    Write-ScudoText "Requires admin: $($Control.RequiresAdmin)" Gray
    Write-ScudoText "Requires reboot: $($Control.RequiresReboot)" Gray

    if ($Status.Notes.Count -gt 0) {
        Write-ScudoText ''
        foreach ($note in $Status.Notes) {
            Write-ScudoText "Note: $note" DarkGray
        }
    }

    Write-ScudoText ''
}

function Start-ScudoElevatedAction {
    param(
        [Parameter(Mandatory)]
        [string]$ControlId,

        [Parameter(Mandatory)]
        [ValidateSet('apply', 'rollback')]
        [string]$Action
    )

    if (-not (Test-ScudoWindows)) {
        Write-ScudoText 'Elevation relaunch is only available on Windows.' Red
        return
    }

    $scriptPath = Join-Path -Path $script:ScudoRoot -ChildPath 'scudo.ps1'
    $argumentString = '-NoProfile -ExecutionPolicy Bypass -File "{0}" --action {1} --control-id {2}' -f $scriptPath, $Action, $ControlId
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argumentString | Out-Null
}

function Invoke-ScudoApplySelection {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Control,

        [Parameter(Mandatory)]
        [pscustomobject]$Status
    )

    Show-ScudoControlPreview -Control $Control -Status $Status

    if (-not (Test-ScudoAdministrator)) {
        Write-ScudoText 'This action needs administrator rights.' Yellow
        if (Confirm-ScudoSelection -Prompt 'Relaunch elevated now?') {
            Start-ScudoElevatedAction -ControlId $Control.Id -Action 'apply'
        }

        return
    }

    $preflight = Get-ScudoPreflightStatus -Control $Control -Action 'apply'
    if ($preflight.Blocked) {
        Write-ScudoText $preflight.Summary Red
        foreach ($note in $preflight.Notes) {
            Write-ScudoText "Note: $note" DarkGray
        }
        return
    }

    if (-not (Confirm-ScudoSelection -Prompt 'Apply this control now?')) {
        return
    }

    $result = Invoke-ScudoControlApply -Control $Control
    Save-ScudoOperationState -Control $Control -Action 'apply' -BeforeStatus $Status -ResultStatus $result | Out-Null
    Write-ScudoText ''
    Write-ScudoText $result.Summary (Get-ScudoStatusColor -Status $result)

    if ($result.RequiresReboot) {
        Write-ScudoText 'A restart is required for this change to take full effect.' Yellow
    }
}

function Get-ScudoRollbackControls {
    return @(
        Get-ScudoControlCatalog |
            Where-Object { Test-ScudoControlRollbackSupported -Control $_ } |
            Sort-Object Title
    )
}

function Invoke-ScudoRollbackSelection {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Control,

        [Parameter(Mandatory)]
        [pscustomobject]$Snapshot
    )

    $currentStatus = Invoke-ScudoControlDetection -Control $Control
    Show-ScudoControlPreview -Control $Control -Status $currentStatus
    Write-ScudoText "Saved state captured: $($Snapshot.savedAt)" Gray
    Write-ScudoText "Saved action result: $($Snapshot.resultStatus.Summary)" Gray
    Write-ScudoText ''

    if (-not (Test-ScudoAdministrator)) {
        Write-ScudoText 'This action needs administrator rights.' Yellow
        if (Confirm-ScudoSelection -Prompt 'Relaunch elevated now?') {
            Start-ScudoElevatedAction -ControlId $Control.Id -Action 'rollback'
        }

        return
    }

    $preflight = Get-ScudoPreflightStatus -Control $Control -Action 'rollback'
    if ($preflight.Blocked) {
        Write-ScudoText $preflight.Summary Red
        foreach ($note in $preflight.Notes) {
            Write-ScudoText "Note: $note" DarkGray
        }
        return
    }

    if (-not (Confirm-ScudoSelection -Prompt 'Restore the saved state now?')) {
        return
    }

    $result = Invoke-ScudoControlRollback -Control $Control -Snapshot $Snapshot
    Save-ScudoOperationState -Control $Control -Action 'rollback' -BeforeStatus $currentStatus -ResultStatus $result | Out-Null
    Write-ScudoText ''
    Write-ScudoText $result.Summary (Get-ScudoStatusColor -Status $result)

    if ($result.RequiresReboot) {
        Write-ScudoText 'A restart is required for this change to take full effect.' Yellow
    }
}

function Show-ScudoRollbackPage {
    $rollbackControls = Get-ScudoRollbackControls

    do {
        Write-ScudoBanner
        Write-ScudoText 'Saved control rollback' Yellow
        Write-ScudoText ''

        $controlsWithSnapshots = @()
        foreach ($control in $rollbackControls) {
            $snapshot = Get-ScudoControlSnapshot -ControlId $control.Id
            if ($null -eq $snapshot) {
                continue
            }

            $controlsWithSnapshots += [pscustomobject]@{
                Control  = $control
                Snapshot = $snapshot
            }
        }

        if ($controlsWithSnapshots.Count -eq 0) {
            Write-ScudoText 'No saved Scudo control states are available for rollback yet.' DarkGray
            Write-ScudoText ''
            Pause-Scudo
            return
        }

        for ($index = 0; $index -lt $controlsWithSnapshots.Count; $index += 1) {
            $item = $controlsWithSnapshots[$index]
            Write-ScudoText ('[{0}] [ok] {1}' -f ($index + 1), $item.Control.Title) Yellow
            Write-ScudoText ('    saved: {0}' -f $item.Snapshot.savedAt) DarkGray
        }

        Write-ScudoText '[0] Back' Gray
        Write-ScudoText ''

        $selection = Read-Host 'Select an option'
        if ($selection -eq '0') {
            return
        }

        $selectedIndex = 0
        if (-not [int]::TryParse($selection, [ref]$selectedIndex)) {
            Write-ScudoText 'Invalid selection.' Red
            Pause-Scudo
            continue
        }

        if ($selectedIndex -lt 1 -or $selectedIndex -gt $controlsWithSnapshots.Count) {
            Write-ScudoText 'Invalid selection.' Red
            Pause-Scudo
            continue
        }

        $selectedItem = $controlsWithSnapshots[$selectedIndex - 1]
        Invoke-ScudoRollbackSelection -Control $selectedItem.Control -Snapshot $selectedItem.Snapshot
        Pause-Scudo
    } while ($true)
}

function Show-ScudoFirmwarePage {
    $firmwareControls = Get-ScudoControlCatalog | Where-Object { $_.Category -eq 'Firmware' }

    do {
        Write-ScudoBanner
        Write-ScudoText 'Firmware and boot items' Cyan
        Write-ScudoText ''

        $infoControls = @($firmwareControls | Where-Object { $_.Id -in @('secure-boot', 'kernel-dma-protection', 'bios-password') })
        foreach ($control in $infoControls) {
            $status = Invoke-ScudoControlDetection -Control $control
            Write-ScudoText "$($control.Title): $($status.Summary)" (Get-ScudoStatusColor -Status $status)
            foreach ($note in $status.Notes) {
                Write-ScudoText "  - $note" DarkGray
            }
        }

        Write-ScudoText ''
        Write-ScudoText '[1] Reboot to firmware settings' Green
        Write-ScudoText '[0] Back' Gray
        Write-ScudoText ''

        $selection = Read-Host 'Select an option'
        if ($selection -eq '0') {
            return
        }

        if ($selection -eq '1') {
            $control = Get-ScudoControlCatalog | Where-Object { $_.Id -eq 'firmware.reboot-to-uefi' }
            $status = Invoke-ScudoControlDetection -Control $control
            Invoke-ScudoApplySelection -Control $control -Status $status
            Pause-Scudo
            return
        }

        Write-ScudoText 'Invalid selection.' Red
        Pause-Scudo
    } while ($true)
}

function Show-ScudoGuidancePage {
    $guidanceControls = Get-ScudoControlCatalog | Where-Object { $_.Kind -eq 'manual-only' -and $_.Category -ne 'Firmware' }

    Write-ScudoBanner
    Write-ScudoText 'Remaining manual guidance' Cyan
    Write-ScudoText ''

    foreach ($control in $guidanceControls) {
        $status = Invoke-ScudoControlDetection -Control $control
        Write-ScudoText "$($control.Title): $($status.Summary)" Cyan
    }

    Write-ScudoText ''
    Pause-Scudo
}

function Show-ScudoPrivacyIdentityPage {
    do {
        $telemetryPolicyControl = Get-ScudoControlCatalog | Where-Object { $_.Id -eq 'privacy.telemetry-policy' }
        $telemetryServicesControl = Get-ScudoControlCatalog | Where-Object { $_.Id -eq 'privacy.telemetry-services' }
        $standardUserControl = Get-ScudoControlCatalog | Where-Object { $_.Id -eq 'account.create-standard-user' }

        $telemetryPolicyStatus = Invoke-ScudoControlDetection -Control $telemetryPolicyControl
        $telemetryServicesStatus = Invoke-ScudoControlDetection -Control $telemetryServicesControl
        $standardUserStatus = Invoke-ScudoControlDetection -Control $standardUserControl

        Write-ScudoBanner
        Write-ScudoText 'Privacy and account tools' Green
        Write-ScudoText ''
        Write-ScudoText "[1] $(Get-ScudoStatusBadge -Status $telemetryPolicyStatus) Reduce telemetry policy" (Get-ScudoStatusColor -Status $telemetryPolicyStatus)
        Write-ScudoText "[2] $(Get-ScudoStatusBadge -Status $telemetryServicesStatus) Disable telemetry services" (Get-ScudoStatusColor -Status $telemetryServicesStatus)
        Write-ScudoText "[3] $(Get-ScudoStatusBadge -Status $standardUserStatus) Create standard local user" Cyan
        Write-ScudoText '[4] Show remaining manual identity guidance' Cyan
        Write-ScudoText '[0] Back' Gray
        Write-ScudoText ''

        $selection = Read-Host 'Select an option'
        switch ($selection) {
            '1' {
                Invoke-ScudoApplySelection -Control $telemetryPolicyControl -Status $telemetryPolicyStatus
                Pause-Scudo
            }
            '2' {
                Invoke-ScudoApplySelection -Control $telemetryServicesControl -Status $telemetryServicesStatus
                Pause-Scudo
            }
            '3' {
                Write-ScudoBanner
                if (-not (Test-ScudoAdministrator)) {
                    Write-ScudoText 'This action needs administrator rights.' Yellow
                    if (Confirm-ScudoSelection -Prompt 'Relaunch elevated now?') {
                        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f (Join-Path -Path $script:ScudoRoot -ChildPath 'scudo.ps1'))
                    }
                    Pause-Scudo
                    continue
                }

                $userName = Read-Host 'Enter the new local username'
                if ([string]::IsNullOrWhiteSpace($userName)) {
                    Write-ScudoText 'Username is required.' Red
                    Pause-Scudo
                    continue
                }

                $password = Read-Host 'Enter the password for the new account' -AsSecureString
                $result = New-ScudoStandardUser -UserName $userName -Password $password
                Write-ScudoText $result.Summary (Get-ScudoStatusColor -Status $result)
                Pause-Scudo
            }
            '4' {
                Write-ScudoBanner
                $manualIdentityControls = Get-ScudoControlCatalog | Where-Object { $_.Kind -eq 'manual-only' -and $_.Category -eq 'Identity' }
                foreach ($control in $manualIdentityControls) {
                    $status = Invoke-ScudoControlDetection -Control $control
                    Write-ScudoText "$($control.Title): $($status.Summary)" Cyan
                }
                Pause-Scudo
            }
            '0' {
                return
            }
            default {
                Write-ScudoText 'Invalid selection.' Red
                Pause-Scudo
            }
        }
    } while ($true)
}

function Show-ScudoInstallAppsPage {
    $appControls = Get-ScudoControlCatalog | Where-Object { $_.Category -eq 'Apps' } | Sort-Object Title

    do {
        Write-ScudoBanner
        Write-ScudoText 'Install recommended apps' Green
        Write-ScudoText ''

        for ($index = 0; $index -lt $appControls.Count; $index += 1) {
            $control = $appControls[$index]
            $status = Invoke-ScudoControlDetection -Control $control
            $line = ('[{0}] {1} {2}' -f ($index + 1), (Get-ScudoStatusBadge -Status $status), $control.Title)
            Write-ScudoText $line (Get-ScudoStatusColor -Status $status)
        }

        Write-ScudoText '[0] Back' Gray
        Write-ScudoText ''

        $selection = Read-Host 'Select an app'
        if ($selection -eq '0') {
            return
        }

        $selectedIndex = 0
        if (-not [int]::TryParse($selection, [ref]$selectedIndex)) {
            Write-ScudoText 'Invalid selection.' Red
            Pause-Scudo
            continue
        }

        if ($selectedIndex -lt 1 -or $selectedIndex -gt $appControls.Count) {
            Write-ScudoText 'Invalid selection.' Red
            Pause-Scudo
            continue
        }

        $control = $appControls[$selectedIndex - 1]
        $status = Invoke-ScudoControlDetection -Control $control
        Invoke-ScudoApplySelection -Control $control -Status $status
        Pause-Scudo
    } while ($true)
}

function Show-ScudoBrowserToolsPage {
    do {
        $firefoxNoScriptControl = Get-ScudoControlCatalog | Where-Object { $_.Id -eq 'browser.firefox-noscript' }
        $firefoxSanitizeControl = Get-ScudoControlCatalog | Where-Object { $_.Id -eq 'browser.firefox-sanitize' }
        $noScriptStatus = Invoke-ScudoControlDetection -Control $firefoxNoScriptControl
        $sanitizeStatus = Invoke-ScudoControlDetection -Control $firefoxSanitizeControl

        Write-ScudoBanner
        Write-ScudoText 'Browser tools' Green
        Write-ScudoText ''
        Write-ScudoText "[1] $(Get-ScudoStatusBadge -Status $noScriptStatus) Apply Firefox NoScript policy" (Get-ScudoStatusColor -Status $noScriptStatus)
        Write-ScudoText "[2] $(Get-ScudoStatusBadge -Status $sanitizeStatus) Apply Firefox shutdown sanitization" (Get-ScudoStatusColor -Status $sanitizeStatus)
        Write-ScudoText '[3] Show remaining manual browser guidance' Cyan
        Write-ScudoText '[0] Back' Gray
        Write-ScudoText ''

        $selection = Read-Host 'Select an option'
        switch ($selection) {
            '1' {
                Invoke-ScudoApplySelection -Control $firefoxNoScriptControl -Status $noScriptStatus
                Pause-Scudo
            }
            '2' {
                Invoke-ScudoApplySelection -Control $firefoxSanitizeControl -Status $sanitizeStatus
                Pause-Scudo
            }
            '3' {
                Write-ScudoBanner
                $manualBrowserControls = Get-ScudoControlCatalog | Where-Object { $_.Kind -eq 'manual-only' -and $_.Category -eq 'Browser' }
                foreach ($control in $manualBrowserControls) {
                    $status = Invoke-ScudoControlDetection -Control $control
                    Write-ScudoText "$($control.Title): $($status.Summary)" Cyan
                }
                Pause-Scudo
            }
            '0' {
                return
            }
            default {
                Write-ScudoText 'Invalid selection.' Red
                Pause-Scudo
            }
        }
    } while ($true)
}

function Invoke-ScudoCheckAll {
    Write-ScudoBanner
    Write-ScudoText 'Checking all controls...' Cyan
    Write-ScudoText ''

    $controls = Get-ScudoControlCatalog
    foreach ($control in $controls) {
        $status = Invoke-ScudoControlDetection -Control $control
        $label = '{0} {1}' -f (Get-ScudoStatusBadge -Status $status), $control.Title
        Write-ScudoText $label (Get-ScudoStatusColor -Status $status)
    }

    Write-ScudoText ''
}

function Invoke-ScudoExport {
    $reportPaths = Export-ScudoReport -Results (Get-ScudoReportEntries)
    Write-ScudoText "Markdown: $($reportPaths.MarkdownPath)" Green
    Write-ScudoText "JSON: $($reportPaths.JsonPath)" Green
}

function Show-ScudoHelp {
    Write-ScudoText 'scudo usage' Green
    Write-ScudoText ''
    Write-ScudoText 'scudo' Gray
    Write-ScudoText 'scudo --check-all' Gray
    Write-ScudoText 'scudo --export' Gray
    Write-ScudoText 'scudo --action apply --control-id <id>' Gray
    Write-ScudoText 'scudo --action rollback --control-id <id>' Gray
    Write-ScudoText 'scudo --version' Gray
    Write-ScudoText 'scudo --help' Gray
}

function Invoke-ScudoDirectApply {
    param(
        [Parameter(Mandatory)]
        [string]$ControlId,

        [bool]$SkipPause = $false
    )

    $controlMap = Get-ScudoControlMap
    $control = $controlMap[$ControlId]
    if ($null -eq $control) {
        Write-ScudoText "Unknown control: $ControlId" Red
        return 1
    }

    $status = Invoke-ScudoControlDetection -Control $control
    $preflight = Get-ScudoPreflightStatus -Control $control -Action 'apply'
    Show-ScudoControlPreview -Control $control -Status $status
    if ($preflight.Blocked) {
        Write-ScudoText $preflight.Summary Red
        foreach ($note in $preflight.Notes) {
            Write-ScudoText "Note: $note" DarkGray
        }
        Pause-Scudo -SkipPause $SkipPause
        return 1
    }

    $result = Invoke-ScudoControlApply -Control $control
    Save-ScudoOperationState -Control $control -Action 'apply' -BeforeStatus $status -ResultStatus $result | Out-Null
    Write-ScudoText $result.Summary (Get-ScudoStatusColor -Status $result)
    Pause-Scudo -SkipPause $SkipPause

    if ($result.State -eq 'pending-reboot') {
        return 2
    }

    if ($result.State -eq 'error') {
        return 1
    }

    return 0
}

function Invoke-ScudoDirectRollback {
    param(
        [Parameter(Mandatory)]
        [string]$ControlId,

        [bool]$SkipPause = $false
    )

    $controlMap = Get-ScudoControlMap
    $control = $controlMap[$ControlId]
    if ($null -eq $control) {
        Write-ScudoText "Unknown control: $ControlId" Red
        return 1
    }

    $snapshot = Get-ScudoControlSnapshot -ControlId $ControlId
    if ($null -eq $snapshot) {
        Write-ScudoText "No saved Scudo state exists for: $ControlId" Red
        return 1
    }

    $status = Invoke-ScudoControlDetection -Control $control
    $preflight = Get-ScudoPreflightStatus -Control $control -Action 'rollback'
    Show-ScudoControlPreview -Control $control -Status $status
    if ($preflight.Blocked) {
        Write-ScudoText $preflight.Summary Red
        foreach ($note in $preflight.Notes) {
            Write-ScudoText "Note: $note" DarkGray
        }
        Pause-Scudo -SkipPause $SkipPause
        return 1
    }

    $result = Invoke-ScudoControlRollback -Control $control -Snapshot $snapshot
    Save-ScudoOperationState -Control $control -Action 'rollback' -BeforeStatus $status -ResultStatus $result | Out-Null
    Write-ScudoText $result.Summary (Get-ScudoStatusColor -Status $result)
    Pause-Scudo -SkipPause $SkipPause

    if ($result.State -eq 'pending-reboot') {
        return 2
    }

    if ($result.State -eq 'error') {
        return 1
    }

    return 0
}

function Start-ScudoMenu {
    do {
        $statusMap = Get-ScudoStatusMap
        Show-ScudoMenu -StatusMap $statusMap
        $selection = Read-Host 'Select an option'

        switch ($selection) {
            '1' {
                Invoke-ScudoCheckAll
                Pause-Scudo
            }
            '13' {
                Show-ScudoFirmwarePage
            }
            '14' {
                Show-ScudoInstallAppsPage
            }
            '15' {
                do {
                    Write-ScudoBanner
                    Write-ScudoText 'Browser and account steps' Cyan
                    Write-ScudoText ''
                    Write-ScudoText '[1] Browser tools' Green
                    Write-ScudoText '[2] Privacy and account tools' Green
                    Write-ScudoText '[3] Show remaining manual guidance' Cyan
                    Write-ScudoText '[0] Back' Gray
                    Write-ScudoText ''

                    $subSelection = Read-Host 'Select an option'
                    switch ($subSelection) {
                        '1' { Show-ScudoBrowserToolsPage }
                        '2' { Show-ScudoPrivacyIdentityPage }
                        '3' { Show-ScudoGuidancePage }
                        '0' { break }
                        default {
                            Write-ScudoText 'Invalid selection.' Red
                            Pause-Scudo
                        }
                    }
                } while ($subSelection -ne '0')
            }
            '16' {
                Write-ScudoBanner
                Invoke-ScudoExport
                Pause-Scudo
            }
            '17' {
                Show-ScudoRollbackPage
            }
            '0' {
                return
            }
            default {
                $control = Get-ScudoControlCatalog | Where-Object { "$($_.MenuNumber)" -eq $selection }
                if ($null -eq $control) {
                    Write-ScudoText 'Invalid selection.' Red
                    Pause-Scudo
                }
                else {
                    Invoke-ScudoApplySelection -Control $control -Status $statusMap[$control.Id]
                    Pause-Scudo
                }
            }
        }
    } while ($true)
}

$parsedArguments = Get-ScudoParsedArguments -Arguments $CliArgs

if ($parsedArguments.Help) {
    Show-ScudoHelp
    exit 0
}

if ($parsedArguments.Version) {
    Write-Output $script:ScudoVersion
    exit 0
}

if (-not (Test-ScudoWindows)) {
    Write-ScudoText 'scudo only runs on Windows 11.' Red
    exit 1
}

if (-not (Test-ScudoWindows11)) {
    Write-ScudoText 'scudo only supports Windows 11.' Red
    exit 1
}

Start-ScudoTranscript | Out-Null

$exitCode = 0

try {
    if ($parsedArguments.Action -eq 'apply' -and -not [string]::IsNullOrWhiteSpace($parsedArguments.ControlId)) {
        $exitCode = Invoke-ScudoDirectApply -ControlId $parsedArguments.ControlId -SkipPause $parsedArguments.NoPause
    }
    elseif ($parsedArguments.Action -eq 'rollback' -and -not [string]::IsNullOrWhiteSpace($parsedArguments.ControlId)) {
        $exitCode = Invoke-ScudoDirectRollback -ControlId $parsedArguments.ControlId -SkipPause $parsedArguments.NoPause
    }
    elseif ($parsedArguments.CheckAll) {
        Invoke-ScudoCheckAll
    }
    elseif ($parsedArguments.Export) {
        Invoke-ScudoExport
    }
    else {
        Start-ScudoMenu
    }
}
finally {
    Stop-ScudoTranscript
}

exit $exitCode
