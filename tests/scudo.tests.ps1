Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot

Describe 'scudo control catalog' {
    BeforeAll {
        . (Join-Path -Path $projectRoot -ChildPath 'modules/control-actions.ps1')
        . (Join-Path -Path $projectRoot -ChildPath 'modules/safety.ps1')
        . (Join-Path -Path $projectRoot -ChildPath 'modules/control-catalog.ps1')
        . (Join-Path -Path $projectRoot -ChildPath 'modules/reporting.ps1')
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
}

Describe 'scudo reporting' {
    BeforeAll {
        . (Join-Path -Path $projectRoot -ChildPath 'modules/control-actions.ps1')
        . (Join-Path -Path $projectRoot -ChildPath 'modules/safety.ps1')
        . (Join-Path -Path $projectRoot -ChildPath 'modules/control-catalog.ps1')
        . (Join-Path -Path $projectRoot -ChildPath 'modules/reporting.ps1')
    }

    It 'writes both report formats' {
        $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('scudo-tests-' + [guid]::NewGuid().ToString('N'))
        $results = @(
            [pscustomobject]@{
                id             = 'demo'
                title          = 'Demo control'
                category       = 'Demo'
                kind           = 'manual-only'
                requiresAdmin  = $false
                requiresReboot = $false
                guidance       = 'demo'
                status         = New-ScudoStatus -State 'advisory' -Summary 'demo'
            }
        )

        $paths = Export-ScudoReport -Results $results -BaseDirectory $tempRoot

        Test-Path -Path $paths.MarkdownPath | Should -BeTrue
        Test-Path -Path $paths.JsonPath | Should -BeTrue
    }
}
