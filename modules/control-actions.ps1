Set-StrictMode -Version Latest

$script:ScudoAsrRules = @{
    'defender.asr.office-child-process' = @{
        Id    = 'D4F940AB-401B-4EFC-AADC-AD5F3C50688A'
        Title = 'ASR: Block Office child processes'
    }
    'defender.asr.obfuscated-scripts'   = @{
        Id    = '5BEB7EFE-FD9A-4556-801D-275E5FFC04CC'
        Title = 'ASR: Block obfuscated scripts'
    }
    'defender.asr.email-executable-content' = @{
        Id    = 'BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550'
        Title = 'ASR: Block executable email content'
    }
}

function Test-ScudoWindows {
    return $env:OS -eq 'Windows_NT'
}

function Test-ScudoAdministrator {
    if (-not (Test-ScudoWindows)) {
        return $false
    }

    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-ScudoCommandAvailable {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    return $null -ne (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Test-ScudoWingetAvailable {
    return Test-ScudoCommandAvailable -Name 'winget'
}

function Get-ScudoWindowsEdition {
    if (-not (Test-ScudoWindows)) {
        return $null
    }

    try {
        $productName = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'ProductName' -ErrorAction Stop
        return [string]$productName
    }
    catch {
        return $null
    }
}

function Test-ScudoWindows11 {
    $edition = Get-ScudoWindowsEdition
    return $edition -match 'Windows 11'
}

function New-ScudoStatus {
    param(
        [Parameter(Mandatory)]
        [string]$State,

        [Parameter(Mandatory)]
        [string]$Summary,

        [bool]$Supported = $true,
        [bool]$RequiresReboot = $false,
        [object]$BeforeValue = $null,
        [object]$AfterValue = $null,
        [string[]]$Notes = @()
    )

    return [pscustomobject]@{
        State          = $State
        Summary        = $Summary
        Supported      = $Supported
        RequiresReboot = $RequiresReboot
        BeforeValue    = $BeforeValue
        AfterValue     = $AfterValue
        Notes          = $Notes
    }
}

function Get-ScudoRegistryDword {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if (-not (Test-Path -Path $Path)) {
        return $null
    }

    $item = Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue
    if ($null -eq $item) {
        return $null
    }

    $property = $item.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return [int]$property.Value
}

function Set-ScudoRegistryDword {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [int]$Value
    )

    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null
}

function Restore-ScudoRegistryDword {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name,

        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        if (Test-Path -Path $Path) {
            Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        }

        return
    }

    Set-ScudoRegistryDword -Path $Path -Name $Name -Value ([int]$Value)
}

function Get-ScudoSimpleWallExecutablePath {
    $candidates = @(
        (Join-Path -Path ${env:ProgramFiles} -ChildPath 'simplewall\simplewall.exe'),
        (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'simplewall\simplewall.exe')
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($candidate in $candidates) {
        if (Test-Path -Path $candidate) {
            return $candidate
        }
    }

    return $null
}

function Get-ScudoFirefoxInstallPath {
    $candidates = @(
        (Join-Path -Path ${env:ProgramFiles} -ChildPath 'Mozilla Firefox'),
        (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Mozilla Firefox')
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($candidate in $candidates) {
        if (Test-Path -Path (Join-Path -Path $candidate -ChildPath 'firefox.exe')) {
            return $candidate
        }
    }

    return $null
}

function Get-ScudoActiveAdapterAliases {
    if (-not (Test-ScudoCommandAvailable -Name 'Get-NetAdapter')) {
        return @()
    }

    $adapters = Get-NetAdapter -ErrorAction Stop |
        Where-Object {
            $_.Status -eq 'Up' -and $_.InterfaceDescription -notmatch 'Loopback|Virtual'
        }

    return @($adapters | Select-Object -ExpandProperty Name)
}

function Get-ScudoStatusControlFlowGuard {
    if (-not (Test-ScudoCommandAvailable -Name 'Get-ProcessMitigation')) {
        return New-ScudoStatus -State 'unsupported' -Summary 'Process mitigation cmdlets are unavailable.' -Supported $false
    }

    try {
        $mitigationText = Get-ProcessMitigation -System | Out-String
        $isEnabled = $mitigationText -match '(?im)CFG.*ON|Control Flow Guard.*ON'
        $summary = if ($isEnabled) { 'Control Flow Guard appears enabled at the system level.' } else { 'Control Flow Guard does not appear enabled at the system level.' }
        $state = if ($isEnabled) { 'already-configured' } else { 'needs-action' }

        return New-ScudoStatus -State $state -Summary $summary -BeforeValue $mitigationText.Trim()
    }
    catch {
        return New-ScudoStatus -State 'error' -Summary "Failed to read CFG state: $($_.Exception.Message)" -Supported $false
    }
}

function Set-ScudoControlFlowGuard {
    Set-ProcessMitigation -System -Enable CFG | Out-Null
    $status = Get-ScudoStatusControlFlowGuard
    return New-ScudoStatus -State $status.State -Summary 'Enabled Control Flow Guard at the system level.' -BeforeValue $status.BeforeValue -AfterValue $status.BeforeValue
}

function Get-ScudoAsrPreferenceMap {
    $preference = Get-MpPreference
    $ruleMap = [ordered]@{}

    $ids = @($preference.AttackSurfaceReductionRules_Ids)
    $actions = @($preference.AttackSurfaceReductionRules_Actions)

    for ($index = 0; $index -lt $ids.Count; $index += 1) {
        if ($index -lt $actions.Count) {
            $ruleMap[$ids[$index]] = $actions[$index]
        }
    }

    return $ruleMap
}

function Get-ScudoStatusAsrRule {
    param(
        [Parameter(Mandatory)]
        [string]$ControlId
    )

    if (-not (Test-ScudoCommandAvailable -Name 'Get-MpPreference')) {
        return New-ScudoStatus -State 'unsupported' -Summary 'Microsoft Defender PowerShell cmdlets are unavailable.' -Supported $false
    }

    $ruleId = $script:ScudoAsrRules[$ControlId].Id
    $ruleMap = Get-ScudoAsrPreferenceMap
    $currentValue = $ruleMap[$ruleId]
    $isEnabled = $currentValue -in @('Enabled', '1', 1)
    $summary = if ($isEnabled) { "$ruleId is enabled." } else { "$ruleId is not enabled." }
    $state = if ($isEnabled) { 'already-configured' } else { 'needs-action' }

    return New-ScudoStatus -State $state -Summary $summary -BeforeValue $currentValue
}

function Set-ScudoAsrRule {
    param(
        [Parameter(Mandatory)]
        [string]$ControlId
    )

    $ruleId = $script:ScudoAsrRules[$ControlId].Id
    $ruleMap = Get-ScudoAsrPreferenceMap
    $beforeValue = $ruleMap[$ruleId]
    $ruleMap[$ruleId] = 'Enabled'

    $ids = @($ruleMap.Keys)
    $actions = foreach ($id in $ids) { $ruleMap[$id] }

    Set-MpPreference -AttackSurfaceReductionRules_Ids $ids -AttackSurfaceReductionRules_Actions $actions | Out-Null

    $status = Get-ScudoStatusAsrRule -ControlId $ControlId
    return New-ScudoStatus -State $status.State -Summary "Enabled $($script:ScudoAsrRules[$ControlId].Title)." -BeforeValue $beforeValue -AfterValue 'Enabled'
}

function Get-ScudoStatusMemoryIntegrity {
    $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'
    $enabled = Get-ScudoRegistryDword -Path $path -Name 'Enabled'
    $isEnabled = $enabled -eq 1
    $state = if ($isEnabled) { 'already-configured' } else { 'needs-action' }
    $summary = if ($isEnabled) { 'Memory integrity is enabled.' } else { 'Memory integrity is disabled.' }

    return New-ScudoStatus -State $state -Summary $summary -RequiresReboot (-not $isEnabled) -BeforeValue $enabled
}

function Set-ScudoMemoryIntegrity {
    $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'
    $beforeValue = Get-ScudoRegistryDword -Path $path -Name 'Enabled'
    Set-ScudoRegistryDword -Path $path -Name 'Enabled' -Value 1

    return New-ScudoStatus -State 'pending-reboot' -Summary 'Enabled memory integrity. Restart Windows to complete the change.' -RequiresReboot $true -BeforeValue $beforeValue -AfterValue 1
}

function Get-ScudoStatusDriverBlocklist {
    $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Config'
    $enabled = Get-ScudoRegistryDword -Path $path -Name 'VulnerableDriverBlocklistEnable'
    $isEnabled = $enabled -eq 1
    $state = if ($isEnabled) { 'already-configured' } else { 'needs-action' }
    $summary = if ($isEnabled) { 'The vulnerable driver blocklist is enabled.' } else { 'The vulnerable driver blocklist is disabled.' }

    return New-ScudoStatus -State $state -Summary $summary -RequiresReboot (-not $isEnabled) -BeforeValue $enabled
}

function Set-ScudoDriverBlocklist {
    $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Config'
    $beforeValue = Get-ScudoRegistryDword -Path $path -Name 'VulnerableDriverBlocklistEnable'
    Set-ScudoRegistryDword -Path $path -Name 'VulnerableDriverBlocklistEnable' -Value 1

    return New-ScudoStatus -State 'pending-reboot' -Summary 'Enabled the vulnerable driver blocklist. Restart Windows to complete the change.' -RequiresReboot $true -BeforeValue $beforeValue -AfterValue 1
}

function Get-ScudoStatusQuad9Dns {
    if (-not (Test-ScudoCommandAvailable -Name 'Get-DnsClientServerAddress')) {
        return New-ScudoStatus -State 'unsupported' -Summary 'DNS client cmdlets are unavailable.' -Supported $false
    }

    $expected = @('9.9.9.9', '149.112.112.112')
    $aliases = Get-ScudoActiveAdapterAliases
    if ($aliases.Count -eq 0) {
        return New-ScudoStatus -State 'advisory' -Summary 'No active physical adapters were found.' -Supported $false
    }

    $results = foreach ($alias in $aliases) {
        Get-DnsClientServerAddress -InterfaceAlias $alias -AddressFamily IPv4 -ErrorAction SilentlyContinue
    }

    $allMatch = $true
    $expectedSignature = $expected -join ','
    foreach ($result in $results) {
        $currentSignature = if ($null -eq $result) { '' } else { (@($result.ServerAddresses) -join ',') }
        if ($currentSignature -ne $expectedSignature) {
            $allMatch = $false
        }
    }

    $state = if ($allMatch) { 'already-configured' } else { 'needs-action' }
    $summary = if ($allMatch) { 'Quad9 IPv4 DNS is configured on active adapters.' } else { 'Active adapters are not fully configured for Quad9 IPv4 DNS.' }
    return New-ScudoStatus -State $state -Summary $summary -BeforeValue $results
}

function Set-ScudoQuad9Dns {
    $aliases = Get-ScudoActiveAdapterAliases
    $beforeValue = foreach ($alias in $aliases) {
        Get-DnsClientServerAddress -InterfaceAlias $alias -AddressFamily IPv4 -ErrorAction SilentlyContinue
    }

    foreach ($alias in $aliases) {
        Set-DnsClientServerAddress -InterfaceAlias $alias -ServerAddresses @('9.9.9.9', '149.112.112.112') -ErrorAction Stop | Out-Null
    }

    return New-ScudoStatus -State 'already-configured' -Summary 'Configured Quad9 IPv4 DNS on active adapters.' -BeforeValue $beforeValue -AfterValue @('9.9.9.9', '149.112.112.112')
}

function Get-ScudoStatusDnsOverHttps {
    if (-not (Test-ScudoCommandAvailable -Name 'Get-DnsClientDohServerAddress')) {
        return New-ScudoStatus -State 'unsupported' -Summary 'DNS-over-HTTPS cmdlets are unavailable.' -Supported $false
    }

    $servers = Get-DnsClientDohServerAddress -ErrorAction SilentlyContinue
    $quad9Servers = $servers | Where-Object { $_.ServerAddress -in @('9.9.9.9', '149.112.112.112') }
    $isConfigured = ($quad9Servers.Count -ge 2) -and ($quad9Servers | Where-Object { $_.AutoUpgrade -and -not $_.AllowFallbackToUdp }).Count -ge 2
    $state = if ($isConfigured) { 'already-configured' } else { 'needs-action' }
    $summary = if ($isConfigured) { 'Quad9 DNS-over-HTTPS is configured.' } else { 'Quad9 DNS-over-HTTPS is not configured.' }

    return New-ScudoStatus -State $state -Summary $summary -BeforeValue $quad9Servers
}

function Set-ScudoDnsOverHttps {
    foreach ($serverAddress in @('9.9.9.9', '149.112.112.112')) {
        if (Test-ScudoCommandAvailable -Name 'Add-DnsClientDohServerAddress') {
            $existing = Get-DnsClientDohServerAddress -ServerAddress $serverAddress -ErrorAction SilentlyContinue
            if ($null -eq $existing) {
                Add-DnsClientDohServerAddress -ServerAddress $serverAddress -DohTemplate 'https://dns.quad9.net/dns-query' -AutoUpgrade $true -AllowFallbackToUdp $false | Out-Null
            }
        }

        Set-DnsClientDohServerAddress -ServerAddress $serverAddress -DohTemplate 'https://dns.quad9.net/dns-query' -AutoUpgrade $true -AllowFallbackToUdp $false | Out-Null
    }

    return New-ScudoStatus -State 'already-configured' -Summary 'Configured Quad9 DNS-over-HTTPS for the standard IPv4 servers.' -AfterValue 'https://dns.quad9.net/dns-query'
}

function Get-ScudoServiceControlStatus {
    param(
        [Parameter(Mandatory)]
        [string]$ServiceName
    )

    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($null -eq $service) {
        return New-ScudoStatus -State 'unsupported' -Summary "$ServiceName is unavailable on this system." -Supported $false
    }

    $isDisabled = $service.StartType -eq 'Disabled'
    $summary = if ($isDisabled) { "$ServiceName is disabled." } else { "$ServiceName is not disabled." }
    $state = if ($isDisabled) { 'already-configured' } else { 'needs-action' }

    return New-ScudoStatus -State $state -Summary $summary -BeforeValue @{
        Status    = $service.Status.ToString()
        StartType = $service.StartType.ToString()
    }
}

function Set-ScudoServiceDisabled {
    param(
        [Parameter(Mandatory)]
        [string]$ServiceName
    )

    $service = Get-Service -Name $ServiceName -ErrorAction Stop
    $beforeValue = @{
        Status    = $service.Status.ToString()
        StartType = $service.StartType.ToString()
    }

    if ($service.Status -ne 'Stopped') {
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
    }

    Set-Service -Name $ServiceName -StartupType Disabled -ErrorAction Stop

    return New-ScudoStatus -State 'already-configured' -Summary "Disabled $ServiceName." -BeforeValue $beforeValue -AfterValue @{
        Status    = 'Stopped'
        StartType = 'Disabled'
    }
}

function Restore-ScudoServiceState {
    param(
        [Parameter(Mandatory)]
        [string]$ServiceName,

        [Parameter(Mandatory)]
        [pscustomobject]$Snapshot
    )

    $beforeValue = $Snapshot.beforeStatus.BeforeValue
    if ($null -eq $beforeValue) {
        return New-ScudoStatus -State 'error' -Summary "No saved state exists for $ServiceName." -Supported $false
    }

    $service = Get-Service -Name $ServiceName -ErrorAction Stop

    if ($service.Status -ne 'Stopped') {
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
    }

    Set-Service -Name $ServiceName -StartupType $beforeValue.StartType -ErrorAction Stop

    if ($beforeValue.Status -eq 'Running') {
        Start-Service -Name $ServiceName -ErrorAction SilentlyContinue
    }

    return New-ScudoStatus -State 'already-configured' -Summary "Restored $ServiceName to its saved state." -BeforeValue @{
        Status    = $service.Status.ToString()
        StartType = $service.StartType.ToString()
    } -AfterValue $beforeValue
}

function Get-ScudoStatusRemoteRegistry {
    return Get-ScudoServiceControlStatus -ServiceName 'RemoteRegistry'
}

function Set-ScudoRemoteRegistryDisabled {
    return Set-ScudoServiceDisabled -ServiceName 'RemoteRegistry'
}

function Get-ScudoStatusPrintSpooler {
    return Get-ScudoServiceControlStatus -ServiceName 'Spooler'
}

function Set-ScudoPrintSpoolerDisabled {
    return Set-ScudoServiceDisabled -ServiceName 'Spooler'
}

function Get-ScudoStatusDeviceInstallRestriction {
    $path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions'
    $enabled = Get-ScudoRegistryDword -Path $path -Name 'DenyUnspecified'
    $isEnabled = $enabled -eq 1
    $state = if ($isEnabled) { 'already-configured' } else { 'needs-action' }
    $summary = if ($isEnabled) { 'New device installation is restricted unless another policy allows it.' } else { 'New device installation is not restricted.' }

    return New-ScudoStatus -State $state -Summary $summary -BeforeValue $enabled
}

function Set-ScudoDeviceInstallRestriction {
    $path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions'
    $beforeValue = Get-ScudoRegistryDword -Path $path -Name 'DenyUnspecified'
    Set-ScudoRegistryDword -Path $path -Name 'DenyUnspecified' -Value 1

    return New-ScudoStatus -State 'already-configured' -Summary 'Enabled policy to block installation of unspecified new devices.' -BeforeValue $beforeValue -AfterValue 1
}

function Restore-ScudoMemoryIntegrity {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Snapshot
    )

    $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'
    $currentValue = Get-ScudoRegistryDword -Path $path -Name 'Enabled'
    $beforeValue = $Snapshot.beforeStatus.BeforeValue
    Restore-ScudoRegistryDword -Path $path -Name 'Enabled' -Value $beforeValue

    $state = if ($beforeValue -eq 1) { 'already-configured' } else { 'pending-reboot' }
    $summary = if ($beforeValue -eq 1) {
        'Restored memory integrity to the saved enabled state.'
    }
    else {
        'Restored memory integrity to the saved disabled state. Restart Windows to complete the change.'
    }

    return New-ScudoStatus -State $state -Summary $summary -RequiresReboot ($beforeValue -ne 1) -BeforeValue $currentValue -AfterValue $beforeValue
}

function Restore-ScudoDriverBlocklist {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Snapshot
    )

    $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Config'
    $currentValue = Get-ScudoRegistryDword -Path $path -Name 'VulnerableDriverBlocklistEnable'
    $beforeValue = $Snapshot.beforeStatus.BeforeValue
    Restore-ScudoRegistryDword -Path $path -Name 'VulnerableDriverBlocklistEnable' -Value $beforeValue

    $state = if ($beforeValue -eq 1) { 'already-configured' } else { 'pending-reboot' }
    $summary = if ($beforeValue -eq 1) {
        'Restored the vulnerable driver blocklist to the saved enabled state.'
    }
    else {
        'Restored the vulnerable driver blocklist to the saved disabled state. Restart Windows to complete the change.'
    }

    return New-ScudoStatus -State $state -Summary $summary -RequiresReboot ($beforeValue -ne 1) -BeforeValue $currentValue -AfterValue $beforeValue
}

function Restore-ScudoDeviceInstallRestriction {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Snapshot
    )

    $path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions'
    $currentValue = Get-ScudoRegistryDword -Path $path -Name 'DenyUnspecified'
    $beforeValue = $Snapshot.beforeStatus.BeforeValue
    Restore-ScudoRegistryDword -Path $path -Name 'DenyUnspecified' -Value $beforeValue

    $summary = if ($beforeValue -eq 1) {
        'Restored the device installation restriction to the saved enabled state.'
    }
    else {
        'Restored the device installation restriction to the saved prior state.'
    }

    return New-ScudoStatus -State 'already-configured' -Summary $summary -BeforeValue $currentValue -AfterValue $beforeValue
}

function Get-ScudoStatusSecureBoot {
    if (-not (Test-ScudoCommandAvailable -Name 'Confirm-SecureBootUEFI')) {
        return New-ScudoStatus -State 'unsupported' -Summary 'Secure Boot checks are unavailable on this device.' -Supported $false
    }

    try {
        $enabled = Confirm-SecureBootUEFI
        $state = if ($enabled) { 'already-configured' } else { 'needs-action' }
        $summary = if ($enabled) { 'Secure Boot is enabled.' } else { 'Secure Boot is disabled.' }

        return New-ScudoStatus -State $state -Summary $summary -BeforeValue $enabled
    }
    catch {
        return New-ScudoStatus -State 'advisory' -Summary 'Secure Boot could not be confirmed. Check firmware settings manually.' -Supported $false -Notes @($_.Exception.Message)
    }
}

function Get-ScudoStatusKernelDmaProtection {
    $notes = @(
        'Windows does not provide a stable first-party PowerShell check for Kernel DMA Protection on all hardware.',
        'Verify this in System Information (msinfo32) and look for "Kernel DMA Protection".'
    )

    return New-ScudoStatus -State 'advisory' -Summary 'Manual verification recommended for Kernel DMA Protection.' -Supported $false -Notes $notes
}

function Get-ScudoStatusBiosPassword {
    return New-ScudoStatus -State 'advisory' -Summary 'BIOS or UEFI passwords must be configured manually in firmware settings.' -Supported $false
}

function Get-ScudoStatusStandardUserGuidance {
    $isAdmin = Test-ScudoAdministrator
    $summary = if ($isAdmin) {
        'The current session is running with administrator rights. Daily use should move to a standard user account.'
    }
    else {
        'The current session is not running with administrator rights.'
    }

    return New-ScudoStatus -State 'advisory' -Summary $summary -BeforeValue $isAdmin
}

function Get-ScudoStatusPasswordManagerGuidance {
    return New-ScudoStatus -State 'advisory' -Summary 'Use a password manager and unique long passwords. Scudo can install Bitwarden, but account setup stays manual.' -Supported $false
}

function Get-ScudoStatusUsbGuidance {
    return New-ScudoStatus -State 'advisory' -Summary 'Avoid public USB charging ports, or use a USB data blocker when charging is unavoidable.' -Supported $false
}

function Get-ScudoStatusBrowserGuidance {
    return New-ScudoStatus -State 'advisory' -Summary 'Use a hardened browser profile. Scudo can install Firefox and apply baseline Firefox policies, but Helium hardening and per-site script allowlisting stay manual.' -Supported $false
}

function Get-ScudoStatusSimpleWallGuidance {
    return New-ScudoStatus -State 'advisory' -Summary 'Scudo can install SimpleWall and enable its default filtering. Rule tuning and app-by-app allowlisting still need manual review.' -Supported $false
}

function Get-ScudoStatusTelemetryPolicy {
    $path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
    $allowTelemetry = Get-ScudoRegistryDword -Path $path -Name 'AllowTelemetry'
    $state = if ($allowTelemetry -in @(0, 1)) { 'already-configured' } else { 'needs-action' }
    $edition = Get-ScudoWindowsEdition
    $summary = if ($allowTelemetry -in @(0, 1)) {
        "Diagnostic data policy is already reduced to the minimum configured value ($allowTelemetry)."
    }
    else {
        'Diagnostic data policy is not reduced.'
    }

    $notes = @()
    if ($edition -and $edition -notmatch 'Enterprise|Education|IoT') {
        $notes += 'Windows 11 Pro and Home may treat telemetry value 0 as 1 (required diagnostic data).'
    }

    return New-ScudoStatus -State $state -Summary $summary -BeforeValue $allowTelemetry -Notes $notes
}

function Set-ScudoTelemetryPolicy {
    $path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
    $beforeValue = Get-ScudoRegistryDword -Path $path -Name 'AllowTelemetry'
    Set-ScudoRegistryDword -Path $path -Name 'AllowTelemetry' -Value 0

    return New-ScudoStatus -State 'already-configured' -Summary 'Set diagnostic data policy to the minimum configured level.' -BeforeValue $beforeValue -AfterValue 0 -Notes @('On some Windows editions, 0 is treated as 1.')
}

function Restore-ScudoTelemetryPolicy {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Snapshot
    )

    $path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
    $currentValue = Get-ScudoRegistryDword -Path $path -Name 'AllowTelemetry'
    $beforeValue = $Snapshot.beforeStatus.BeforeValue
    Restore-ScudoRegistryDword -Path $path -Name 'AllowTelemetry' -Value $beforeValue

    return New-ScudoStatus -State 'already-configured' -Summary 'Restored the diagnostic data policy to the saved value.' -BeforeValue $currentValue -AfterValue $beforeValue
}

