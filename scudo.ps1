param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ScudoVersion = '0.2.0'
$script:ScudoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:ScudoUiBodyWidth = 92

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

    $metrics = Get-ScudoUiMetrics
    $lines = Get-ScudoWrappedLines -Text $Text -Width $metrics.BodyWidth

    foreach ($line in $lines) {
        $prefix = ' ' * $metrics.LeftPad
        if (Test-ScudoWindows) {
            Write-Host ($prefix + $line) -ForegroundColor $Color
        }
        else {
            Write-Host ($prefix + $line)
        }
    }
}

function Get-ScudoUiMetrics {
    $consoleWidth = 100

    try {
        $consoleWidth = [Math]::Max(80, [int]$Host.UI.RawUI.WindowSize.Width)
    }
    catch {
        $consoleWidth = 100
    }

    $bodyWidth = [Math]::Min($script:ScudoUiBodyWidth, [Math]::Max(72, $consoleWidth - 6))
    $leftPad = [Math]::Max(0, [int][Math]::Floor(($consoleWidth - $bodyWidth) / 2))

    return [pscustomobject]@{
        ConsoleWidth = $consoleWidth
        BodyWidth    = $bodyWidth
        LeftPad      = $leftPad
    }
}

function Get-ScudoWrappedLines {
    param(
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory)]
        [int]$Width
    )

    if ([string]::IsNullOrEmpty($Text)) {
        return @('')
    }

    $wrappedLines = New-Object System.Collections.Generic.List[string]
    $sourceLines = $Text -split "`r?`n"

    foreach ($sourceLine in $sourceLines) {
        if ($sourceLine.Length -le $Width) {
            $wrappedLines.Add($sourceLine)
            continue
        }

        $currentLine = ''
        foreach ($word in ($sourceLine -split '\s+')) {
            if ([string]::IsNullOrWhiteSpace($word)) {
                continue
            }

            if ([string]::IsNullOrEmpty($currentLine)) {
                if ($word.Length -le $Width) {
                    $currentLine = $word
                    continue
                }

                for ($index = 0; $index -lt $word.Length; $index += $Width) {
                    $segmentLength = [Math]::Min($Width, $word.Length - $index)
                    $wrappedLines.Add($word.Substring($index, $segmentLength))
                }

                continue
            }

            $candidate = '{0} {1}' -f $currentLine, $word
            if ($candidate.Length -le $Width) {
                $currentLine = $candidate
                continue
            }

            $wrappedLines.Add($currentLine)
            if ($word.Length -le $Width) {
                $currentLine = $word
                continue
            }

            for ($index = 0; $index -lt $word.Length; $index += $Width) {
                $segmentLength = [Math]::Min($Width, $word.Length - $index)
                $wrappedLines.Add($word.Substring($index, $segmentLength))
            }

            $currentLine = ''
        }

        if (-not [string]::IsNullOrEmpty($currentLine)) {
            $wrappedLines.Add($currentLine)
        }
    }

    return @($wrappedLines)
}

function Write-ScudoCenteredText {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text,

        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )

    $metrics = Get-ScudoUiMetrics
    foreach ($line in (Get-ScudoWrappedLines -Text $Text -Width $metrics.BodyWidth)) {
        $innerPad = [Math]::Max(0, [int][Math]::Floor(($metrics.BodyWidth - $line.Length) / 2))
        $prefix = ' ' * ($metrics.LeftPad + $innerPad)

        if (Test-ScudoWindows) {
            Write-Host ($prefix + $line) -ForegroundColor $Color
        }
        else {
            Write-Host ($prefix + $line)
        }
    }
}

function Write-ScudoDivider {
    param(
        [string]$Character = '='
    )

    $metrics = Get-ScudoUiMetrics
    Write-ScudoText -Text ($Character * $metrics.BodyWidth) -Color DarkGray
}

function Write-ScudoSpacer {
    Write-Host ''
}

function Write-ScudoSectionTitle {
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )

    Write-ScudoText -Text ('[ {0} ]' -f $Text.ToUpperInvariant()) -Color $Color
}

function Write-ScudoMenuOption {
    param(
        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [string]$Label,

        [string]$Detail = '',

        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )

    $metrics = Get-ScudoUiMetrics
    $detailWidth = if ([string]::IsNullOrWhiteSpace($Detail)) { 0 } else { 22 }
    $labelWidth = $metrics.BodyWidth - 6

    if ($detailWidth -gt 0) {
        $labelWidth -= ($detailWidth + 1)
    }

    $trimmedLabel = $Label
    if ($trimmedLabel.Length -gt $labelWidth) {
        $trimmedLabel = $trimmedLabel.Substring(0, $labelWidth - 3) + '...'
    }

    $line = (('[{0}]' -f $Key).PadRight(6)) + $trimmedLabel.PadRight($labelWidth)
    if ($detailWidth -gt 0) {
        $trimmedDetail = $Detail
        if ($trimmedDetail.Length -gt $detailWidth) {
            $trimmedDetail = $trimmedDetail.Substring(0, $detailWidth - 3) + '...'
        }

        $line += ' ' + $trimmedDetail.PadLeft($detailWidth)
    }

    Write-ScudoText -Text $line -Color $Color
}

