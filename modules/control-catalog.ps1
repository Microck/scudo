Set-StrictMode -Version Latest

function Get-ScudoControlCatalog {
    return @(
        [pscustomobject]@{
            Id            = 'mitigation.control-flow-guard'
            MenuNumber    = 2
            Title         = 'Apply Control Flow Guard'
            Kind          = 'applyable'
            Category      = 'Exploit protection'
            RequiresAdmin = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusControlFlowGuard }
            ApplyFunction  = { Set-ScudoControlFlowGuard }
            Guidance      = 'Enable the system-level Control Flow Guard mitigation.'
        }
        [pscustomobject]@{
            Id            = 'defender.asr.office-child-process'
            MenuNumber    = 3
            Title         = 'Apply ASR: Block Office child processes'
            Kind          = 'applyable'
            Category      = 'Microsoft Defender'
            RequiresAdmin = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusAsrRule -ControlId 'defender.asr.office-child-process' }
            ApplyFunction  = { Set-ScudoAsrRule -ControlId 'defender.asr.office-child-process' }
            Guidance      = 'Block Office applications from creating child processes.'
        }
        [pscustomobject]@{
            Id            = 'defender.asr.obfuscated-scripts'
            MenuNumber    = 4
            Title         = 'Apply ASR: Block obfuscated scripts'
            Kind          = 'applyable'
            Category      = 'Microsoft Defender'
            RequiresAdmin = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusAsrRule -ControlId 'defender.asr.obfuscated-scripts' }
            ApplyFunction  = { Set-ScudoAsrRule -ControlId 'defender.asr.obfuscated-scripts' }
            Guidance      = 'Block obfuscated scripts through Defender ASR.'
        }
        [pscustomobject]@{
            Id            = 'defender.asr.email-executable-content'
            MenuNumber    = 5
            Title         = 'Apply ASR: Block executable email content'
            Kind          = 'applyable'
            Category      = 'Microsoft Defender'
            RequiresAdmin = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusAsrRule -ControlId 'defender.asr.email-executable-content' }
            ApplyFunction  = { Set-ScudoAsrRule -ControlId 'defender.asr.email-executable-content' }
            Guidance      = 'Block executable content from email clients and webmail.'
        }
        [pscustomobject]@{
            Id            = 'vbs.memory-integrity'
            MenuNumber    = 6
            Title         = 'Apply Memory Integrity'
            Kind          = 'applyable'
            Category      = 'Virtualization-based security'
            RequiresAdmin = $true
            RequiresReboot = $true
            DetectFunction = { Get-ScudoStatusMemoryIntegrity }
            ApplyFunction  = { Set-ScudoMemoryIntegrity }
            RollbackFunction = { param($Snapshot) Restore-ScudoMemoryIntegrity -Snapshot $Snapshot }
            Guidance      = 'Enable memory integrity through VBS.'
        }
        [pscustomobject]@{
            Id            = 'driver-blocklist'
            MenuNumber    = 7
            Title         = 'Apply Vulnerable Driver Blocklist'
            Kind          = 'applyable'
            Category      = 'Virtualization-based security'
            RequiresAdmin = $true
            RequiresReboot = $true
            DetectFunction = { Get-ScudoStatusDriverBlocklist }
            ApplyFunction  = { Set-ScudoDriverBlocklist }
            RollbackFunction = { param($Snapshot) Restore-ScudoDriverBlocklist -Snapshot $Snapshot }
            Guidance      = 'Enable the Microsoft vulnerable driver blocklist.'
        }
        [pscustomobject]@{
            Id            = 'dns.quad9'
            MenuNumber    = 8
            Title         = 'Apply Quad9 DNS'
            Kind          = 'applyable'
            Category      = 'Networking'
            RequiresAdmin = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusQuad9Dns }
            ApplyFunction  = { Set-ScudoQuad9Dns }
            Guidance      = 'Set Quad9 IPv4 DNS on active physical adapters.'
        }
        [pscustomobject]@{
            Id            = 'dns.doh'
            MenuNumber    = 9
            Title         = 'Apply DNS over HTTPS'
            Kind          = 'applyable'
            Category      = 'Networking'
            RequiresAdmin = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusDnsOverHttps }
            ApplyFunction  = { Set-ScudoDnsOverHttps }
            Guidance      = 'Configure Quad9 DNS-over-HTTPS.'
        }
        [pscustomobject]@{
            Id            = 'service.remote-registry.disabled'
            MenuNumber    = 10
            Title         = 'Disable Remote Registry'
            Kind          = 'applyable'
            Category      = 'Services'
            RequiresAdmin = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusRemoteRegistry }
            ApplyFunction  = { Set-ScudoRemoteRegistryDisabled }
            RollbackFunction = { param($Snapshot) Restore-ScudoServiceState -ServiceName 'RemoteRegistry' -Snapshot $Snapshot }
            Guidance      = 'Disable the Remote Registry service.'
        }
        [pscustomobject]@{
            Id            = 'service.print-spooler.disabled'
            MenuNumber    = 11
            Title         = 'Disable Print Spooler'
            Kind          = 'applyable'
            Category      = 'Services'
            RequiresAdmin = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusPrintSpooler }
            ApplyFunction  = { Set-ScudoPrintSpoolerDisabled }
            RollbackFunction = { param($Snapshot) Restore-ScudoServiceState -ServiceName 'Spooler' -Snapshot $Snapshot }
            Guidance      = 'Disable the Print Spooler service.'
        }
        [pscustomobject]@{
            Id            = 'device-install.restrict-new-devices'
            MenuNumber    = 12
            Title         = 'Restrict new device installation'
            Kind          = 'applyable'
            Category      = 'Physical access'
            RequiresAdmin = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusDeviceInstallRestriction }
            ApplyFunction  = { Set-ScudoDeviceInstallRestriction }
            RollbackFunction = { param($Snapshot) Restore-ScudoDeviceInstallRestriction -Snapshot $Snapshot }
            Guidance      = 'Block installation of devices not described by another policy.'
        }
        [pscustomobject]@{
            Id            = 'privacy.telemetry-policy'
            MenuNumber    = $null
            Title         = 'Reduce telemetry policy'
            Kind          = 'applyable'
            Category      = 'Privacy'
            RequiresAdmin = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusTelemetryPolicy }
            ApplyFunction  = { Set-ScudoTelemetryPolicy }
            RollbackFunction = { param($Snapshot) Restore-ScudoTelemetryPolicy -Snapshot $Snapshot }
            Guidance      = 'Reduce Windows diagnostic data policy to the minimum configured level.'
        }
        [pscustomobject]@{
            Id            = 'privacy.telemetry-services'
            MenuNumber    = $null
            Title         = 'Disable telemetry services'
            Kind          = 'applyable'
            Category      = 'Privacy'
            RequiresAdmin = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusTelemetryServices }
            ApplyFunction  = { Set-ScudoTelemetryServicesDisabled }
            RollbackFunction = { param($Snapshot) Restore-ScudoTelemetryServices -Snapshot $Snapshot }
            Guidance      = 'Disable DiagTrack and related telemetry services where available.'
        }
        [pscustomobject]@{
            Id            = 'browser.firefox-noscript'
            MenuNumber    = $null
            Title         = 'Apply Firefox NoScript policy'
            Kind          = 'applyable'
            Category      = 'Browser'
            RequiresAdmin = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusFirefoxNoScript }
            ApplyFunction  = { Set-ScudoFirefoxNoScript }
            Guidance      = 'Force-install NoScript in Firefox through enterprise policies.'
        }
        [pscustomobject]@{
            Id            = 'browser.firefox-sanitize'
            MenuNumber    = $null
            Title         = 'Apply Firefox shutdown sanitization'
            Kind          = 'applyable'
            Category      = 'Browser'
            RequiresAdmin = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusFirefoxSanitizeOnShutdown }
            ApplyFunction  = { Set-ScudoFirefoxSanitizeOnShutdown }
            Guidance      = 'Clear cookies and selected site data on Firefox shutdown through enterprise policies.'
        }
        [pscustomobject]@{
            Id            = 'account.create-standard-user'
            MenuNumber    = $null
            Title         = 'Create standard local user'
            Kind          = 'special'
            Category      = 'Identity'
            RequiresAdmin = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusStandardUserGuidance }
            ApplyFunction  = $null
            Guidance      = 'Create a standard local user account.'
        }
        [pscustomobject]@{
            Id            = 'app.simplewall-enable-filtering'
            MenuNumber    = $null
            Title         = 'Enable SimpleWall filtering'
            Kind          = 'applyable'
            Category      = 'Apps'
            RequiresAdmin = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusSimpleWallFiltering }
            ApplyFunction  = { Set-ScudoSimpleWallFiltering }
            Guidance      = 'Enable SimpleWall filtering using its command-line install switch.'
        }
        [pscustomobject]@{
            Id            = 'firmware.reboot-to-uefi'
            MenuNumber    = $null
            Title         = 'Reboot to firmware settings'
            Kind          = 'applyable'
            Category      = 'Firmware'
            RequiresAdmin = $true
            RequiresReboot = $true
            DetectFunction = { Get-ScudoStatusSecureBoot }
            ApplyFunction  = { Restart-ScudoToFirmwareSettings }
            Guidance      = 'Reboot directly into firmware settings so Secure Boot can be enabled manually.'
        }
        [pscustomobject]@{
            Id            = 'secure-boot'
            MenuNumber    = $null
            Title         = 'Check Secure Boot'
            Kind          = 'check-only'
            Category      = 'Firmware'
            RequiresAdmin = $false
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusSecureBoot }
            ApplyFunction  = $null
            Guidance      = 'Read-only Secure Boot check.'
        }
        [pscustomobject]@{
            Id            = 'app.bitwarden'
            MenuNumber    = $null
            Title         = 'Install Bitwarden'
            Kind          = 'installable'
            Category      = 'Apps'
            RequiresAdmin = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusBitwarden }
            ApplyFunction  = { Install-ScudoBitwarden }
            Guidance      = 'Install Bitwarden through winget.'
        }
        [pscustomobject]@{
            Id            = 'app.simplewall'
            MenuNumber    = $null
            Title         = 'Install SimpleWall'
            Kind          = 'installable'
            Category      = 'Apps'
            RequiresAdmin = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusSimpleWall }
            ApplyFunction  = { Install-ScudoSimpleWall }
            Guidance      = 'Install SimpleWall through winget.'
        }
        [pscustomobject]@{
            Id            = 'app.helium'
            MenuNumber    = $null
            Title         = 'Install Helium Browser'
            Kind          = 'installable'
            Category      = 'Apps'
            RequiresAdmin = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusHelium }
            ApplyFunction  = { Install-ScudoHelium }
            Guidance      = 'Install Helium Browser through winget.'
        }
        [pscustomobject]@{
            Id            = 'app.firefox'
            MenuNumber    = $null
            Title         = 'Install Mozilla Firefox'
            Kind          = 'installable'
            Category      = 'Apps'
            RequiresAdmin = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusFirefox }
            ApplyFunction  = { Install-ScudoFirefox }
            Guidance      = 'Install Mozilla Firefox through winget.'
        }
        [pscustomobject]@{
            Id            = 'kernel-dma-protection'
            MenuNumber    = $null
            Title         = 'Check Kernel DMA Protection'
            Kind          = 'check-only'
            Category      = 'Firmware'
            RequiresAdmin = $false
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusKernelDmaProtection }
            ApplyFunction  = $null
            Guidance      = 'Best-effort guidance for Kernel DMA Protection.'
        }
        [pscustomobject]@{
            Id            = 'bios-password'
            MenuNumber    = $null
            Title         = 'Manual: BIOS or UEFI password'
            Kind          = 'manual-only'
            Category      = 'Firmware'
            RequiresAdmin = $false
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusBiosPassword }
            ApplyFunction  = $null
            Guidance      = 'Manual firmware task.'
        }
        [pscustomobject]@{
            Id            = 'account.standard-user'
            MenuNumber    = $null
            Title         = 'Manual: Use a standard user account'
            Kind          = 'manual-only'
            Category      = 'Identity'
            RequiresAdmin = $false
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusStandardUserGuidance }
            ApplyFunction  = $null
            Guidance      = 'Move daily work to a standard user account.'
        }
        [pscustomobject]@{
            Id            = 'password-manager'
            MenuNumber    = $null
            Title         = 'Manual: Use a password manager'
            Kind          = 'manual-only'
            Category      = 'Identity'
            RequiresAdmin = $false
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusPasswordManagerGuidance }
            ApplyFunction  = $null
            Guidance      = 'Bitwarden or another password manager is a manual choice.'
        }
        [pscustomobject]@{
            Id            = 'public-usb-guidance'
            MenuNumber    = $null
            Title         = 'Manual: Public USB and charging guidance'
            Kind          = 'manual-only'
            Category      = 'Physical access'
            RequiresAdmin = $false
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusUsbGuidance }
            ApplyFunction  = $null
            Guidance      = 'Public USB guidance only.'
        }
        [pscustomobject]@{
            Id            = 'browser-hardening'
            MenuNumber    = $null
            Title         = 'Manual: Browser hardening guidance'
            Kind          = 'manual-only'
            Category      = 'Browser'
            RequiresAdmin = $false
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusBrowserGuidance }
            ApplyFunction  = $null
            Guidance      = 'Browser guidance only.'
        }
        [pscustomobject]@{
            Id            = 'simplewall-guidance'
            MenuNumber    = $null
            Title         = 'Manual: SimpleWall guidance'
            Kind          = 'manual-only'
            Category      = 'Networking'
            RequiresAdmin = $false
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusSimpleWallGuidance }
            ApplyFunction  = $null
            Guidance      = 'Third-party outbound firewall guidance only.'
        }
    )
}
