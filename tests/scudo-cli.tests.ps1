Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$script:ScudoScriptPath = Join-Path -Path $projectRoot -ChildPath 'scudo.ps1'
$script:ScudoScriptText = Get-Content -Path $script:ScudoScriptPath -Raw
$versionMatch = [regex]::Match($script:ScudoScriptText, '\$script:ScudoVersion = ''([^'']+)''')
if (-not $versionMatch.Success) {
    throw 'Could not find the scripted Scudo version in scudo.ps1.'
}

$script:ScudoVersion = $versionMatch.Groups[1].Value
$script:IsWindowsHost = $env:OS -eq 'Windows_NT'

$script:IsWindows11 = $false
if ($script:IsWindowsHost) {
    try {
        $productName = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'ProductName' -ErrorAction Stop
        $script:IsWindows11 = $productName -match 'Windows 11'
    }
    catch {
        $script:IsWindows11 = $false
    }
}

function Invoke-ScudoCli {
    param(
        [Parameter(Mandatory)]
        [string]$ShellPath,

        [Parameter(Mandatory)]
        [string[]]$ShellArgs,

        [Parameter(Mandatory)]
        [string]$ScriptPath,

        [string[]]$Arguments
    )

    $commandParts = @('&', ("'{0}'" -f $ScriptPath.Replace("'", "''")))
    foreach ($argument in $Arguments) {
        $commandParts += ("'{0}'" -f $argument.Replace("'", "''"))
    }

    $commandText = '& { ' + ($commandParts -join ' ') + ' }'
    $output = & $ShellPath @ShellArgs -Command $commandText 2>&1 | Out-String
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output   = $output.TrimEnd()
    }
}

Describe 'scudo cli surface' {
    BeforeAll {
        $script:RuntimeScudoScriptPath = Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'scudo.ps1'
        $script:RuntimeScudoVersion = $script:ScudoVersion
        $script:RuntimeScudoShellPath = if ($env:OS -eq 'Windows_NT' -and (Get-Command -Name 'powershell.exe' -ErrorAction SilentlyContinue)) {
            (Get-Command -Name 'powershell.exe' -ErrorAction Stop).Source
        }
        elseif (Get-Command -Name 'pwsh' -ErrorAction SilentlyContinue) {
            (Get-Command -Name 'pwsh' -ErrorAction Stop).Source
        }
        else {
            throw 'No PowerShell executable is available for CLI tests.'
        }

        $script:RuntimeScudoShellArgs = @('-NoProfile')
        $shellLeaf = Split-Path -Leaf $script:RuntimeScudoShellPath
        if ($shellLeaf -ieq 'powershell.exe' -or $shellLeaf -ieq 'powershell') {
            $script:RuntimeScudoShellArgs += @('-ExecutionPolicy', 'Bypass')
        }
    }

    It 'shows help without requiring Windows 11' {
        $result = Invoke-ScudoCli -ShellPath $script:RuntimeScudoShellPath -ShellArgs $script:RuntimeScudoShellArgs -ScriptPath $script:RuntimeScudoScriptPath -Arguments @('-help')

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'scudo usage'
        $result.Output | Should -Match 'scudo --action apply --control-id <id>'
    }

    It 'prints the scripted version without requiring Windows 11' {
        $result = Invoke-ScudoCli -ShellPath $script:RuntimeScudoShellPath -ShellArgs $script:RuntimeScudoShellArgs -ScriptPath $script:RuntimeScudoScriptPath -Arguments @('--version')
        $expectedVersion = ([regex]::Match((Get-Content -Path $script:RuntimeScudoScriptPath -Raw), '\$script:ScudoVersion = ''([^'']+)''')).Groups[1].Value

        $result.ExitCode | Should -Be 0
        $result.Output.Trim() | Should -Be $expectedVersion
    }
}

Describe 'scudo platform guardrails' {
    BeforeAll {
        $script:RuntimeScudoScriptPath = Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'scudo.ps1'
        $script:RuntimeScudoShellPath = if ($env:OS -eq 'Windows_NT' -and (Get-Command -Name 'powershell.exe' -ErrorAction SilentlyContinue)) {
            (Get-Command -Name 'powershell.exe' -ErrorAction Stop).Source
        }
        elseif (Get-Command -Name 'pwsh' -ErrorAction SilentlyContinue) {
            (Get-Command -Name 'pwsh' -ErrorAction Stop).Source
        }
        else {
            throw 'No PowerShell executable is available for CLI tests.'
        }

        $script:RuntimeScudoShellArgs = @('-NoProfile')
        $shellLeaf = Split-Path -Leaf $script:RuntimeScudoShellPath
        if ($shellLeaf -ieq 'powershell.exe' -or $shellLeaf -ieq 'powershell') {
            $script:RuntimeScudoShellArgs += @('-ExecutionPolicy', 'Bypass')
        }
    }

    It 'rejects non-Windows hosts explicitly' -Skip:$script:IsWindowsHost {
        $result = Invoke-ScudoCli -ShellPath $script:RuntimeScudoShellPath -ShellArgs $script:RuntimeScudoShellArgs -ScriptPath $script:RuntimeScudoScriptPath -Arguments @('--check-all')

        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'scudo only runs on Windows 11\.'
    }

    It 'rejects Windows hosts that are not Windows 11 explicitly' -Skip:(-not $script:IsWindowsHost -or $script:IsWindows11) {
        $result = Invoke-ScudoCli -ShellPath $script:RuntimeScudoShellPath -ShellArgs $script:RuntimeScudoShellArgs -ScriptPath $script:RuntimeScudoScriptPath -Arguments @('--check-all')

        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'scudo only supports Windows 11\.'
    }
}
