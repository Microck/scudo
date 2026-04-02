Set-StrictMode -Version Latest

Describe 'scudo control catalog' {
    BeforeAll {
        $projectRoot = Split-Path -Parent $PSScriptRoot
        . (Join-Path -Path $projectRoot -ChildPath 'modules/control-actions.ps1')
        . (Join-Path -Path $projectRoot -ChildPath 'modules/safety.ps1')
        . (Join-Path -Path $projectRoot -ChildPath 'modules/control-catalog.ps1')
        . (Join-Path -Path $projectRoot -ChildPath 'modules/reporting.ps1')
        . (Join-Path -Path $projectRoot -ChildPath 'modules/entrypoint.ps1')
    }

    It 'defines unique control ids' {
        $controls = Get-ScudoControlCatalog
        $controlIds = @($controls | Select-Object -ExpandProperty Id)

        $controlIds.Count | Should -Be ($controlIds | Select-Object -Unique).Count
    }

    It 'defines menu controls 2 through 12' {
        $menuNumbers = @(
            Get-ScudoControlCatalog |
                Where-Object { $null -ne $_.MenuNumber } |
                Select-Object -ExpandProperty MenuNumber
        )

        $menuNumbers | Should -Be @(2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)
    }

    It 'defines section metadata for every control' {
        foreach ($control in Get-ScudoControlCatalog) {
            [string]::IsNullOrWhiteSpace($control.WhatItDoes) | Should -BeFalse
            [string]::IsNullOrWhiteSpace($control.WhyApply) | Should -BeFalse
            [string]::IsNullOrWhiteSpace($control.WhyNotApply) | Should -BeFalse
            [string]::IsNullOrWhiteSpace($control.RecommendationTier) | Should -BeFalse
            [string]::IsNullOrWhiteSpace($control.AutomationLevel) | Should -BeFalse
            [string]::IsNullOrWhiteSpace($control.SectionId) | Should -BeFalse
            [string]::IsNullOrWhiteSpace($control.RollbackNote) | Should -BeFalse
        }
    }

    It 'marks all applyable controls as admin-required' {
        $applyableControls = Get-ScudoControlCatalog | Where-Object { $_.Kind -in @('applyable', 'installable') }
        @($applyableControls | Where-Object { -not $_.RequiresAdmin }).Count | Should -Be 0
    }

    It 'defines the expected installable app controls' {
        $installableIds = @(
            Get-ScudoControlCatalog |
                Where-Object { $_.Kind -eq 'installable' } |
                Select-Object -ExpandProperty Id |
                Sort-Object
        )

        $installableIds | Should -Be @(
            'app.bitwarden',
            'app.firefox',
            'app.helium',
            'app.simplewall'
        )
    }

    It 'defines the researched privacy and browser controls' {
        $controlIds = @(
            Get-ScudoControlCatalog |
                Select-Object -ExpandProperty Id
        )

        @(
            'privacy.telemetry-policy',
            'privacy.telemetry-services',
            'browser.firefox-noscript',
            'browser.firefox-sanitize',
            'account.create-standard-user',
            'app.simplewall-enable-filtering',
            'firmware.reboot-to-uefi'
        ) | ForEach-Object {
            $controlIds | Should -Contain $_
        }
    }

    It 'defines rollback support for the isolated controls only' {
        $rollbackIds = @(
            Get-ScudoControlCatalog |
                Where-Object { Test-ScudoControlRollbackSupported -Control $_ } |
                Select-Object -ExpandProperty Id |
                Sort-Object
        )

        $rollbackIds | Should -Be @(
            'device-install.restrict-new-devices',
            'driver-blocklist',
            'privacy.telemetry-policy',
            'privacy.telemetry-services',
            'service.print-spooler.disabled',
            'service.remote-registry.disabled',
            'vbs.memory-integrity'
        )
    }

    It 'defines the baseline and strict preset control sets' {
        $baselineIds = @(Get-ScudoControlsForPreset -PresetId 'baseline' | Select-Object -ExpandProperty Id)
        $strictIds = @(Get-ScudoControlsForPreset -PresetId 'strict' | Select-Object -ExpandProperty Id)

        $baselineIds | Should -Contain 'mitigation.control-flow-guard'
        $baselineIds | Should -Contain 'vbs.memory-integrity'
        $baselineIds | Should -Not -Contain 'browser.firefox-noscript'
        $strictIds | Should -Contain 'browser.firefox-noscript'
        $strictIds | Should -Contain 'dns.quad9'
        $strictIds | Should -Not -Contain 'app.bitwarden'
    }
}

