Set-StrictMode -Version Latest

Describe 'scudo internal helpers' {
    BeforeAll {
        $projectRoot = Split-Path -Parent $PSScriptRoot
        . (Join-Path -Path $projectRoot -ChildPath 'modules/control-actions.ps1')
        . (Join-Path -Path $projectRoot -ChildPath 'modules/safety.ps1')
        . (Join-Path -Path $projectRoot -ChildPath 'modules/control-catalog.ps1')
        . (Join-Path -Path $projectRoot -ChildPath 'modules/reporting.ps1')
    }

    It 'normalizes safe file names and keeps a fallback' {
        (Get-ScudoSafeFileName -Value 'Remote Registry / Control') | Should -Be 'remote-registry-control'
        (Get-ScudoSafeFileName -Value '!!!') | Should -Be 'item'
    }

    It 'writes operation logs and manages the latest rollback snapshot' {
        $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('scudo-state-' + [guid]::NewGuid().ToString('N'))
        $control = Get-ScudoControlCatalog | Where-Object { $_.Id -eq 'service.remote-registry.disabled' }
        $beforeStatus = New-ScudoStatus -State 'needs-action' -Summary 'before' -BeforeValue @{ StartType = 'Manual'; Status = 'Running' }
        $resultStatus = New-ScudoStatus -State 'already-configured' -Summary 'after' -AfterValue @{ StartType = 'Disabled'; Status = 'Stopped' }

        $operationPath = Save-ScudoOperationState -Control $control -Action 'apply' -BeforeStatus $beforeStatus -ResultStatus $resultStatus -BaseDirectory $tempRoot

        Test-Path -Path $operationPath | Should -BeTrue
        $latestSnapshot = Get-ScudoControlSnapshot -ControlId $control.Id -BaseDirectory $tempRoot
        $latestSnapshot.controlId | Should -Be $control.Id
        $latestSnapshot.action | Should -Be 'apply'

        $rollbackStatus = New-ScudoStatus -State 'already-configured' -Summary 'rolled back'
        Save-ScudoOperationState -Control $control -Action 'rollback' -BeforeStatus $resultStatus -ResultStatus $rollbackStatus -BaseDirectory $tempRoot | Out-Null

        $latestAfterRollback = Get-ScudoControlSnapshot -ControlId $control.Id -BaseDirectory $tempRoot
        $latestAfterRollback | Should -Be $null
    }

    It 'prefers a Windows 11 candidate when multiple edition strings disagree' {
        $selected = Get-ScudoPreferredWindowsEdition -Candidates @(
            'Windows 10 IoT Enterprise LTSC 2024 Evaluation'
            'Microsoft Windows 11 IoT Enterprise LTSC Evaluation'
        )

        $selected | Should -Be 'Microsoft Windows 11 IoT Enterprise LTSC Evaluation'
    }
}

Describe 'scudo file-backed browser policies' {
    BeforeAll {
        $projectRoot = Split-Path -Parent $PSScriptRoot
        . (Join-Path -Path $projectRoot -ChildPath 'modules/control-actions.ps1')
        . (Join-Path -Path $projectRoot -ChildPath 'modules/control-catalog.ps1')
        . (Join-Path -Path $projectRoot -ChildPath 'modules/safety.ps1')
    }

    It 'merges Firefox policies without overwriting existing keys' {
        $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('scudo-firefox-' + [guid]::NewGuid().ToString('N'))
        $programFiles = Join-Path -Path $tempRoot -ChildPath 'Program Files'
        $firefoxRoot = Join-Path -Path $programFiles -ChildPath 'Mozilla Firefox'
        $distributionPath = Join-Path -Path $firefoxRoot -ChildPath 'distribution'
        $policyPath = Join-Path -Path $distributionPath -ChildPath 'policies.json'
        $existingProgramFiles = $env:ProgramFiles
        $existingProgramFilesX86 = ${env:ProgramFiles(x86)}

        New-Item -Path $distributionPath -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path -Path $firefoxRoot -ChildPath 'firefox.exe') -ItemType File -Force | Out-Null
        @{
            policies = @{
                Homepage = @{
                    URL = 'https://example.com'
                }
            }
        } | ConvertTo-Json -Depth 6 | Set-Content -Path $policyPath -Encoding UTF8

        try {
            $env:ProgramFiles = $programFiles
            Remove-Item Env:'ProgramFiles(x86)' -ErrorAction SilentlyContinue

            $result = Set-ScudoFirefoxPolicies -InstallNoScript $true -SanitizeCookiesOnShutdown $true
            $policyDocument = Get-ScudoFirefoxPolicyDocument
            $noScriptStatus = Get-ScudoStatusFirefoxNoScript
            $sanitizeStatus = Get-ScudoStatusFirefoxSanitizeOnShutdown

            $result.State | Should -Be 'already-configured'
            $policyDocument.Error | Should -Be $null
            $policyDocument.Data['policies']['Homepage']['URL'] | Should -Be 'https://example.com'
            $policyDocument.Data['policies']['DisableTelemetry'] | Should -BeTrue
            $policyDocument.Data['policies']['DisableFirefoxStudies'] | Should -BeTrue
            $policyDocument.Data['policies']['SanitizeOnShutdown']['Cookies'] | Should -BeTrue
            $policyDocument.Data['policies']['ExtensionSettings']['{73a6fe31-595d-460b-a920-fcc0f8843232}']['installation_mode'] | Should -Be 'force_installed'
            $noScriptStatus.State | Should -Be 'already-configured'
            $sanitizeStatus.State | Should -Be 'already-configured'
        }
        finally {
            $env:ProgramFiles = $existingProgramFiles
            if ($null -eq $existingProgramFilesX86) {
                Remove-Item Env:'ProgramFiles(x86)' -ErrorAction SilentlyContinue
            }
            else {
                ${env:ProgramFiles(x86)} = $existingProgramFilesX86
            }
        }
    }

    It 'persists browser operation state without serializing full policy payloads' {
        $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('scudo-firefox-state-' + [guid]::NewGuid().ToString('N'))
        $programFiles = Join-Path -Path $tempRoot -ChildPath 'Program Files'
        $firefoxRoot = Join-Path -Path $programFiles -ChildPath 'Mozilla Firefox'
        $existingProgramFiles = $env:ProgramFiles
        $existingProgramFilesX86 = ${env:ProgramFiles(x86)}
        $stateRoot = Join-Path -Path $tempRoot -ChildPath 'state'
        $control = $null

        New-Item -Path $firefoxRoot -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path -Path $firefoxRoot -ChildPath 'firefox.exe') -ItemType File -Force | Out-Null

        try {
            $env:ProgramFiles = $programFiles
            Remove-Item Env:'ProgramFiles(x86)' -ErrorAction SilentlyContinue
            $control = Get-ScudoControlCatalog | Where-Object { $_.Id -eq 'browser.firefox-noscript' }

            $beforeStatus = Get-ScudoStatusFirefoxNoScript
            $result = Set-ScudoFirefoxNoScript
            $operationPath = Save-ScudoOperationState -Control $control -Action 'apply' -BeforeStatus $beforeStatus -ResultStatus $result -BaseDirectory $stateRoot
            $savedOperation = Get-Content -Path $operationPath -Raw | ConvertFrom-Json

            $beforeStatus.BeforeValue | Should -Be $null
            $result.BeforeValue | Should -Be (Join-Path -Path $firefoxRoot -ChildPath 'distribution\policies.json')
            $result.AfterValue | Should -Be (Join-Path -Path $firefoxRoot -ChildPath 'distribution\policies.json')
            Test-Path -Path $operationPath | Should -BeTrue
            $savedOperation.controlId | Should -Be 'browser.firefox-noscript'
        }
        finally {
            $env:ProgramFiles = $existingProgramFiles
            if ($null -eq $existingProgramFilesX86) {
                Remove-Item Env:'ProgramFiles(x86)' -ErrorAction SilentlyContinue
            }
            else {
                ${env:ProgramFiles(x86)} = $existingProgramFilesX86
            }
        }
    }
}