function Write-ScudoKeyValue {
    param(
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value,

        [ConsoleColor]$Color = [ConsoleColor]::DarkGray
    )

    $line = '{0,-20} {1}' -f ($Label + ':'), $Value
    Write-ScudoText -Text $line -Color $Color
}

function Write-ScudoPromptHint {
    param(
        [string]$Text = 'Keys: shown items select | N next page | P previous page | 0 back'
    )

    Write-ScudoDivider -Character '-'
    Write-ScudoCenteredText -Text $Text -Color DarkGray
}

function Read-ScudoInput {
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [switch]$AsSecureString
    )

    $metrics = Get-ScudoUiMetrics
    $promptText = (' ' * $metrics.LeftPad) + $Prompt

    if ($AsSecureString) {
        return Read-Host $promptText -AsSecureString
    }

    return Read-Host $promptText
}

function Read-ScudoMenuChoice {
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter(Mandatory)]
        [string[]]$Choices
    )

    $normalizedChoices = @(
        $Choices |
            ForEach-Object { ([string]$_).ToUpperInvariant() }
    )

    $supportsSingleKey = (Test-ScudoWindows) -and (@($normalizedChoices | Where-Object { $_.Length -ne 1 }).Count -eq 0)
    if ($supportsSingleKey) {
        try {
            $metrics = Get-ScudoUiMetrics
            $promptText = (' ' * $metrics.LeftPad) + $Prompt + ' '

            if (Test-ScudoWindows) {
                Write-Host $promptText -NoNewline -ForegroundColor Gray
            }
            else {
                Write-Host $promptText -NoNewline
            }

            while ($true) {
                $keyInfo = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                $rawCharacter = [string]$keyInfo.Character
                if ([string]::IsNullOrWhiteSpace($rawCharacter)) {
                    continue
                }

                $choice = $rawCharacter.ToUpperInvariant()
                if ($normalizedChoices -notcontains $choice) {
                    continue
                }

                if (Test-ScudoWindows) {
                    Write-Host $choice -ForegroundColor Green
                }
                else {
                    Write-Host $choice
                }

                return $choice
            }
        }
        catch {
        }
    }

    return (Read-ScudoInput -Prompt $Prompt).ToUpperInvariant()
}

function Show-ScudoTaskScreen {
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [string]$Subtitle = ''
    )

    Write-ScudoBanner
    Write-ScudoCenteredText -Text $Title -Color Green
    if (-not [string]::IsNullOrWhiteSpace($Subtitle)) {
        Write-ScudoCenteredText -Text $Subtitle -Color Gray
    }
    Write-ScudoDivider -Character '-'
}

function Get-ScudoPageItems {
    param(
        [Parameter(Mandatory)]
        [array]$Items,

        [Parameter(Mandatory)]
        [int]$PageIndex,

        [Parameter(Mandatory)]
        [int]$PageSize
    )

    $offset = $PageIndex * $PageSize
    return @($Items | Select-Object -Skip $offset -First $PageSize)
}

function Get-ScudoPageCount {
    param(
        [Parameter(Mandatory)]
        [int]$TotalCount,

        [Parameter(Mandatory)]
        [int]$PageSize
    )

    if ($TotalCount -le 0) {
        return 1
    }

    return [Math]::Max(1, [int][Math]::Ceiling($TotalCount / $PageSize))
}

function Write-ScudoPageStatus {
    param(
        [Parameter(Mandatory)]
        [int]$PageIndex,

        [Parameter(Mandatory)]
        [int]$PageCount
    )

    if ($PageCount -gt 1) {
        Write-ScudoKeyValue -Label 'Page' -Value ('{0}/{1}' -f ($PageIndex + 1), $PageCount) -Color DarkGray
    }
}

function Write-ScudoTaskStep {
    param(
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [string]$Result,

        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )

    $metrics = Get-ScudoUiMetrics
    $normalizedResult = switch ($Result.ToLowerInvariant()) {
        'already-configured' { 'DONE' }
        'needs-action' { 'PEND' }
        'pending-reboot' { 'REBT' }
        'advisory' { 'MANL' }
        'unsupported' { 'SKIP' }
        'error' { 'FAIL' }
        default {
            if ($Result.Length -gt 4) {
                $Result.Substring(0, 4).ToUpperInvariant()
            }
            else {
                $Result.ToUpperInvariant()
            }
        }
    }
    $resultToken = ('[{0}]' -f $normalizedResult)
    $labelWidth = [Math]::Max(16, $metrics.BodyWidth - $resultToken.Length - 1)
    $trimmedLabel = $Label
    if ($trimmedLabel.Length -gt $labelWidth) {
        $trimmedLabel = $trimmedLabel.Substring(0, $labelWidth - 3) + '...'
    }

    $dotCount = [Math]::Max(2, $labelWidth - $trimmedLabel.Length)
    $line = '{0}{1}{2}' -f $trimmedLabel, ('.' * $dotCount), $resultToken
    Write-ScudoText -Text $line -Color $Color
}

