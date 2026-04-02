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
. (Join-Path -Path $script:ScudoRoot -ChildPath 'modules/entrypoint.ps1')
. (Join-Path -Path $script:ScudoRoot -ChildPath 'modules/gui.ps1')

function Write-ScudoText {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
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
    $map = @{}
    foreach ($control in Get-ScudoControlCatalog) {
        $map[$control.Id] = $control
    }

    return $map
}

function Get-ScudoSortedControls {
    $sectionRankMap = @{}
    foreach ($section in Get-ScudoTranscriptSectionCatalog) {
        $sectionRankMap[$section.Id] = [int]$section.DisplayRank
    }

    return @(
        Get-ScudoControlCatalog |
            Sort-Object `
                @{ Expression = { $sectionRankMap[$_.TranscriptSection] } }, `
                @{ Expression = { [int]$_.SortOrder } }, `
                @{ Expression = { $_.Title } }
    )
}

function Get-ScudoControlsForSection {
    param(
        [Parameter(Mandatory)]
        [string]$SectionId
    )

    return @(
        Get-ScudoSortedControls |
            Where-Object { $_.TranscriptSection -eq $SectionId }
    )
}

function Get-ScudoStatusNotes {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Status
    )

    return @(
        @($Status.Notes) |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}

function Get-ScudoStatusMap {
    $statusMap = @{}
    foreach ($control in Get-ScudoSortedControls) {
        $statusMap[$control.Id] = Invoke-ScudoControlDetection -Control $control
    }

    return $statusMap
}

function Get-ScudoReportEntries {
    $controls = Get-ScudoSortedControls
    $statusMap = Get-ScudoStatusMap

    return @(
        foreach ($control in $controls) {
            [pscustomobject]@{
                id                 = $control.Id
                title              = $control.Title
                category           = $control.Category
                kind               = $control.Kind
                requiresAdmin      = $control.RequiresAdmin
                requiresReboot     = $control.RequiresReboot
                rollbackSupported  = (Test-ScudoControlRollbackSupported -Control $control)
                guidance           = $control.Guidance
                whatItDoes         = $control.WhatItDoes
                whyApply           = $control.WhyApply
                whyNotApply        = $control.WhyNotApply
                recommendationTier = $control.RecommendationTier
                automationLevel    = $control.AutomationLevel
                transcriptSection  = $control.TranscriptSection
                rollbackNote       = $control.RollbackNote
                status             = $statusMap[$control.Id]
            }
        }
    )
}

function Get-ScudoRecommendationLabel {
    param(
        [Parameter(Mandatory)]
        [string]$Tier
    )

    switch ($Tier) {
        'baseline' { return 'baseline' }
        'strict' { return 'strict' }
        'guided' { return 'guided' }
        'optional' { return 'optional' }
        default { return $Tier }
    }
}

function Get-ScudoAutomationLabel {
    param(
        [Parameter(Mandatory)]
        [string]$AutomationLevel
    )

    switch ($AutomationLevel) {
        'automatic' { return 'automatic' }
        'guided' { return 'guided input' }
        'check-only' { return 'check only' }
        'manual' { return 'manual step' }
        default { return $AutomationLevel }
    }
}

function Show-ScudoMenu {
    param(
        [Parameter(Mandatory)]
        [hashtable]$StatusMap
    )

    Write-ScudoBanner

    Write-ScudoText '[1] Review this PC' Green
    Write-ScudoText '[2] Apply baseline hardening' Green
    Write-ScudoText '[3] Apply strict hardening' Yellow
    Write-ScudoText '[4] Guided hardening walkthrough' Cyan
    Write-ScudoText '[5] Browse individual controls' Green
    Write-ScudoText '[6] Optional apps and browser tools' Green
    Write-ScudoText '[7] Roll back a saved change' Yellow
    Write-ScudoText '[8] Export report' Green
    Write-ScudoText '[0] Exit' Gray
    Write-ScudoText ''

    foreach ($preset in @('baseline', 'strict')) {
        $controls = Get-ScudoControlsForPreset -PresetId $preset
        $doneCount = @(
            $controls |
                Where-Object { $StatusMap[$_.Id].State -eq 'already-configured' }
        ).Count
        $totalCount = @($controls).Count
        Write-ScudoText ("{0}: {1}/{2} automatic controls already configured" -f (Get-ScudoRecommendationLabel -Tier $preset), $doneCount, $totalCount) DarkGray
    }

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
    Write-ScudoText ("State: $($Status.Summary)") (Get-ScudoStatusColor -Status $Status)
    Write-ScudoText ("Section: {0}" -f $Control.TranscriptSection) DarkGray
    Write-ScudoText ("Tier: {0}" -f (Get-ScudoRecommendationLabel -Tier $Control.RecommendationTier)) DarkGray
    Write-ScudoText ("Automation: {0}" -f (Get-ScudoAutomationLabel -AutomationLevel $Control.AutomationLevel)) DarkGray
    Write-ScudoText ("Requires admin: {0}" -f $Control.RequiresAdmin) DarkGray
    Write-ScudoText ("Requires reboot: {0}" -f $Control.RequiresReboot) DarkGray
    Write-ScudoText ("Rollback: {0}" -f $Control.RollbackNote) DarkGray
    Write-ScudoText ''
    Write-ScudoText 'What it does' Cyan
    Write-ScudoText $Control.WhatItDoes Gray
    Write-ScudoText ''
    Write-ScudoText 'Why apply it' Cyan
    Write-ScudoText $Control.WhyApply Gray
    Write-ScudoText ''
    Write-ScudoText 'Why skip it' Cyan
    Write-ScudoText $Control.WhyNotApply Gray

    $statusNotes = Get-ScudoStatusNotes -Status $Status
    if (@($statusNotes).Count -gt 0) {
        Write-ScudoText ''
        Write-ScudoText 'Status notes' Cyan
        foreach ($note in $statusNotes) {
            Write-ScudoText "- $note" DarkGray
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

function Start-ScudoElevatedPreset {
    param(
        [Parameter(Mandatory)]
        [string]$PresetId
    )

    if (-not (Test-ScudoWindows)) {
        Write-ScudoText 'Elevation relaunch is only available on Windows.' Red
        return
    }

    $scriptPath = Join-Path -Path $script:ScudoRoot -ChildPath 'scudo.ps1'
    $argumentString = '-NoProfile -ExecutionPolicy Bypass -File "{0}" --preset {1}' -f $scriptPath, $PresetId
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

    if ($Control.Id -eq 'account.create-standard-user') {
        if (-not (Test-ScudoAdministrator)) {
            Write-ScudoText 'This action needs administrator rights.' Yellow
            if (Confirm-ScudoSelection -Prompt 'Relaunch elevated now?') {
                Start-ScudoElevatedAction -ControlId $Control.Id -Action 'apply'
            }

            return
        }

        $userName = Read-Host 'Enter the new local username'
        if ([string]::IsNullOrWhiteSpace($userName)) {
            Write-ScudoText 'Username is required.' Red
            return
        }

        $password = Read-Host 'Enter the password for the new account' -AsSecureString
        $result = New-ScudoStandardUser -UserName $userName -Password $password
        Write-ScudoText ''
        Write-ScudoText $result.Summary (Get-ScudoStatusColor -Status $result)
        return
    }

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

function Show-ScudoPresetPreview {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Preset
    )

    $controls = Get-ScudoControlsForPreset -PresetId $Preset.Id

    Write-ScudoBanner
    Write-ScudoText $Preset.Title Green
    Write-ScudoText ''
    Write-ScudoText $Preset.Summary Gray
    Write-ScudoText ''
    Write-ScudoText ('Automatic controls in this preset: {0}' -f @($controls).Count) DarkGray
    Write-ScudoText ''

    foreach ($control in $controls) {
        Write-ScudoText ('- {0} [{1}]' -f $control.Title, (Get-ScudoRecommendationLabel -Tier $control.RecommendationTier)) Gray
    }

    Write-ScudoText ''
}

function Invoke-ScudoPresetApply {
    param(
        [Parameter(Mandatory)]
        [string]$PresetId,

        [bool]$SkipPause = $false
    )

    $preset = Get-ScudoPreset -PresetId $PresetId
    if ($null -eq $preset) {
        Write-ScudoText "Unknown preset: $PresetId" Red
        return 1
    }

    if ($preset.ApplyMode -ne 'batch') {
        Write-ScudoText "$($preset.Title) is not a batch-apply preset." Red
        return 1
    }

    Show-ScudoPresetPreview -Preset $preset

    if (-not (Test-ScudoAdministrator)) {
        Write-ScudoText 'This preset needs administrator rights.' Yellow
        if (-not $SkipPause -and (Confirm-ScudoSelection -Prompt 'Relaunch elevated now?')) {
            Start-ScudoElevatedPreset -PresetId $PresetId
        }

        Pause-Scudo -SkipPause $SkipPause
        return 1
    }

    if (-not $SkipPause -and -not (Confirm-ScudoSelection -Prompt ("Apply '{0}' now?" -f $preset.Title))) {
        return 0
    }

    $controls = Get-ScudoControlsForPreset -PresetId $PresetId
    $statusMap = Get-ScudoStatusMap
    $hadPendingReboot = $false
    $hadError = $false

    foreach ($control in $controls) {
        $status = $statusMap[$control.Id]
        $label = '{0} {1}' -f (Get-ScudoStatusBadge -Status $status), $control.Title

        if ($status.State -eq 'already-configured') {
            Write-ScudoText "$label - already configured" Green
            continue
        }

        if ($status.State -eq 'unsupported') {
            Write-ScudoText "$label - skipped: $($status.Summary)" DarkGray
            continue
        }

        $preflight = Get-ScudoPreflightStatus -Control $control -Action 'apply'
        if ($preflight.Blocked) {
            Write-ScudoText "$label - blocked: $($preflight.Summary)" Red
            $hadError = $true
            continue
        }

        $result = Invoke-ScudoControlApply -Control $control
        if ($result.State -ne 'error') {
            Save-ScudoOperationState -Control $control -Action 'apply' -BeforeStatus $status -ResultStatus $result | Out-Null
        }

        Write-ScudoText ('{0} - {1}' -f $control.Title, $result.Summary) (Get-ScudoStatusColor -Status $result)
        $hadPendingReboot = $hadPendingReboot -or [bool]$result.RequiresReboot
        $hadError = $hadError -or ($result.State -eq 'error')
    }

    Write-ScudoText ''
    if ($hadPendingReboot) {
        Write-ScudoText 'One or more preset actions need a reboot to fully take effect.' Yellow
    }

    Pause-Scudo -SkipPause $SkipPause

    if ($hadError) {
        return 1
    }

    if ($hadPendingReboot) {
        return 2
    }

    return 0
}

function Show-ScudoControlActionPage {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Control
    )

    do {
        $status = Invoke-ScudoControlDetection -Control $Control
        $snapshot = Get-ScudoControlSnapshot -ControlId $Control.Id
        Show-ScudoControlPreview -Control $Control -Status $status

        $actionLabel = if ($Control.Id -eq 'account.create-standard-user') {
            'Create user'
        }
        elseif ($Control.Kind -eq 'installable') {
            'Install'
        }
        elseif ($Control.Id -eq 'firmware.reboot-to-uefi') {
            'Reboot to firmware'
        }
        else {
            'Apply'
        }

        $optionNumber = 1
        $applyOption = $null
        $rollbackOption = $null

        if ($Control.Kind -in @('applyable', 'installable', 'special')) {
            $applyOption = "$optionNumber"
            Write-ScudoText ("[{0}] {1}" -f $applyOption, $actionLabel) Green
            $optionNumber += 1
        }

        if ((Test-ScudoControlRollbackSupported -Control $Control) -and $null -ne $snapshot) {
            $rollbackOption = "$optionNumber"
            Write-ScudoText ("[{0}] Roll back saved state" -f $rollbackOption) Yellow
            $optionNumber += 1
        }

        Write-ScudoText '[0] Back' Gray
        Write-ScudoText ''

        $selection = Read-Host 'Select an option'
        if ($selection -eq '0') {
            return
        }

        if ($selection -eq $applyOption) {
            Invoke-ScudoApplySelection -Control $Control -Status $status
            Pause-Scudo
            continue
        }

        if ($selection -eq $rollbackOption) {
            Invoke-ScudoRollbackSelection -Control $Control -Snapshot $snapshot
            Pause-Scudo
            continue
        }

        Write-ScudoText 'Invalid selection.' Red
        Pause-Scudo
    } while ($true)
}

function Show-ScudoControlListPage {
    param(
        [Parameter(Mandatory)]
        [string]$Heading,

        [Parameter(Mandatory)]
        [array]$Controls
    )

    do {
        Write-ScudoBanner
        Write-ScudoText $Heading Green
        Write-ScudoText ''

        if (@($Controls).Count -eq 0) {
            Write-ScudoText 'No controls are available in this view.' DarkGray
            Write-ScudoText ''
            Pause-Scudo
            return
        }

        for ($index = 0; $index -lt @($Controls).Count; $index += 1) {
            $control = $Controls[$index]
            $status = Invoke-ScudoControlDetection -Control $control
            Write-ScudoText ('[{0}] {1} {2}' -f ($index + 1), (Get-ScudoStatusBadge -Status $status), $control.Title) (Get-ScudoStatusColor -Status $status)
            Write-ScudoText ('    {0} | {1} | {2}' -f $control.Category, (Get-ScudoRecommendationLabel -Tier $control.RecommendationTier), (Get-ScudoAutomationLabel -AutomationLevel $control.AutomationLevel)) DarkGray
        }

        Write-ScudoText '[0] Back' Gray
        Write-ScudoText ''

        $selection = Read-Host 'Select a control'
        if ($selection -eq '0') {
            return
        }

        $selectedIndex = 0
        if (-not [int]::TryParse($selection, [ref]$selectedIndex)) {
            Write-ScudoText 'Invalid selection.' Red
            Pause-Scudo
            continue
        }

        if ($selectedIndex -lt 1 -or $selectedIndex -gt @($Controls).Count) {
            Write-ScudoText 'Invalid selection.' Red
            Pause-Scudo
            continue
        }

        Show-ScudoControlActionPage -Control $Controls[$selectedIndex - 1]
    } while ($true)
}

function Show-ScudoBrowseControlsPage {
    $categories = @(
        Get-ScudoSortedControls |
            Where-Object { $_.Category -ne 'Apps' } |
            Select-Object -ExpandProperty Category -Unique
    )

    do {
        Write-ScudoBanner
        Write-ScudoText 'Browse individual controls' Green
        Write-ScudoText ''

        for ($index = 0; $index -lt @($categories).Count; $index += 1) {
            Write-ScudoText ('[{0}] {1}' -f ($index + 1), $categories[$index]) Gray
        }

        Write-ScudoText '[0] Back' Gray
        Write-ScudoText ''

        $selection = Read-Host 'Select a category'
        if ($selection -eq '0') {
            return
        }

        $selectedIndex = 0
        if (-not [int]::TryParse($selection, [ref]$selectedIndex)) {
            Write-ScudoText 'Invalid selection.' Red
            Pause-Scudo
            continue
        }

        if ($selectedIndex -lt 1 -or $selectedIndex -gt @($categories).Count) {
            Write-ScudoText 'Invalid selection.' Red
            Pause-Scudo
            continue
        }

        $category = $categories[$selectedIndex - 1]
        $controls = @(
            Get-ScudoSortedControls |
                Where-Object { $_.Category -eq $category }
        )
        Show-ScudoControlListPage -Heading $category -Controls $controls
    } while ($true)
}

function Show-ScudoOptionalToolsPage {
    $controls = @(
        Get-ScudoSortedControls |
            Where-Object {
                $_.Category -eq 'Apps' -or $_.Id -in @(
                    'browser.firefox-noscript',
                    'browser.firefox-sanitize',
                    'browser-hardening'
                )
            }
    )

    Show-ScudoControlListPage -Heading 'Optional apps and browser tools' -Controls $controls
}

function Show-ScudoGuidedWalkthrough {
    $sections = @(
        Get-ScudoTranscriptSectionCatalog |
            Where-Object { $_.Id -ne 'apps' } |
            Sort-Object DisplayRank
    )

    for ($index = 0; $index -lt @($sections).Count; $index += 1) {
        $section = $sections[$index]

        do {
            Write-ScudoBanner
            Write-ScudoText $section.Title Cyan
            Write-ScudoText ''
            Write-ScudoText $section.Summary Gray
            Write-ScudoText ''

            $controls = Get-ScudoControlsForSection -SectionId $section.Id
            foreach ($control in $controls) {
                $status = Invoke-ScudoControlDetection -Control $control
                Write-ScudoText ('- {0} {1}' -f (Get-ScudoStatusBadge -Status $status), $control.Title) (Get-ScudoStatusColor -Status $status)
            }

            Write-ScudoText ''
            Write-ScudoText '[1] Review this section' Green
            if ($index -lt (@($sections).Count - 1)) {
                Write-ScudoText '[2] Next section' Gray
            }
            Write-ScudoText '[0] Exit walkthrough' Gray
            Write-ScudoText ''

            $selection = Read-Host 'Select an option'
            switch ($selection) {
                '1' {
                    Show-ScudoControlListPage -Heading $section.Title -Controls $controls
                }
                '2' {
                    if ($index -lt (@($sections).Count - 1)) {
                        break
                    }
                }
                '0' {
                    return
                }
                default {
                    Write-ScudoText 'Invalid selection.' Red
                    Pause-Scudo
                }
            }
        } while ($selection -ne '2')
    }
}

function Invoke-ScudoShowTarget {
    param(
        [Parameter(Mandatory)]
        [string]$Target
    )

    $preset = Get-ScudoPreset -PresetId $Target
    if ($null -ne $preset) {
        Show-ScudoPresetPreview -Preset $preset
        if ($preset.Id -eq 'guided') {
            $controls = Get-ScudoControlsForPreset -PresetId $preset.Id -IncludeNonAutomatic
        }
        else {
            $controls = Get-ScudoControlsForPreset -PresetId $preset.Id
        }

        foreach ($control in $controls) {
            Write-ScudoText ('- {0}: {1}' -f $control.Title, $control.WhatItDoes) Gray
        }

        return 0
    }

    $control = (Get-ScudoControlCatalog | Where-Object { $_.Id -eq $Target } | Select-Object -First 1)
    if ($null -eq $control) {
        Write-ScudoText "Unknown control or preset: $Target" Red
        return 1
    }

    Show-ScudoControlPreview -Control $control -Status (Invoke-ScudoControlDetection -Control $control)
    return 0
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
    Write-ScudoText 'Review this PC' Green
    Write-ScudoText ''

    $statusMap = Get-ScudoStatusMap
    foreach ($state in 'already-configured', 'needs-action', 'pending-reboot', 'advisory', 'unsupported', 'error') {
        $count = @(
            $statusMap.Values |
                Where-Object { $_.State -eq $state }
        ).Count
        Write-ScudoText ('- {0}: {1}' -f $state, $count) DarkGray
    }

    foreach ($section in Get-ScudoTranscriptSectionCatalog | Where-Object { $_.Id -ne 'apps' } | Sort-Object DisplayRank) {
        $controls = Get-ScudoControlsForSection -SectionId $section.Id
        if (@($controls).Count -eq 0) {
            continue
        }

        Write-ScudoText ''
        Write-ScudoText $section.Title Cyan
        foreach ($control in $controls) {
            $status = $statusMap[$control.Id]
            $label = '{0} {1}' -f (Get-ScudoStatusBadge -Status $status), $control.Title
            Write-ScudoText $label (Get-ScudoStatusColor -Status $status)
            Write-ScudoText ('    {0}' -f $status.Summary) DarkGray
        }
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
    Write-ScudoText 'scudo --preset baseline' Gray
    Write-ScudoText 'scudo --preset strict' Gray
    Write-ScudoText 'scudo --show <control-id|preset>' Gray
    Write-ScudoText 'scudo --export' Gray
    Write-ScudoText 'scudo --gui' Gray
    Write-ScudoText 'scudo --cli' Gray
    Write-ScudoText 'scudo --version' Gray
    Write-ScudoText 'scudo --help' Gray
    Write-ScudoText ''
    Write-ScudoText 'advanced' DarkGray
    Write-ScudoText 'scudo --action apply --control-id <id>' DarkGray
    Write-ScudoText 'scudo --action rollback --control-id <id>' DarkGray
    Write-ScudoText 'scudo --no-pause' DarkGray
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
            '2' {
                [void](Invoke-ScudoPresetApply -PresetId 'baseline')
            }
            '3' {
                [void](Invoke-ScudoPresetApply -PresetId 'strict')
            }
            '4' {
                Show-ScudoGuidedWalkthrough
            }
            '5' {
                Show-ScudoBrowseControlsPage
            }
            '6' {
                Show-ScudoOptionalToolsPage
            }
            '7' {
                Show-ScudoRollbackPage
            }
            '8' {
                Write-ScudoBanner
                Invoke-ScudoExport
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
    elseif (-not [string]::IsNullOrWhiteSpace($parsedArguments.Show)) {
        $exitCode = Invoke-ScudoShowTarget -Target $parsedArguments.Show
    }
    elseif (-not [string]::IsNullOrWhiteSpace($parsedArguments.Preset)) {
        $exitCode = Invoke-ScudoPresetApply -PresetId $parsedArguments.Preset -SkipPause $parsedArguments.NoPause
    }
    elseif ($parsedArguments.CheckAll) {
        Invoke-ScudoCheckAll
    }
    elseif ($parsedArguments.Export) {
        Invoke-ScudoExport
    }
    elseif (Test-ScudoShouldLaunchGui -ParsedArguments $parsedArguments) {
        Show-ScudoGui
    }
    else {
        Start-ScudoMenu
    }
}
finally {
    Stop-ScudoTranscript
}

exit $exitCode