function Get-ScudoStatusTelemetryServices {
    $serviceNames = @('DiagTrack', 'dmwappushservice')
    $services = foreach ($serviceName in $serviceNames) {
        Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    }

    if (@($services | Where-Object { $_ -ne $null }).Count -eq 0) {
        return New-ScudoStatus -State 'unsupported' -Summary 'Telemetry services were not found on this system.' -Supported $false
    }

    $allDisabled = $true
    $beforeValue = @()
    foreach ($service in $services) {
        if ($null -eq $service) {
            continue
        }

        $beforeValue += @{
            Name      = $service.Name
            StartType = $service.StartType.ToString()
            Status    = $service.Status.ToString()
        }

        if ($service.StartType -ne 'Disabled') {
            $allDisabled = $false
        }
    }

    $summary = if ($allDisabled) { 'Telemetry services are disabled.' } else { 'One or more telemetry services are not disabled.' }
    $state = if ($allDisabled) { 'already-configured' } else { 'needs-action' }
    return New-ScudoStatus -State $state -Summary $summary -BeforeValue $beforeValue
}

function Set-ScudoTelemetryServicesDisabled {
    $serviceNames = @('DiagTrack', 'dmwappushservice')
    $beforeValue = @()

    foreach ($serviceName in $serviceNames) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($null -eq $service) {
            continue
        }

        $beforeValue += @{
            Name      = $service.Name
            StartType = $service.StartType.ToString()
            Status    = $service.Status.ToString()
        }

        if ($service.Status -ne 'Stopped') {
            Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
        }

        Set-Service -Name $serviceName -StartupType Disabled -ErrorAction SilentlyContinue
    }

    return New-ScudoStatus -State 'already-configured' -Summary 'Disabled telemetry-related services where available.' -BeforeValue $beforeValue -AfterValue @('DiagTrack=Disabled', 'dmwappushservice=Disabled')
}