Describe 'scudo file-backed app helpers' -Skip:($env:OS -eq 'Windows_NT') {
    BeforeAll {
        $projectRoot = Split-Path -Parent $PSScriptRoot
        . (Join-Path -Path $projectRoot -ChildPath 'modules/control-actions.ps1')
    }

    It 'detects and enables SimpleWall filtering through the discovered executable path' {
        $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('scudo-simplewall-' + [guid]::NewGuid().ToString('N'))
        $programFiles = Join-Path -Path $tempRoot -ChildPath 'Program Files'
        $simpleWallRoot = Join-Path -Path $programFiles -ChildPath 'simplewall'
        $simpleWallPath = Join-Path -Path $simpleWallRoot -ChildPath 'simplewall.exe'
        $argLogPath = Join-Path -Path $tempRoot -ChildPath 'simplewall-args.txt'
        $existingProgramFiles = $env:ProgramFiles
        $existingProgramFilesX86 = ${env:ProgramFiles(x86)}

        New-Item -Path $simpleWallRoot -ItemType Directory -Force | Out-Null
        @(
            '#!/bin/sh'
            ('printf ''%s\n'' "$@" > "{0}"' -f $argLogPath)
        ) | Set-Content -Path $simpleWallPath -Encoding UTF8

        try {
            $env:ProgramFiles = $programFiles
            Remove-Item Env:'ProgramFiles(x86)' -ErrorAction SilentlyContinue
            chmod +x $simpleWallPath

            $status = Get-ScudoStatusSimpleWallFiltering
            $result = Set-ScudoSimpleWallFiltering
            $argsWritten = Get-Content -Path $argLogPath

            $status.State | Should -Be 'advisory'
            $result.State | Should -Be 'already-configured'
            $argsWritten | Should -Be @('-install', '-silent')
        }
        finally {
            $env:ProgramFiles = $existingProgramFiles
            if ($null -eq $existingProgramFilesX86) {
                Remove-Item Env:'ProgramFiles(x86)' -ErrorAction SilentlyContinue
            }
            else {
                ${env:ProgramFiles(x86)} = $existingProgramFilesX86
            }
        }
    }
}

Describe 'scudo non-windows fallback behavior' -Skip:($env:OS -eq 'Windows_NT') {
    BeforeAll {
        $projectRoot = Split-Path -Parent $PSScriptRoot
        . (Join-Path -Path $projectRoot -ChildPath 'modules/control-actions.ps1')
    }

    It 'treats Windows-only registry checks as unsupported' {
        (Get-ScudoStatusMemoryIntegrity).State | Should -Be 'unsupported'
        (Get-ScudoStatusDriverBlocklist).State | Should -Be 'unsupported'
        (Get-ScudoStatusDeviceInstallRestriction).State | Should -Be 'unsupported'
        (Get-ScudoStatusTelemetryPolicy).State | Should -Be 'unsupported'
    }

    It 'treats unavailable service and app checks as unsupported instead of throwing' {
        (Get-ScudoStatusRemoteRegistry).State | Should -Be 'unsupported'
        (Get-ScudoStatusTelemetryServices).State | Should -Be 'unsupported'
        (Get-ScudoStatusSimpleWallFiltering).State | Should -Be 'unsupported'
        (Get-ScudoStatusFirefoxNoScript).State | Should -Be 'unsupported'
        (Get-ScudoStatusFirefoxSanitizeOnShutdown).State | Should -Be 'unsupported'
    }
}
