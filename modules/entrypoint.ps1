Set-StrictMode -Version Latest

function Get-ScudoParsedArguments {
    param(
        [string[]]$Arguments
    )

    $parsed = [ordered]@{
        Help      = $false
        Version   = $false
        CheckAll  = $false
        Export    = $false
        Preset    = $null
        Show      = $null
        Action    = $null
        ControlId = $null
        NoPause   = $false
        Gui       = $false
        Cli       = $false
    }

    for ($index = 0; $index -lt $Arguments.Count; $index += 1) {
        switch ($Arguments[$index]) {
            '--help' {
                $parsed.Help = $true
            }
            '-help' {
                $parsed.Help = $true
            }
            '-h' {
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
            '--preset' {
                $index += 1
                $parsed.Preset = $Arguments[$index]
            }
            '--show' {
                $index += 1
                $parsed.Show = $Arguments[$index]
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
            '--gui' {
                $parsed.Gui = $true
            }
            '--cli' {
                $parsed.Cli = $true
            }
        }
    }

    return [pscustomobject]$parsed
}

function Test-ScudoShouldLaunchGui {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$ParsedArguments,

        [bool]$IsWindows = ($env:OS -eq 'Windows_NT')
    )

    if (-not $IsWindows) {
        return $false
    }

    if ($ParsedArguments.Cli) {
        return $false
    }

    if ($ParsedArguments.Help -or $ParsedArguments.Version -or $ParsedArguments.CheckAll -or $ParsedArguments.Export) {
        return $false
    }

    if (-not [string]::IsNullOrWhiteSpace($ParsedArguments.Preset) -or -not [string]::IsNullOrWhiteSpace($ParsedArguments.Show)) {
        return $false
    }

    if (-not [string]::IsNullOrWhiteSpace($ParsedArguments.Action)) {
        return $false
    }

    if ($ParsedArguments.Gui) {
        return $true
    }

    return $true
}
