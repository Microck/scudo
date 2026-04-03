Set-StrictMode -Version Latest

Describe 'scudo gui helpers' {
    BeforeAll {
        $projectRoot = Split-Path -Parent $PSScriptRoot
        . (Join-Path -Path $projectRoot -ChildPath 'modules/control-actions.ps1')
        . (Join-Path -Path $projectRoot -ChildPath 'modules/safety.ps1')
        . (Join-Path -Path $projectRoot -ChildPath 'modules/control-catalog.ps1')
        . (Join-Path -Path $projectRoot -ChildPath 'modules/reporting.ps1')
        . (Join-Path -Path $projectRoot -ChildPath 'modules/gui.ps1')
    }

    It 'defines the expected gui theme palette' {
        $theme = Get-ScudoGuiThemeDefinition

        $theme.BgMain | Should -Be '#2B3031'
        $theme.BgSurface | Should -Be '#3B4243'
        $theme.TextPrimary | Should -Be '#EAD6B8'
        $theme.AccentPrimary | Should -Be '#81A884'
        $theme.AccentDanger | Should -Be '#CA4433'
    }

    It 'summarizes status buckets for the overview cards' {
        $statusMap = @{
            one   = [pscustomobject]@{ State = 'already-configured' }
            two   = [pscustomobject]@{ State = 'needs-action' }
            three = [pscustomobject]@{ State = 'pending-reboot' }
            four  = [pscustomobject]@{ State = 'advisory' }
            five  = [pscustomobject]@{ State = 'unsupported' }
            six   = [pscustomobject]@{ State = 'error' }
            seven = [pscustomobject]@{ State = 'already-configured' }
        }

        $summary = Get-ScudoGuiSummaryCounts -StatusMap $statusMap

        $summary.Configured | Should -Be 2
        $summary.NeedsAction | Should -Be 1
        $summary.PendingReboot | Should -Be 1
        $summary.Guidance | Should -Be 1
        $summary.Unsupported | Should -Be 1
        $summary.Errors | Should -Be 1
    }

    It 'filters controls by section, track, and search text' {
        $sectionRankMap = @{}
        foreach ($section in Get-ScudoSectionCatalog) {
            $sectionRankMap[$section.Id] = [int]$section.DisplayRank
        }

        $controls = @(
            Get-ScudoControlCatalog |
                Sort-Object `
                    @{ Expression = { $sectionRankMap[$_.SectionId] } }, `
                    @{ Expression = { [int]$_.SortOrder } }, `
                    @{ Expression = { $_.Title } }
        )

        $firmwareControls = Get-ScudoGuiFilteredControls -Controls $controls -SectionId 'firmware'
        @($firmwareControls | Where-Object { $_.SectionId -ne 'firmware' }).Count | Should -Be 0

        $strictControls = Get-ScudoGuiFilteredControls -Controls $controls -TierFilter 'strict'
        @($strictControls | Where-Object { $_.RecommendationTier -ne 'strict' }).Count | Should -Be 0

        $searchControls = Get-ScudoGuiFilteredControls -Controls $controls -SearchText 'helium'
        @($searchControls | Select-Object -ExpandProperty Id) | Should -Contain 'app.helium'
        @($searchControls).Count | Should -BeGreaterThan 0
    }

    It 'creates combo items with stable ids and labels for the gui filters' {
        $item = New-ScudoGuiComboItem -Id 'strict' -Title 'Strict'

        $item.Id | Should -Be 'strict'
        $item.Title | Should -Be 'Strict'
        (Get-ScudoGuiComboItemId -Item $item) | Should -Be 'strict'
    }

    It 'maps action labels for the gui detail footer' {
        $controlMap = @{}
        foreach ($control in Get-ScudoControlCatalog) {
            $controlMap[$control.Id] = $control
        }

        (Get-ScudoGuiPrimaryActionLabel -Control $controlMap['account.create-standard-user']) | Should -Be 'Create user'
        (Get-ScudoGuiPrimaryActionLabel -Control $controlMap['app.helium']) | Should -Be 'Install'
        (Get-ScudoGuiPrimaryActionLabel -Control $controlMap['firmware.reboot-to-uefi']) | Should -Be 'Reboot to firmware'
        (Get-ScudoGuiPrimaryActionLabel -Control $controlMap['service.remote-registry.disabled']) | Should -Be 'Apply'
    }
}
