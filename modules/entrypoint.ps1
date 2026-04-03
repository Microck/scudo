Set-StrictMode -Version Latest

function Get-ScudoParsedArguments {
    param(
        [string[]]$Arguments = @()
    )

    $argumentsList = New-Object System.Collections.Generic.List[string]
    foreach ($argument in $Arguments) {
        if ($null -ne $argument) {
            $argumentsList.Add([string]$argument)
        }
    }

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

    for ($index = 0; $index -lt $argumentsList.Count; $index += 1) {
        switch ($argumentsList[$index]) {
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
                $parsed.Preset = $argumentsList[$index]
            }
            '--show' {
                $index += 1
                $parsed.Show = $argumentsList[$index]
            }
            '--action' {
                $index += 1
                $parsed.Action = $argumentsList[$index]
            }
            '--control-id' {
                $index += 1
                $parsed.ControlId = $argumentsList[$index]
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

        [bool]$RunningOnWindows = ($env:OS -eq 'Windows_NT')
    )

    if (-not $RunningOnWindows) {
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

    return [bool]$ParsedArguments.Gui
}