function Restore-ScudoTelemetryServices {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Snapshot
    )

    $savedServices = @($Snapshot.beforeStatus.BeforeValue)
    if ($savedServices.Count -eq 0) {
        return New-ScudoStatus -State 'error' -Summary 'No saved telemetry service state exists.' -Supported $false
    }

    foreach ($savedService in $savedServices) {
        $service = Get-Service -Name $savedService.Name -ErrorAction SilentlyContinue
        if ($null -eq $service) {
            continue
        }

        if ($service.Status -ne 'Stopped') {
            Stop-Service -Name $savedService.Name -Force -ErrorAction SilentlyContinue
        }

        Set-Service -Name $savedService.Name -StartupType $savedService.StartType -ErrorAction SilentlyContinue

        if ($savedService.Status -eq 'Running') {
            Start-Service -Name $savedService.Name -ErrorAction SilentlyContinue
        }
    }

    return New-ScudoStatus -State 'already-configured' -Summary 'Restored telemetry services to their saved states.' -BeforeValue $Snapshot.resultStatus.AfterValue -AfterValue $savedServices
}

function Get-ScudoFirefoxPolicyPath {
    $installPath = Get-ScudoFirefoxInstallPath
    if ($null -eq $installPath) {
        return $null
    }

    return Join-Path -Path $installPath -ChildPath 'distribution\policies.json'
}