function Write-ScudoBanner {
    if (Test-ScudoWindows) {
        try {
            $Host.UI.RawUI.BackgroundColor = 'Black'
            $Host.UI.RawUI.ForegroundColor = 'Gray'
        }
        catch {
        }
    }

    Clear-Host
    Write-ScudoSpacer
    Write-ScudoCenteredText -Text ("Session: {0}" -f $(if (Test-ScudoAdministrator) { 'Elevated' } else { 'Standard' })) -Color DarkGray
    Write-ScudoDivider
    Write-ScudoSpacer
    Write-ScudoCenteredText -Text 'SCUDO' -Color Gray
    Write-ScudoCenteredText -Text ("Windows 11 hardening utility v{0}" -f $script:ScudoVersion) -Color Gray
    Write-ScudoSpacer
    Write-ScudoDivider
}

function Get-ScudoStatusBadge {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Status
    )

    switch ($Status.State) {
        'already-configured' { return '[DONE]' }
        'needs-action' { return '[PEND]' }
        'pending-reboot' { return '[REBT]' }
        'advisory' { return '[MANUAL]' }
        'unsupported' { return '[SKIP]' }
        'error' { return '[FAIL]' }
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
        'advisory' { return [ConsoleColor]::Gray }
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
    foreach ($section in Get-ScudoSectionCatalog) {
        $sectionRankMap[$section.Id] = [int]$section.DisplayRank
    }

    return @(
        Get-ScudoControlCatalog |
            Sort-Object `
                @{ Expression = { $sectionRankMap[$_.SectionId] } }, `
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
            Where-Object { $_.SectionId -eq $SectionId }
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
                section            = $control.SectionId
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
    Write-ScudoSectionTitle -Text 'Audit' -Color Gray
    Write-ScudoMenuOption -Key '1' -Label 'Audit this PC' -Color Gray
    Write-ScudoSpacer
    Write-ScudoSectionTitle -Text 'Apply hardening' -Color Gray
    Write-ScudoMenuOption -Key '2' -Label 'Apply baseline hardening' -Color Gray
    Write-ScudoMenuOption -Key '3' -Label 'Apply strict hardening' -Color Gray
    Write-ScudoSpacer
    Write-ScudoSectionTitle -Text 'Manual / guided' -Color Gray
    Write-ScudoMenuOption -Key '4' -Label 'Run guided walkthrough' -Color Gray
    Write-ScudoSpacer
    Write-ScudoSectionTitle -Text 'Utilities' -Color Gray
    Write-ScudoMenuOption -Key '5' -Label 'Review individual controls' -Color Gray
    Write-ScudoMenuOption -Key '6' -Label 'Manage optional apps and browser tools' -Color Gray
    Write-ScudoMenuOption -Key '7' -Label 'Restore previous changes' -Color Gray
    Write-ScudoMenuOption -Key '8' -Label 'Export results' -Color Gray
    Write-ScudoSpacer
    Write-ScudoSectionTitle -Text 'Status' -Color Gray

    foreach ($preset in @('baseline', 'strict')) {
        $controls = Get-ScudoControlsForPreset -PresetId $preset
        $doneCount = @(
            $controls |
                Where-Object { $StatusMap[$_.Id].State -eq 'already-configured' }
        ).Count
        $totalCount = @($controls).Count
        $label = if ($preset -eq 'baseline') { 'Baseline configured' } else { 'Strict configured' }
        Write-ScudoKeyValue -Label $label -Value ('{0}/{1}' -f $doneCount, $totalCount) -Color DarkGray
    }

    Write-ScudoText -Text 'Reversible changes can be restored from Utilities.' -Color DarkGray
    Write-ScudoSpacer
    Write-ScudoMenuOption -Key '0' -Label 'Exit Scudo' -Color Gray
    Write-ScudoPromptHint -Text 'Enter 0-8 to continue.'
}

function Pause-Scudo {
    param(
        [bool]$SkipPause = $false
    )

    if (-not $SkipPause) {
        Write-ScudoPromptHint -Text 'Press Enter to continue.'
        [void](Read-ScudoInput -Prompt 'Press Enter to continue')
    }
}

function Confirm-ScudoSelection {
    param(
        [Parameter(Mandatory)]
        [string]$Prompt
    )

    Write-ScudoPromptHint -Text $Prompt
    $choice = Read-ScudoInput -Prompt "$Prompt [Y/N]"
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
    Write-ScudoCenteredText -Text $Control.Title -Color Green
    Write-ScudoDivider -Character '-'
    Write-ScudoKeyValue -Label 'State' -Value $Status.Summary -Color (Get-ScudoStatusColor -Status $Status)
    Write-ScudoKeyValue -Label 'Section' -Value $Control.SectionId -Color DarkGray
    Write-ScudoKeyValue -Label 'Tier' -Value (Get-ScudoRecommendationLabel -Tier $Control.RecommendationTier) -Color DarkGray
    Write-ScudoKeyValue -Label 'Automation' -Value (Get-ScudoAutomationLabel -AutomationLevel $Control.AutomationLevel) -Color DarkGray
    Write-ScudoKeyValue -Label 'Requires admin' -Value ([string]$Control.RequiresAdmin).ToLowerInvariant() -Color DarkGray
    Write-ScudoKeyValue -Label 'Requires reboot' -Value ([string]$Control.RequiresReboot).ToLowerInvariant() -Color DarkGray
    Write-ScudoKeyValue -Label 'Rollback' -Value $Control.RollbackNote -Color DarkGray
    Write-ScudoSpacer
    Write-ScudoSectionTitle -Text 'What it does' -Color Gray
    Write-ScudoText -Text $Control.WhatItDoes -Color Gray
    Write-ScudoSpacer
    Write-ScudoSectionTitle -Text 'Why apply it' -Color Green
    Write-ScudoText -Text $Control.WhyApply -Color Gray
    Write-ScudoSpacer
    Write-ScudoSectionTitle -Text 'Why skip it' -Color Yellow
    Write-ScudoText -Text $Control.WhyNotApply -Color Gray

    $statusNotes = Get-ScudoStatusNotes -Status $Status
    if (@($statusNotes).Count -gt 0) {
        Write-ScudoSpacer
        Write-ScudoSectionTitle -Text 'Status notes' -Color Gray
        foreach ($note in $statusNotes) {
            Write-ScudoText -Text ('- {0}' -f $note) -Color DarkGray
        }
    }

    Write-ScudoSpacer
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

        $userName = Read-ScudoInput -Prompt 'Enter the new local username'
        if ([string]::IsNullOrWhiteSpace($userName)) {
            Write-ScudoText 'Username is required.' Red
            return
        }
        if ($userName -notmatch '^[a-zA-Z0-9._-]{1,20}$') {
            Write-ScudoText 'Username must be 1-20 characters and contain only letters, numbers, dots, underscores, or hyphens.' Red
            return
        }

        $password = Read-ScudoInput -Prompt 'Enter the password for the new account' -AsSecureString
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

    Show-ScudoTaskScreen -Title $Control.Title -Subtitle 'Applying control'
    Write-ScudoTaskStep -Label 'Preflight checks' -Result 'DONE' -Color Green
    $result = Invoke-ScudoControlApply -Control $Control
    Save-ScudoOperationState -Control $Control -Action 'apply' -BeforeStatus $Status -ResultStatus $result | Out-Null
    Write-ScudoTaskStep -Label 'Apply control' -Result $result.State -Color (Get-ScudoStatusColor -Status $result)
    Write-ScudoSpacer
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

    Show-ScudoTaskScreen -Title $Control.Title -Subtitle 'Restoring saved state'
    Write-ScudoTaskStep -Label 'Preflight checks' -Result 'DONE' -Color Green
    $result = Invoke-ScudoControlRollback -Control $Control -Snapshot $Snapshot
    Save-ScudoOperationState -Control $Control -Action 'rollback' -BeforeStatus $currentStatus -ResultStatus $result | Out-Null
    Write-ScudoTaskStep -Label 'Rollback control' -Result $result.State -Color (Get-ScudoStatusColor -Status $result)
    Write-ScudoSpacer
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

    Show-ScudoTaskScreen -Title $preset.Title -Subtitle 'Running preset actions'
    $controls = Get-ScudoControlsForPreset -PresetId $PresetId
    $statusMap = Get-ScudoStatusMap
    $hadPendingReboot = $false
    $hadError = $false

    foreach ($control in $controls) {
        $status = $statusMap[$control.Id]
        $label = '{0} {1}' -f (Get-ScudoStatusBadge -Status $status), $control.Title

        if ($status.State -eq 'already-configured') {
            Write-ScudoTaskStep -Label $control.Title -Result 'DONE' -Color Green
            continue
        }

        if ($status.State -eq 'unsupported') {
            Write-ScudoTaskStep -Label $control.Title -Result 'SKIP' -Color DarkGray
            continue
        }

        $preflight = Get-ScudoPreflightStatus -Control $control -Action 'apply'
        if ($preflight.Blocked) {
            Write-ScudoTaskStep -Label $control.Title -Result 'FAIL' -Color Red
            Write-ScudoText "Reason: $($preflight.Summary)" DarkGray
            $hadError = $true
            continue
        }

        $result = Invoke-ScudoControlApply -Control $control
        if ($result.State -ne 'error') {
            Save-ScudoOperationState -Control $control -Action 'apply' -BeforeStatus $status -ResultStatus $result | Out-Null
        }

        Write-ScudoTaskStep -Label $control.Title -Result $result.State -Color (Get-ScudoStatusColor -Status $result)
        Write-ScudoText $result.Summary DarkGray
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
            Write-ScudoMenuOption -Key $applyOption -Label $actionLabel -Detail 'run' -Color Green
            $optionNumber += 1
        }

        if ((Test-ScudoControlRollbackSupported -Control $Control) -and $null -ne $snapshot) {
            $rollbackOption = "$optionNumber"
            Write-ScudoMenuOption -Key $rollbackOption -Label 'Roll back saved state' -Detail 'restore' -Color Yellow
            $optionNumber += 1
        }

        Write-ScudoSpacer
        Write-ScudoMenuOption -Key '0' -Label 'Back' -Color DarkGray

        Write-ScudoPromptHint
        $choices = @('0')
        if ($null -ne $applyOption) {
            $choices += $applyOption
        }
        if ($null -ne $rollbackOption) {
            $choices += $rollbackOption
        }
        $selection = Read-ScudoMenuChoice -Prompt 'Enter an option number:' -Choices $choices
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

    $pageSize = 8
    $pageIndex = 0

    do {
        Write-ScudoBanner
        Write-ScudoCenteredText -Text $Heading -Color Green
        Write-ScudoDivider -Character '-'

        if (@($Controls).Count -eq 0) {
            Write-ScudoText 'No controls are available in this view.' DarkGray
            Write-ScudoSpacer
            Pause-Scudo
            return
        }

        $pageCount = Get-ScudoPageCount -TotalCount @($Controls).Count -PageSize $pageSize
        if ($pageIndex -ge $pageCount) {
            $pageIndex = $pageCount - 1
        }

        $pageItems = Get-ScudoPageItems -Items $Controls -PageIndex $pageIndex -PageSize $pageSize
        for ($index = 0; $index -lt @($pageItems).Count; $index += 1) {
            $control = $pageItems[$index]
            $status = Invoke-ScudoControlDetection -Control $control
            $detail = '{0} | {1}' -f (Get-ScudoRecommendationLabel -Tier $control.RecommendationTier), (Get-ScudoAutomationLabel -AutomationLevel $control.AutomationLevel)
            Write-ScudoMenuOption -Key ($index + 1) -Label ('{0} {1}' -f (Get-ScudoStatusBadge -Status $status), $control.Title) -Detail $detail -Color (Get-ScudoStatusColor -Status $status)
        }

        Write-ScudoSpacer
        Write-ScudoPageStatus -PageIndex $pageIndex -PageCount $pageCount
        if ($pageIndex -gt 0) {
            Write-ScudoMenuOption -Key 'P' -Label 'Previous page' -Detail 'navigate' -Color Gray
        }
        if ($pageIndex -lt ($pageCount - 1)) {
            Write-ScudoMenuOption -Key 'N' -Label 'Next page' -Detail 'navigate' -Color Gray
        }
        Write-ScudoMenuOption -Key '0' -Label 'Back' -Color DarkGray

        Write-ScudoPromptHint
        $choices = @('0') + @(1..@($pageItems).Count | ForEach-Object { "$_" })
        if ($pageIndex -gt 0) {
            $choices += 'P'
        }
        if ($pageIndex -lt ($pageCount - 1)) {
            $choices += 'N'
        }
        $selection = Read-ScudoMenuChoice -Prompt 'Enter an option number:' -Choices $choices
        if ($selection -eq '0') {
            return
        }

        if ($selection -eq 'P') {
            $pageIndex -= 1
            continue
        }

        if ($selection -eq 'N') {
            $pageIndex += 1
            continue
        }

        $selectedIndex = 0
        if (-not [int]::TryParse($selection, [ref]$selectedIndex)) {
            Write-ScudoText 'Invalid selection.' Red
            Pause-Scudo
            continue
        }

        if ($selectedIndex -lt 1 -or $selectedIndex -gt @($pageItems).Count) {
            Write-ScudoText 'Invalid selection.' Red
            Pause-Scudo
            continue
        }

        Show-ScudoControlActionPage -Control $pageItems[$selectedIndex - 1]
    } while ($true)
}

function Show-ScudoBrowseControlsPage {
    $categories = @(
        Get-ScudoSortedControls |
            Where-Object { $_.Category -ne 'Apps' } |
            Select-Object -ExpandProperty Category -Unique
    )

    $pageSize = 8
    $pageIndex = 0

    do {
        Write-ScudoBanner
        Write-ScudoCenteredText -Text 'Browse individual controls' -Color Green
        Write-ScudoDivider -Character '-'

        $pageCount = Get-ScudoPageCount -TotalCount @($categories).Count -PageSize $pageSize
        if ($pageIndex -ge $pageCount) {
            $pageIndex = $pageCount - 1
        }

        $pageItems = Get-ScudoPageItems -Items $categories -PageIndex $pageIndex -PageSize $pageSize
        for ($index = 0; $index -lt @($pageItems).Count; $index += 1) {
            Write-ScudoMenuOption -Key ($index + 1) -Label $pageItems[$index] -Detail 'category' -Color Gray
        }

        Write-ScudoSpacer
        Write-ScudoPageStatus -PageIndex $pageIndex -PageCount $pageCount
        if ($pageIndex -gt 0) {
            Write-ScudoMenuOption -Key 'P' -Label 'Previous page' -Detail 'navigate' -Color Gray
        }
        if ($pageIndex -lt ($pageCount - 1)) {
            Write-ScudoMenuOption -Key 'N' -Label 'Next page' -Detail 'navigate' -Color Gray
        }
        Write-ScudoMenuOption -Key '0' -Label 'Back' -Color DarkGray

        Write-ScudoPromptHint
        $choices = @('0') + @(1..@($pageItems).Count | ForEach-Object { "$_" })
        if ($pageIndex -gt 0) {
            $choices += 'P'
        }
        if ($pageIndex -lt ($pageCount - 1)) {
            $choices += 'N'
        }
        $selection = Read-ScudoMenuChoice -Prompt 'Enter an option number:' -Choices $choices
        if ($selection -eq '0') {
            return
        }

        if ($selection -eq 'P') {
            $pageIndex -= 1
            continue
        }

        if ($selection -eq 'N') {
            $pageIndex += 1
            continue
        }

        $selectedIndex = 0
        if (-not [int]::TryParse($selection, [ref]$selectedIndex)) {
            Write-ScudoText 'Invalid selection.' Red
            Pause-Scudo
            continue
        }

        if ($selectedIndex -lt 1 -or $selectedIndex -gt @($pageItems).Count) {
            Write-ScudoText 'Invalid selection.' Red
            Pause-Scudo
            continue
        }

        $category = $pageItems[$selectedIndex - 1]
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
                    'browser.firefox-sanitize'
                )
            }
    )

    Show-ScudoControlListPage -Heading 'Optional apps and browser tools' -Controls $controls
}