Describe 'scudo entrypoint parsing' {
    BeforeAll {
        $projectRoot = Split-Path -Parent $PSScriptRoot
        . (Join-Path -Path $projectRoot -ChildPath 'modules/entrypoint.ps1')
    }

    It 'parses gui, cli, preset, and show flags explicitly' {
        $guiArgs = Get-ScudoParsedArguments -Arguments @('--gui')
        $cliArgs = Get-ScudoParsedArguments -Arguments @('--cli')
        $presetArgs = Get-ScudoParsedArguments -Arguments @('--preset', 'baseline')
        $showArgs = Get-ScudoParsedArguments -Arguments @('--show', 'strict')

        $guiArgs.Gui | Should -BeTrue
        $guiArgs.Cli | Should -BeFalse
        $cliArgs.Cli | Should -BeTrue
        $cliArgs.Gui | Should -BeFalse
        $presetArgs.Preset | Should -Be 'baseline'
        $showArgs.Show | Should -Be 'strict'
    }

    It 'launches the GUI only when requested explicitly on Windows' {
        (Test-ScudoShouldLaunchGui -ParsedArguments (Get-ScudoParsedArguments -Arguments @()) -RunningOnWindows $true) | Should -BeFalse
        (Test-ScudoShouldLaunchGui -ParsedArguments (Get-ScudoParsedArguments -Arguments @('--gui')) -RunningOnWindows $true) | Should -BeTrue
        (Test-ScudoShouldLaunchGui -ParsedArguments (Get-ScudoParsedArguments -Arguments @('--cli')) -RunningOnWindows $true) | Should -BeFalse
        (Test-ScudoShouldLaunchGui -ParsedArguments (Get-ScudoParsedArguments -Arguments @('--check-all')) -RunningOnWindows $true) | Should -BeFalse
        (Test-ScudoShouldLaunchGui -ParsedArguments (Get-ScudoParsedArguments -Arguments @('--preset', 'baseline')) -RunningOnWindows $true) | Should -BeFalse
        (Test-ScudoShouldLaunchGui -ParsedArguments (Get-ScudoParsedArguments -Arguments @('--show', 'strict')) -RunningOnWindows $true) | Should -BeFalse
        (Test-ScudoShouldLaunchGui -ParsedArguments (Get-ScudoParsedArguments -Arguments @('--action', 'apply', '--control-id', 'service.remote-registry.disabled')) -RunningOnWindows $true) | Should -BeFalse
        (Test-ScudoShouldLaunchGui -ParsedArguments (Get-ScudoParsedArguments -Arguments @('--gui')) -RunningOnWindows $false) | Should -BeFalse
    }
}

Describe 'scudo reporting' {
    BeforeAll {
        $projectRoot = Split-Path -Parent $PSScriptRoot
        . (Join-Path -Path $projectRoot -ChildPath 'modules/control-actions.ps1')
        . (Join-Path -Path $projectRoot -ChildPath 'modules/safety.ps1')
        . (Join-Path -Path $projectRoot -ChildPath 'modules/control-catalog.ps1')
        . (Join-Path -Path $projectRoot -ChildPath 'modules/reporting.ps1')
    }

    It 'writes both report formats' {
        $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('scudo-tests-' + [guid]::NewGuid().ToString('N'))
        $results = @(
            [pscustomobject]@{
                id                 = 'demo'
                title              = 'Demo control'
                category           = 'Demo'
                kind               = 'manual-only'
                requiresAdmin      = $false
                requiresReboot     = $false
                guidance           = 'demo'
                whatItDoes         = 'demo'
                whyApply           = 'demo'
                whyNotApply        = 'demo'
                recommendationTier = 'guided'
                automationLevel    = 'manual'
                section            = 'identity'
                rollbackNote       = 'demo'
                status             = New-ScudoStatus -State 'advisory' -Summary 'demo'
            }
        )

        $paths = Export-ScudoReport -Results $results -BaseDirectory $tempRoot

        Test-Path -Path $paths.MarkdownPath | Should -BeTrue
        Test-Path -Path $paths.JsonPath | Should -BeTrue
    }
}