function ConvertTo-ScudoHashtable {
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$InputObject
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $dictionary = @{}
        foreach ($key in $InputObject.Keys) {
            $dictionary[$key] = ConvertTo-ScudoHashtable -InputObject $InputObject[$key]
        }

        return $dictionary
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $items = @()
        foreach ($item in $InputObject) {
            $items += ,(ConvertTo-ScudoHashtable -InputObject $item)
        }

        return $items
    }

    if ($InputObject -is [psobject] -and $InputObject.PSObject.Properties.Count -gt 0) {
        $dictionary = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $dictionary[$property.Name] = ConvertTo-ScudoHashtable -InputObject $property.Value
        }

        return $dictionary
    }

    return $InputObject
}

function Get-ScudoFirefoxPolicyDocument {
    $policyPath = Get-ScudoFirefoxPolicyPath
    if ($null -eq $policyPath) {
        return [pscustomobject]@{
            Installed = $false
            Path      = $null
            Raw       = $null
            Data      = $null
            Error     = $null
        }
    }

    if (-not (Test-Path -Path $policyPath)) {
        return [pscustomobject]@{
            Installed = $true
            Path      = $policyPath
            Raw       = $null
            Data      = $null
            Error     = $null
        }
    }

    try {
        $raw = Get-Content -Path $policyPath -Raw -ErrorAction Stop
        $parsed = $raw | ConvertFrom-Json -ErrorAction Stop

        return [pscustomobject]@{
            Installed = $true
            Path      = $policyPath
            Raw       = $raw
            Data      = ConvertTo-ScudoHashtable -InputObject $parsed
            Error     = $null
        }
    }
    catch {
        return [pscustomobject]@{
            Installed = $true
            Path      = $policyPath
            Raw       = $null
            Data      = $null
            Error     = $_.Exception.Message
        }
    }
}

