Set-StrictMode -Version Latest

function Get-ScudoReportDirectory {
    param(
        [string]$BaseDirectory
    )

    if (-not [string]::IsNullOrWhiteSpace($BaseDirectory)) {
        return $BaseDirectory
    }

    $documentsRoot = if (Test-ScudoWindows) {
        Join-Path -Path $env:USERPROFILE -ChildPath 'Documents'
    }
    else {
        $PWD.Path
    }

    return Join-Path -Path $documentsRoot -ChildPath 'Scudo\Reports'
}

function New-ScudoReportPayload {
    param(
        [Parameter(Mandatory)]
        [array]$Results
    )

    return [pscustomobject]@{
        generatedAt = (Get-Date).ToString('o')
        machineName = $env:COMPUTERNAME
        userName    = $env:USERNAME
        scudoVersion = '0.2.0'
        results     = $Results
    }
}

function ConvertTo-ScudoMarkdown {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Payload
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Scudo Report')
    $lines.Add('')
    $lines.Add("Generated: $($Payload.generatedAt)")
    $lines.Add("Machine: $($Payload.machineName)")
    $lines.Add("User: $($Payload.userName)")
    $lines.Add('')
    $lines.Add('## Summary')
    $lines.Add('')

    foreach ($state in 'already-configured', 'needs-action', 'pending-reboot', 'advisory', 'unsupported', 'error') {
        $count = @($Payload.results | Where-Object { $_.status.State -eq $state }).Count
        $lines.Add(('- {0}: {1}' -f $state, $count))
    }

    $lines.Add('')
    $lines.Add('## Controls')
    $lines.Add('')

    foreach ($entry in $Payload.results | Sort-Object title) {
        $rollbackSupported = $false
        if ($null -ne $entry.PSObject.Properties['rollbackSupported']) {
            $rollbackSupported = [bool]$entry.rollbackSupported
        }

        $lines.Add("### $($entry.title)")
        $lines.Add('')
        $lines.Add(('- id: `{0}`' -f $entry.id))
        $lines.Add(('- section: `{0}`' -f $entry.transcriptSection))
        $lines.Add(('- tier: `{0}`' -f $entry.recommendationTier))
        $lines.Add(('- automation: `{0}`' -f $entry.automationLevel))
        $lines.Add(('- kind: `{0}`' -f $entry.kind))
        $lines.Add(('- state: `{0}`' -f $entry.status.State))
        $lines.Add(('- rollback-supported: `{0}`' -f $rollbackSupported))
        $lines.Add("- rollback-note: $($entry.rollbackNote)")
        $lines.Add("- summary: $($entry.status.Summary)")
        $lines.Add("- what-it-does: $($entry.whatItDoes)")
        $lines.Add("- why-apply: $($entry.whyApply)")
        $lines.Add("- why-not-apply: $($entry.whyNotApply)")
        $lines.Add(('- requires-admin: `{0}`' -f $entry.requiresAdmin))
        $lines.Add(('- requires-reboot: `{0}`' -f $entry.requiresReboot))

        if ($null -ne $entry.status.BeforeValue) {
            $beforeJson = $entry.status.BeforeValue | ConvertTo-Json -Depth 6 -Compress
            $lines.Add(('- before: `{0}`' -f $beforeJson))
        }

        if ($null -ne $entry.status.AfterValue) {
            $afterJson = $entry.status.AfterValue | ConvertTo-Json -Depth 6 -Compress
            $lines.Add(('- after: `{0}`' -f $afterJson))
        }

        if (@($entry.status.Notes).Count -gt 0) {
            foreach ($note in @($entry.status.Notes)) {
                $lines.Add("- note: $note")
            }
        }

        $lines.Add('')
    }

    return ($lines -join [Environment]::NewLine)
}

function Export-ScudoReport {
    param(
        [Parameter(Mandatory)]
        [array]$Results,

        [string]$BaseDirectory
    )

    $reportDirectory = Get-ScudoReportDirectory -BaseDirectory $BaseDirectory
    New-Item -Path $reportDirectory -ItemType Directory -Force | Out-Null

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $basePath = Join-Path -Path $reportDirectory -ChildPath "scudo-$stamp"
    $jsonPath = "$basePath.json"
    $markdownPath = "$basePath.md"

    $payload = New-ScudoReportPayload -Results $Results
    $payload | ConvertTo-Json -Depth 8 | Set-Content -Path $jsonPath -Encoding UTF8
    ConvertTo-ScudoMarkdown -Payload $payload | Set-Content -Path $markdownPath -Encoding UTF8

    return [pscustomobject]@{
        JsonPath     = $jsonPath
        MarkdownPath = $markdownPath
    }
}
