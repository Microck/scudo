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
$script:ScudoShellPath = if ($script:IsWindowsHost -and (Get-Command -Name 'powershell.exe' -ErrorAction SilentlyContinue)) {
    (Get-Command -Name 'powershell.exe' -ErrorAction Stop).Source
}
elseif (Get-Command -Name 'pwsh' -ErrorAction SilentlyContinue) {
    (Get-Command -Name 'pwsh' -ErrorAction Stop).Source
}
else {
    throw 'No PowerShell executable is available for CLI tests.'
}

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

$script:ScudoShellArgs = @('-NoProfile')
$shellLeaf = Split-Path -Leaf $script:ScudoShellPath
if ($shellLeaf -ieq 'powershell.exe' -or $shellLeaf -ieq 'powershell') {
    $script:ScudoShellArgs += @('-ExecutionPolicy', 'Bypass')
}

$script:ScudoShellArgs += @('-File', $script:ScudoScriptPath)

Describe 'scudo cli surface' {
    It 'shows help without requiring Windows 11' {
        $output = & $script:ScudoShellPath @script:ScudoShellArgs '--help' 2>&1 | Out-String
        $result = [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output   = $output.TrimEnd()
        }

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'scudo usage'
        $result.Output | Should -Match 'scudo --action apply --control-id <id>'
    }

    It 'prints the scripted version without requiring Windows 11' {
        $output = & $script:ScudoShellPath @script:ScudoShellArgs '--version' 2>&1 | Out-String
        $result = [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output   = $output.TrimEnd()
        }

        $result.ExitCode | Should -Be 0
        $result.Output.Trim() | Should -Be $script:ScudoVersion
    }
}

Describe 'scudo platform guardrails' {
    It 'rejects non-Windows hosts explicitly' -Skip:$script:IsWindowsHost {
        $output = & $script:ScudoShellPath @script:ScudoShellArgs '--check-all' 2>&1 | Out-String
        $result = [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output   = $output.TrimEnd()
        }

        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'scudo only runs on Windows 11\.'
    }

    It 'rejects Windows hosts that are not Windows 11 explicitly' -Skip:(-not $script:IsWindowsHost -or $script:IsWindows11) {
        $output = & $script:ScudoShellPath @script:ScudoShellArgs '--check-all' 2>&1 | Out-String
        $result = [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output   = $output.TrimEnd()
        }

        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'scudo only supports Windows 11\.'
    }
}