function Set-ScudoFirefoxPolicies {
    param(
        [Parameter(Mandatory)]
        [bool]$InstallNoScript,

        [Parameter(Mandatory)]
        [bool]$SanitizeCookiesOnShutdown
    )

    $policyDocument = Get-ScudoFirefoxPolicyDocument
    if (-not $policyDocument.Installed) {
        return New-ScudoStatus -State 'unsupported' -Summary 'Firefox is not installed, so Firefox policies cannot be applied.' -Supported $false
    }

    if ($policyDocument.Error) {
        return New-ScudoStatus -State 'error' -Summary "Existing Firefox policies could not be read: $($policyDocument.Error)" -Supported $false
    }

    $installPath = Get-ScudoFirefoxInstallPath
    $distributionPath = Join-Path -Path $installPath -ChildPath 'distribution'
    New-Item -Path $distributionPath -ItemType Directory -Force | Out-Null

    $policyPath = $policyDocument.Path
    $beforeValue = $policyDocument.Raw
    $policyObject = if ($policyDocument.Data) { $policyDocument.Data } else { @{} }

    if (-not $policyObject.ContainsKey('policies') -or $policyObject['policies'] -isnot [System.Collections.IDictionary]) {
        $policyObject['policies'] = @{}
    }

    $policies = $policyObject['policies']
    $policies['DisableTelemetry'] = $true
    $policies['DisableFirefoxStudies'] = $true

    if ($InstallNoScript) {
        if (-not $policies.ContainsKey('ExtensionSettings') -or $policies['ExtensionSettings'] -isnot [System.Collections.IDictionary]) {
            $policies['ExtensionSettings'] = @{}
        }

        $policies['ExtensionSettings']['{73a6fe31-595d-460b-a920-fcc0f8843232}'] = @{
            installation_mode = 'force_installed'
            install_url       = 'https://addons.mozilla.org/firefox/downloads/file/4741732/noscript-13.6.13.xpi'
        }
    }

    if ($SanitizeCookiesOnShutdown) {
        $policies['SanitizeOnShutdown'] = @{
            Cookies      = $true
            OfflineApps  = $true
            SiteSettings = $true
        }
    }

    $policyObject | ConvertTo-Json -Depth 8 | Set-Content -Path $policyPath -Encoding UTF8

    return New-ScudoStatus -State 'already-configured' -Summary 'Wrote Firefox enterprise policies.' -BeforeValue $beforeValue -AfterValue (Get-Content -Path $policyPath -Raw)
}