function Show-ScudoGuidedWalkthrough {
    $sections = @(
        Get-ScudoSectionCatalog |
            Where-Object { $_.Id -ne 'apps' } |
            Sort-Object DisplayRank
    )

    for ($index = 0; $index -lt @($sections).Count; $index += 1) {
        $section = $sections[$index]

        do {
            Write-ScudoBanner
            Write-ScudoCenteredText -Text $section.Title -Color Green
            Write-ScudoDivider -Character '-'
            Write-ScudoText $section.Summary Gray
            Write-ScudoSpacer

            $controls = Get-ScudoControlsForSection -SectionId $section.Id
            foreach ($control in $controls) {
                $status = Invoke-ScudoControlDetection -Control $control
                Write-ScudoText ('- {0} {1}' -f (Get-ScudoStatusBadge -Status $status), $control.Title) (Get-ScudoStatusColor -Status $status)
            }

            Write-ScudoSpacer
            Write-ScudoMenuOption -Key '1' -Label 'Review this section' -Detail 'details' -Color Green
            if ($index -lt (@($sections).Count - 1)) {
                Write-ScudoMenuOption -Key '2' -Label 'Next section' -Detail 'continue' -Color Gray
            }
            Write-ScudoMenuOption -Key '0' -Label 'Exit walkthrough' -Color DarkGray

            Write-ScudoPromptHint
            $choices = @('0', '1')
            if ($index -lt (@($sections).Count - 1)) {
                $choices += '2'
            }
            $selection = Read-ScudoMenuChoice -Prompt 'Enter an option number:' -Choices $choices
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
    $pageSize = 8
    $pageIndex = 0

    do {
        Write-ScudoBanner
        Write-ScudoCenteredText -Text 'Saved control rollback' -Color Yellow
        Write-ScudoDivider -Character '-'

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
            Write-ScudoSpacer
            Pause-Scudo
            return
        }

        $pageCount = Get-ScudoPageCount -TotalCount $controlsWithSnapshots.Count -PageSize $pageSize
        if ($pageIndex -ge $pageCount) {
            $pageIndex = $pageCount - 1
        }

        $pageItems = Get-ScudoPageItems -Items $controlsWithSnapshots -PageIndex $pageIndex -PageSize $pageSize
        for ($index = 0; $index -lt $pageItems.Count; $index += 1) {
            $item = $pageItems[$index]
            Write-ScudoMenuOption -Key ($index + 1) -Label ('[DONE] {0}' -f $item.Control.Title) -Detail 'saved state' -Color Yellow
            Write-ScudoKeyValue -Label 'Saved' -Value $item.Snapshot.savedAt -Color DarkGray
        }

        Write-ScudoSpacer
        Write-ScudoPageStatus -PageIndex $pageIndex -PageCount $pageCount
        if ($pageIndex -gt 0) {
            Write-ScudoMenuOption -Key 'P' -Label 'Previous page' -Detail 'navigate' -Color Gray
        }
        if ($pageIndex -lt ($pageCount - 1)) {
            Write-ScudoMenuOption -Key 'N' -Label 'Next page' -Detail 'navigate' -Color Gray
        }
        Write-ScudoMenuOption -Key '0' -Label 'Back' -Color DarkGray

        Write-ScudoPromptHint
        $choices = @('0') + @(1..$pageItems.Count | ForEach-Object { "$_" })
        if ($pageIndex -gt 0) {
            $choices += 'P'
        }
        if ($pageIndex -lt ($pageCount - 1)) {
            $choices += 'N'
        }
        $selection = Read-ScudoMenuChoice -Prompt 'Enter an option number:' -Choices $choices
        if ($selection -eq '0') {
            return
        }

        if ($selection -eq 'P') {
            $pageIndex -= 1
            continue
        }

        if ($selection -eq 'N') {
            $pageIndex += 1
            continue
        }

        $selectedIndex = 0
        if (-not [int]::TryParse($selection, [ref]$selectedIndex)) {
            Write-ScudoText 'Invalid selection.' Red
            Pause-Scudo
            continue
        }

        if ($selectedIndex -lt 1 -or $selectedIndex -gt $pageItems.Count) {
            Write-ScudoText 'Invalid selection.' Red
            Pause-Scudo
            continue
        }

        $selectedItem = $pageItems[$selectedIndex - 1]
        Invoke-ScudoRollbackSelection -Control $selectedItem.Control -Snapshot $selectedItem.Snapshot
        Pause-Scudo
    } while ($true)
}

function Show-ScudoFirmwarePage {
    $firmwareControls = Get-ScudoControlCatalog | Where-Object { $_.Category -eq 'Firmware' }

    do {
        Write-ScudoBanner
        Write-ScudoCenteredText -Text 'Firmware and boot items' -Color Green
        Write-ScudoDivider -Character '-'

        $infoControls = @($firmwareControls | Where-Object { $_.Id -in @('secure-boot', 'kernel-dma-protection', 'bios-password') })
        foreach ($control in $infoControls) {
            $status = Invoke-ScudoControlDetection -Control $control
            Write-ScudoText "$($control.Title): $($status.Summary)" (Get-ScudoStatusColor -Status $status)
            foreach ($note in $status.Notes) {
                Write-ScudoText "  - $note" DarkGray
            }
        }

        Write-ScudoSpacer
        Write-ScudoMenuOption -Key '1' -Label 'Reboot to firmware settings' -Detail 'uefi' -Color Green
        Write-ScudoMenuOption -Key '0' -Label 'Back' -Color DarkGray

        Write-ScudoPromptHint
        $selection = Read-ScudoMenuChoice -Prompt 'Enter an option number:' -Choices @('0', '1')
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
    Write-ScudoCenteredText -Text 'Remaining manual guidance' -Color Yellow
    Write-ScudoDivider -Character '-'

    foreach ($control in $guidanceControls) {
        $status = Invoke-ScudoControlDetection -Control $control
        Write-ScudoText "$($control.Title): $($status.Summary)" Gray
    }

    Write-ScudoSpacer
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
        Write-ScudoCenteredText -Text 'Privacy and account tools' -Color Green
        Write-ScudoDivider -Character '-'
        Write-ScudoMenuOption -Key '1' -Label ("{0} Reduce telemetry policy" -f (Get-ScudoStatusBadge -Status $telemetryPolicyStatus)) -Detail 'privacy' -Color (Get-ScudoStatusColor -Status $telemetryPolicyStatus)
        Write-ScudoMenuOption -Key '2' -Label ("{0} Disable telemetry services" -f (Get-ScudoStatusBadge -Status $telemetryServicesStatus)) -Detail 'services' -Color (Get-ScudoStatusColor -Status $telemetryServicesStatus)
        Write-ScudoMenuOption -Key '3' -Label ("{0} Create standard local user" -f (Get-ScudoStatusBadge -Status $standardUserStatus)) -Detail 'identity' -Color Yellow
        Write-ScudoMenuOption -Key '4' -Label 'Show remaining manual identity guidance' -Detail 'manual' -Color Gray
        Write-ScudoMenuOption -Key '0' -Label 'Back' -Color DarkGray

        Write-ScudoPromptHint
        $selection = Read-ScudoMenuChoice -Prompt 'Enter an option number:' -Choices @('0', '1', '2', '3', '4')
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

                $userName = Read-ScudoInput -Prompt 'Enter the new local username'
                if ([string]::IsNullOrWhiteSpace($userName)) {
                    Write-ScudoText 'Username is required.' Red
                    Pause-Scudo
                    continue
                }
                if ($userName -notmatch '^[a-zA-Z0-9._-]{1,20}$') {
                    Write-ScudoText 'Username must be 1-20 characters and contain only letters, numbers, dots, underscores, or hyphens.' Red
                    Pause-Scudo
                    continue
                }

                $password = Read-ScudoInput -Prompt 'Enter the password for the new account' -AsSecureString
                $result = New-ScudoStandardUser -UserName $userName -Password $password
                Write-ScudoText $result.Summary (Get-ScudoStatusColor -Status $result)
                Pause-Scudo
            }
            '4' {
                Write-ScudoBanner
                $manualIdentityControls = Get-ScudoControlCatalog | Where-Object { $_.Kind -eq 'manual-only' -and $_.Category -eq 'Identity' }
                foreach ($control in $manualIdentityControls) {
                    $status = Invoke-ScudoControlDetection -Control $control
                    Write-ScudoText "$($control.Title): $($status.Summary)" Gray
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
    $pageSize = 8
    $pageIndex = 0

    do {
        Write-ScudoBanner
        Write-ScudoCenteredText -Text 'Install recommended apps' -Color Green
        Write-ScudoDivider -Character '-'

        $pageCount = Get-ScudoPageCount -TotalCount $appControls.Count -PageSize $pageSize
        if ($pageIndex -ge $pageCount) {
            $pageIndex = $pageCount - 1
        }

        $pageItems = Get-ScudoPageItems -Items $appControls -PageIndex $pageIndex -PageSize $pageSize
        for ($index = 0; $index -lt $pageItems.Count; $index += 1) {
            $control = $pageItems[$index]
            $status = Invoke-ScudoControlDetection -Control $control
            Write-ScudoMenuOption -Key ($index + 1) -Label ('{0} {1}' -f (Get-ScudoStatusBadge -Status $status), $control.Title) -Detail 'install' -Color (Get-ScudoStatusColor -Status $status)
        }

        Write-ScudoSpacer
        Write-ScudoPageStatus -PageIndex $pageIndex -PageCount $pageCount
        if ($pageIndex -gt 0) {
            Write-ScudoMenuOption -Key 'P' -Label 'Previous page' -Detail 'navigate' -Color Gray
        }
        if ($pageIndex -lt ($pageCount - 1)) {
            Write-ScudoMenuOption -Key 'N' -Label 'Next page' -Detail 'navigate' -Color Gray
        }
        Write-ScudoMenuOption -Key '0' -Label 'Back' -Color DarkGray

        Write-ScudoPromptHint
        $choices = @('0') + @(1..$pageItems.Count | ForEach-Object { "$_" })
        if ($pageIndex -gt 0) {
            $choices += 'P'
        }
        if ($pageIndex -lt ($pageCount - 1)) {
            $choices += 'N'
        }
        $selection = Read-ScudoMenuChoice -Prompt 'Enter an option number:' -Choices $choices
        if ($selection -eq '0') {
            return
        }

        if ($selection -eq 'P') {
            $pageIndex -= 1
            continue
        }

        if ($selection -eq 'N') {
            $pageIndex += 1
            continue
        }

        $selectedIndex = 0
        if (-not [int]::TryParse($selection, [ref]$selectedIndex)) {
            Write-ScudoText 'Invalid selection.' Red
            Pause-Scudo
            continue
        }

        if ($selectedIndex -lt 1 -or $selectedIndex -gt $pageItems.Count) {
            Write-ScudoText 'Invalid selection.' Red
            Pause-Scudo
            continue
        }

        $control = $pageItems[$selectedIndex - 1]
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
        Write-ScudoCenteredText -Text 'Browser tools' -Color Green
        Write-ScudoDivider -Character '-'
        Write-ScudoMenuOption -Key '1' -Label ("{0} Apply Firefox NoScript policy" -f (Get-ScudoStatusBadge -Status $noScriptStatus)) -Detail 'policy' -Color (Get-ScudoStatusColor -Status $noScriptStatus)
        Write-ScudoMenuOption -Key '2' -Label ("{0} Apply Firefox shutdown sanitization" -f (Get-ScudoStatusBadge -Status $sanitizeStatus)) -Detail 'privacy' -Color (Get-ScudoStatusColor -Status $sanitizeStatus)
        Write-ScudoMenuOption -Key '3' -Label 'Show remaining manual browser guidance' -Detail 'manual' -Color Gray
        Write-ScudoMenuOption -Key '0' -Label 'Back' -Color DarkGray

        Write-ScudoPromptHint
        $selection = Read-ScudoMenuChoice -Prompt 'Enter an option number:' -Choices @('0', '1', '2', '3')
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
                    Write-ScudoText "$($control.Title): $($status.Summary)" Gray
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
    Show-ScudoTaskScreen -Title 'Review this PC' -Subtitle 'Current hardening status'

    $statusMap = Get-ScudoStatusMap
    Write-ScudoSectionTitle -Text 'Summary' -Color Gray
    foreach ($state in 'already-configured', 'needs-action', 'pending-reboot', 'advisory', 'unsupported', 'error') {
        $count = @(
            $statusMap.Values |
                Where-Object { $_.State -eq $state }
        ).Count
        Write-ScudoKeyValue -Label $state -Value "$count" -Color DarkGray
    }

    foreach ($section in Get-ScudoSectionCatalog | Where-Object { $_.Id -ne 'apps' } | Sort-Object DisplayRank) {
        $controls = Get-ScudoControlsForSection -SectionId $section.Id
        if (@($controls).Count -eq 0) {
            continue
        }

        Write-ScudoSpacer
        Write-ScudoSectionTitle -Text $section.Title -Color Yellow
        foreach ($control in $controls) {
            $status = $statusMap[$control.Id]
            $label = '{0} {1}' -f (Get-ScudoStatusBadge -Status $status), $control.Title
            Write-ScudoText $label (Get-ScudoStatusColor -Status $status)
            Write-ScudoText ('  {0}' -f $status.Summary) DarkGray
        }
    }

    Write-ScudoSpacer
}

function Invoke-ScudoExport {
    Show-ScudoTaskScreen -Title 'Export report' -Subtitle 'Generating markdown and JSON output'
    $reportPaths = Export-ScudoReport -Results (Get-ScudoReportEntries)
    Write-ScudoTaskStep -Label 'Write markdown report' -Result 'DONE' -Color Green
    Write-ScudoTaskStep -Label 'Write JSON report' -Result 'DONE' -Color Green
    Write-ScudoSpacer
    Write-ScudoKeyValue -Label 'Markdown' -Value $reportPaths.MarkdownPath -Color DarkGray
    Write-ScudoKeyValue -Label 'JSON' -Value $reportPaths.JsonPath -Color DarkGray
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

    Show-ScudoTaskScreen -Title $control.Title -Subtitle 'Applying control'
    Write-ScudoTaskStep -Label 'Preflight checks' -Result 'DONE' -Color Green
    $result = Invoke-ScudoControlApply -Control $control
    Save-ScudoOperationState -Control $control -Action 'apply' -BeforeStatus $status -ResultStatus $result | Out-Null
    Write-ScudoTaskStep -Label 'Apply control' -Result $result.State -Color (Get-ScudoStatusColor -Status $result)
    Write-ScudoSpacer
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

    Show-ScudoTaskScreen -Title $control.Title -Subtitle 'Restoring saved state'
    Write-ScudoTaskStep -Label 'Preflight checks' -Result 'DONE' -Color Green
    $result = Invoke-ScudoControlRollback -Control $control -Snapshot $snapshot
    Save-ScudoOperationState -Control $control -Action 'rollback' -BeforeStatus $status -ResultStatus $result | Out-Null
    Write-ScudoTaskStep -Label 'Rollback control' -Result $result.State -Color (Get-ScudoStatusColor -Status $result)
    Write-ScudoSpacer
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
        $selection = Read-ScudoMenuChoice -Prompt 'Enter an option number:' -Choices @('0', '1', '2', '3', '4', '5', '6', '7', '8')

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

$parsedArguments = Get-ScudoParsedArguments -Arguments @($RemainingArguments)

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