function Get-ScudoStatusFirefoxNoScript {
    $policyDocument = Get-ScudoFirefoxPolicyDocument
    if (-not $policyDocument.Installed) {
        return New-ScudoStatus -State 'unsupported' -Summary 'Firefox is not installed, so the NoScript policy cannot be checked.' -Supported $false
    }

    if ($policyDocument.Error) {
        return New-ScudoStatus -State 'error' -Summary "Firefox policies could not be read: $($policyDocument.Error)" -Supported $false
    }

    $policyObject = $policyDocument.Data
    if ($null -eq $policyObject -or -not $policyObject.ContainsKey('policies')) {
        return New-ScudoStatus -State 'needs-action' -Summary 'Firefox NoScript force-install policy is not configured.'
    }

    $entry = $null
    if ($policyObject['policies'].ContainsKey('ExtensionSettings')) {
        $extensionSettings = $policyObject['policies']['ExtensionSettings']
        if ($extensionSettings -is [System.Collections.IDictionary] -and $extensionSettings.ContainsKey('{73a6fe31-595d-460b-a920-fcc0f8843232}')) {
            $entry = $extensionSettings['{73a6fe31-595d-460b-a920-fcc0f8843232}']
        }
    }

    $isConfigured = $entry -is [System.Collections.IDictionary] -and $entry['installation_mode'] -eq 'force_installed'
    $state = if ($isConfigured) { 'already-configured' } else { 'needs-action' }
    $summary = if ($isConfigured) { 'Firefox NoScript force-install policy is configured.' } else { 'Firefox NoScript force-install policy is not configured.' }
    return New-ScudoStatus -State $state -Summary $summary -BeforeValue $policyObject
}

function Set-ScudoFirefoxNoScript {
    return Set-ScudoFirefoxPolicies -InstallNoScript $true -SanitizeCookiesOnShutdown $false
}

function Get-ScudoStatusFirefoxSanitizeOnShutdown {
    $policyDocument = Get-ScudoFirefoxPolicyDocument
    if (-not $policyDocument.Installed) {
        return New-ScudoStatus -State 'unsupported' -Summary 'Firefox is not installed, so the shutdown sanitization policy cannot be checked.' -Supported $false
    }

    if ($policyDocument.Error) {
        return New-ScudoStatus -State 'error' -Summary "Firefox policies could not be read: $($policyDocument.Error)" -Supported $false
    }

    $policyObject = $policyDocument.Data
    if ($null -eq $policyObject -or -not $policyObject.ContainsKey('policies')) {
        return New-ScudoStatus -State 'needs-action' -Summary 'Firefox shutdown sanitization policy is not configured.'
    }

    $sanitize = $null
    if ($policyObject['policies'].ContainsKey('SanitizeOnShutdown')) {
        $sanitize = $policyObject['policies']['SanitizeOnShutdown']
    }

    $isConfigured = $sanitize -is [System.Collections.IDictionary] -and $sanitize['Cookies'] -eq $true
    $state = if ($isConfigured) { 'already-configured' } else { 'needs-action' }
    $summary = if ($isConfigured) { 'Firefox shutdown sanitization policy is configured.' } else { 'Firefox shutdown sanitization policy is not configured.' }
    return New-ScudoStatus -State $state -Summary $summary -BeforeValue $policyObject
}

function Set-ScudoFirefoxSanitizeOnShutdown {
    return Set-ScudoFirefoxPolicies -InstallNoScript $false -SanitizeCookiesOnShutdown $true
}

function New-ScudoStandardUser {
    param(
        [Parameter(Mandatory)]
        [string]$UserName,

        [Parameter(Mandatory)]
        [securestring]$Password
    )

    if (-not (Test-ScudoCommandAvailable -Name 'New-LocalUser')) {
        return New-ScudoStatus -State 'unsupported' -Summary 'Local account cmdlets are unavailable.' -Supported $false
    }

    $existing = Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue
    if ($null -ne $existing) {
        return New-ScudoStatus -State 'already-configured' -Summary "Local user $UserName already exists." -BeforeValue $existing.Name
    }

    New-LocalUser -Name $UserName -Password $Password -AccountNeverExpires -ErrorAction Stop | Out-Null
    Add-LocalGroupMember -Group 'Users' -Member $UserName -ErrorAction SilentlyContinue
    Remove-LocalGroupMember -Group 'Administrators' -Member $UserName -ErrorAction SilentlyContinue

    return New-ScudoStatus -State 'already-configured' -Summary "Created standard local user $UserName." -AfterValue $UserName
}

function Get-ScudoStatusSimpleWallFiltering {
    $simpleWallPath = Get-ScudoSimpleWallExecutablePath
    if ($null -eq $simpleWallPath) {
        return New-ScudoStatus -State 'unsupported' -Summary 'SimpleWall is not installed, so filtering cannot be enabled.' -Supported $false
    }

    return New-ScudoStatus -State 'advisory' -Summary 'SimpleWall filtering can be enabled from the CLI. Scudo cannot safely verify its full rule state.' -BeforeValue $simpleWallPath
}

function Set-ScudoSimpleWallFiltering {
    $simpleWallPath = Get-ScudoSimpleWallExecutablePath
    if ($null -eq $simpleWallPath) {
        return New-ScudoStatus -State 'unsupported' -Summary 'SimpleWall is not installed, so filtering cannot be enabled.' -Supported $false
    }

    & $simpleWallPath -install -silent
    return New-ScudoStatus -State 'already-configured' -Summary 'Enabled SimpleWall filtering with the built-in install switch.' -AfterValue $simpleWallPath -Notes @('SimpleWall defaults can block a large amount of traffic. Review rules immediately after enabling.')
}

function Restart-ScudoToFirmwareSettings {
    if (-not (Test-ScudoWindows)) {
        return New-ScudoStatus -State 'unsupported' -Summary 'Firmware restart is only available on Windows.' -Supported $false
    }

    Start-Process -FilePath 'shutdown.exe' -ArgumentList '/r /fw /t 0' -WindowStyle Hidden
    return New-ScudoStatus -State 'pending-reboot' -Summary 'Requested a reboot into firmware settings.' -RequiresReboot $true
}

function Get-ScudoStatusWingetPackage {
    param(
        [Parameter(Mandatory)]
        [string]$PackageId,

        [Parameter(Mandatory)]
        [string]$Title
    )

    if (-not (Test-ScudoWingetAvailable)) {
        return New-ScudoStatus -State 'unsupported' -Summary "winget is unavailable, so $Title cannot be managed." -Supported $false
    }

    try {
        $output = & winget list --exact --id $PackageId --accept-source-agreements 2>&1 | Out-String
        $isInstalled = $output -match [regex]::Escape($PackageId)
        $state = if ($isInstalled) { 'already-configured' } else { 'needs-action' }
        $summary = if ($isInstalled) { "$Title is installed." } else { "$Title is not installed." }
        return New-ScudoStatus -State $state -Summary $summary -BeforeValue $output.Trim()
    }
    catch {
        return New-ScudoStatus -State 'error' -Summary "Failed to query $Title: $($_.Exception.Message)" -Supported $false
    }
}

function Install-ScudoWingetPackage {
    param(
        [Parameter(Mandatory)]
        [string]$PackageId,

        [Parameter(Mandatory)]
        [string]$Title
    )

    if (-not (Test-ScudoWingetAvailable)) {
        return New-ScudoStatus -State 'unsupported' -Summary "winget is unavailable, so $Title cannot be installed." -Supported $false
    }

    $beforeStatus = Get-ScudoStatusWingetPackage -PackageId $PackageId -Title $Title
    if ($beforeStatus.State -eq 'already-configured') {
        return $beforeStatus
    }

    & winget install --exact --id $PackageId --accept-package-agreements --accept-source-agreements --silent
    $afterStatus = Get-ScudoStatusWingetPackage -PackageId $PackageId -Title $Title

    return New-ScudoStatus -State $afterStatus.State -Summary "Installed $Title." -BeforeValue $beforeStatus.BeforeValue -AfterValue $afterStatus.BeforeValue
}

function Get-ScudoStatusBitwarden {
    return Get-ScudoStatusWingetPackage -PackageId 'Bitwarden.Bitwarden' -Title 'Bitwarden'
}

function Install-ScudoBitwarden {
    return Install-ScudoWingetPackage -PackageId 'Bitwarden.Bitwarden' -Title 'Bitwarden'
}

function Get-ScudoStatusSimpleWall {
    return Get-ScudoStatusWingetPackage -PackageId 'Henry++.simplewall' -Title 'SimpleWall'
}

function Install-ScudoSimpleWall {
    return Install-ScudoWingetPackage -PackageId 'Henry++.simplewall' -Title 'SimpleWall'
}

function Get-ScudoStatusHelium {
    return Get-ScudoStatusWingetPackage -PackageId 'ImputNet.Helium' -Title 'Helium Browser'
}

function Install-ScudoHelium {
    return Install-ScudoWingetPackage -PackageId 'ImputNet.Helium' -Title 'Helium Browser'
}

function Get-ScudoStatusFirefox {
    return Get-ScudoStatusWingetPackage -PackageId 'Mozilla.Firefox' -Title 'Mozilla Firefox'
}

function Install-ScudoFirefox {
    return Install-ScudoWingetPackage -PackageId 'Mozilla.Firefox' -Title 'Mozilla Firefox'
}

function Invoke-ScudoControlDetection {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Control
    )

    $functionName = $Control.DetectFunction
    try {
        return & $functionName
    }
    catch {
        return New-ScudoStatus -State 'error' -Summary "Detection failed for $($Control.Title): $($_.Exception.Message)" -Supported $false
    }
}

function Invoke-ScudoControlApply {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Control
    )

    if ($Control.Kind -notin @('applyable', 'installable')) {
        return New-ScudoStatus -State 'advisory' -Summary "$($Control.Title) is not an applyable control."
    }

    if (-not (Test-ScudoAdministrator)) {
        return New-ScudoStatus -State 'error' -Summary 'Administrator rights are required for this action.' -Supported $false
    }

    $functionName = $Control.ApplyFunction
    try {
        return & $functionName
    }
    catch {
        return New-ScudoStatus -State 'error' -Summary "Apply failed for $($Control.Title): $($_.Exception.Message)" -Supported $false
    }
}

function Invoke-ScudoControlRollback {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Control,

        [Parameter(Mandatory)]
        [pscustomobject]$Snapshot
    )

    if (-not (Test-ScudoControlRollbackSupported -Control $Control)) {
        return New-ScudoStatus -State 'advisory' -Summary "$($Control.Title) does not have a supported rollback path."
    }

    if (-not (Test-ScudoAdministrator)) {
        return New-ScudoStatus -State 'error' -Summary 'Administrator rights are required for this action.' -Supported $false
    }

    try {
        return & $Control.RollbackFunction $Snapshot
    }
    catch {
        return New-ScudoStatus -State 'error' -Summary "Rollback failed for $($Control.Title): $($_.Exception.Message)" -Supported $false
    }
}
