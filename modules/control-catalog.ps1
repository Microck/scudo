Set-StrictMode -Version Latest

function Get-ScudoSectionCatalog {
    return @(
        [pscustomobject]@{
            Id          = 'firmware'
            Title       = 'Firmware and boot'
            Summary     = 'Start below Windows. Boot trust, Secure Boot, and DMA protections come first.'
            DisplayRank = 10
        }
        [pscustomobject]@{
            Id          = 'windows'
            Title       = 'Windows protections'
            Summary     = 'Exploit mitigations, VBS, driver protections, telemetry reduction, and service hardening.'
            DisplayRank = 20
        }
        [pscustomobject]@{
            Id          = 'defender'
            Title       = 'Microsoft Defender'
            Summary     = 'Behavior-based blocking for common malware and script abuse.'
            DisplayRank = 30
        }
        [pscustomobject]@{
            Id          = 'network'
            Title       = 'Network'
            Summary     = 'Resolver trust, DNS privacy, and outbound filtering.'
            DisplayRank = 40
        }
        [pscustomobject]@{
            Id          = 'physical'
            Title       = 'Physical access'
            Summary     = 'Assume brief physical access and hostile USB paths are real threats.'
            DisplayRank = 50
        }
        [pscustomobject]@{
            Id          = 'browser'
            Title       = 'Browser'
            Summary     = 'Treat the browser as the main delivery path for web-based threats.'
            DisplayRank = 60
        }
        [pscustomobject]@{
            Id          = 'identity'
            Title       = 'Identity and accounts'
            Summary     = 'Least privilege and strong credentials reduce the blast radius of compromise.'
            DisplayRank = 70
        }
        [pscustomobject]@{
            Id          = 'apps'
            Title       = 'Supporting apps'
            Summary     = 'Optional third-party tools that support the hardening workflow.'
            DisplayRank = 80
        }
    )
}

function Get-ScudoPresetCatalog {
    return @(
        [pscustomobject]@{
            Id          = 'baseline'
            Title       = 'Baseline hardening'
            Summary     = 'Lower-friction Windows protections that give solid hardening value without heavy workflow breakage.'
            ApplyMode   = 'batch'
            TierOrder   = @('baseline')
        }
        [pscustomobject]@{
            Id          = 'strict'
            Title       = 'Strict hardening'
            Summary     = 'Baseline plus higher-friction controls for people willing to manage browser, network, and behavior-blocking tradeoffs.'
            ApplyMode   = 'batch'
            TierOrder   = @('baseline', 'strict')
        }
        [pscustomobject]@{
            Id          = 'guided'
            Title       = 'Guided walkthrough'
            Summary     = 'A guided review of firmware, Windows, network, physical, browser, and identity controls.'
            ApplyMode   = 'guided'
            TierOrder   = @('guided')
        }
    )
}

function Get-ScudoPreset {
    param(
        [Parameter(Mandatory)]
        [string]$PresetId
    )

    return Get-ScudoPresetCatalog | Where-Object { $_.Id -eq $PresetId } | Select-Object -First 1
}

function Get-ScudoControlMetadataMap {
    return @{
        'mitigation.control-flow-guard' = @{
            WhatItDoes         = 'Turns on system-level Control Flow Guard checks to make control-flow hijacking harder.'
            WhyApply           = 'Raises the cost of memory-corruption exploits that try to redirect execution into attacker-controlled code.'
            WhyNotApply        = 'Rare legacy software or exploit-lab workflows can depend on weaker mitigation settings.'
            RecommendationTier = 'baseline'
            AutomationLevel    = 'automatic'
            SectionId          = 'windows'
            SortOrder          = 10
        }
        'defender.asr.office-child-process' = @{
            WhatItDoes         = 'Blocks Microsoft Office apps from launching child processes.'
            WhyApply           = 'Cuts off a very common macro and document-based malware execution path.'
            WhyNotApply        = 'Can break unusual Office automations, templates, or line-of-business document workflows.'
            RecommendationTier = 'strict'
            AutomationLevel    = 'automatic'
            SectionId          = 'defender'
            SortOrder          = 10
        }
        'defender.asr.obfuscated-scripts' = @{
            WhatItDoes         = 'Blocks script content that looks intentionally obfuscated to evade inspection.'
            WhyApply           = 'Targets the exact scripting tricks used by droppers, loaders, and commodity malware.'
            WhyNotApply        = 'Aggressive script blocking can interfere with custom admin scripts or vendor tooling.'
            RecommendationTier = 'strict'
            AutomationLevel    = 'automatic'
            SectionId          = 'defender'
            SortOrder          = 20
        }
        'defender.asr.email-executable-content' = @{
            WhatItDoes         = 'Blocks executable content launched from email clients and webmail paths.'
            WhyApply           = 'Reduces the chance that a phishing attachment or email-delivered payload gets to execute.'
            WhyNotApply        = 'Can frustrate environments that still pass legitimate installers through email.'
            RecommendationTier = 'strict'
            AutomationLevel    = 'automatic'
            SectionId          = 'defender'
            SortOrder          = 30
        }
        'vbs.memory-integrity' = @{
            WhatItDoes         = 'Enables Memory Integrity through virtualization-based security.'
            WhyApply           = 'Isolates kernel code integrity decisions and blocks a broad class of low-level tampering.'
            WhyNotApply        = 'Can cost some performance and may clash with old or poorly written drivers.'
            RecommendationTier = 'baseline'
            AutomationLevel    = 'automatic'
            SectionId          = 'windows'
            SortOrder          = 20
        }
        'driver-blocklist' = @{
            WhatItDoes         = 'Enables Microsoft’s vulnerable driver blocklist.'
            WhyApply           = 'Stops attackers from loading known-bad signed drivers to gain kernel-level leverage.'
            WhyNotApply        = 'Old hardware or niche software that relies on outdated drivers may stop working.'
            RecommendationTier = 'baseline'
            AutomationLevel    = 'automatic'
            SectionId          = 'windows'
            SortOrder          = 30
        }
        'dns.quad9' = @{
            WhatItDoes         = 'Points active physical adapters at Quad9.'
            WhyApply           = 'Uses a resolver that actively blocks known malicious domains.'
            WhyNotApply        = 'Overrides your current DNS design and can conflict with split-DNS, VPN, or managed-network requirements.'
            RecommendationTier = 'strict'
            AutomationLevel    = 'automatic'
            SectionId          = 'network'
            SortOrder          = 10
        }
        'dns.doh' = @{
            WhatItDoes         = 'Enables DNS over HTTPS for the configured resolver.'
            WhyApply           = 'Adds privacy and integrity to DNS lookups against local interception or spoofing.'
            WhyNotApply        = 'Can interfere with enterprise filtering, captive portals, or networks that expect plain DNS.'
            RecommendationTier = 'strict'
            AutomationLevel    = 'automatic'
            SectionId          = 'network'
            SortOrder          = 20
        }
        'service.remote-registry.disabled' = @{
            WhatItDoes         = 'Disables the Remote Registry service.'
            WhyApply           = 'Removes a remotely reachable administration surface that many personal machines do not need.'
            WhyNotApply        = 'Some remote-management workflows still rely on it.'
            RecommendationTier = 'baseline'
            AutomationLevel    = 'automatic'
            SectionId          = 'windows'
            SortOrder          = 50
        }
        'service.print-spooler.disabled' = @{
            WhatItDoes         = 'Disables the Print Spooler service.'
            WhyApply           = 'Shrinks attack surface on machines that do not need local or network printing.'
            WhyNotApply        = 'You lose printing until you restore the service.'
            RecommendationTier = 'strict'
            AutomationLevel    = 'automatic'
            SectionId          = 'windows'
            SortOrder          = 60
        }
        'device-install.restrict-new-devices' = @{
            WhatItDoes         = 'Blocks installation of newly attached devices unless another policy already allows them.'
            WhyApply           = 'Helps against quick physical attacks with rogue USB devices.'
            WhyNotApply        = 'Makes legitimate hardware changes more annoying and can surprise you when plugging in new gear.'
            RecommendationTier = 'strict'
            AutomationLevel    = 'automatic'
            SectionId          = 'physical'
            SortOrder          = 10
        }
        'privacy.telemetry-policy' = @{
            WhatItDoes         = 'Reduces the Windows diagnostic data policy to the minimum configured level.'
            WhyApply           = 'Cuts down background telemetry exposure without disabling core Windows security features.'
            WhyNotApply        = 'Managed or support-heavy environments may want fuller telemetry for troubleshooting.'
            RecommendationTier = 'baseline'
            AutomationLevel    = 'automatic'
            SectionId          = 'windows'
            SortOrder          = 40
        }
        'privacy.telemetry-services' = @{
            WhatItDoes         = 'Disables telemetry-related services where Windows exposes a stable switch.'
            WhyApply           = 'Reduces always-on background services that are not essential on many personal systems.'
            WhyNotApply        = 'Can reduce diagnostic visibility and may not be desirable on managed endpoints.'
            RecommendationTier = 'baseline'
            AutomationLevel    = 'automatic'
            SectionId          = 'windows'
            SortOrder          = 45
        }
        'browser.firefox-noscript' = @{
            WhatItDoes         = 'Force-installs NoScript in Firefox through enterprise policy.'
            WhyApply           = 'Gives a high-friction but high-value option for script-restricted browsing.'
            WhyNotApply        = 'Breaks many modern sites until you explicitly allow what should run.'
            RecommendationTier = 'strict'
            AutomationLevel    = 'automatic'
            SectionId          = 'browser'
            SortOrder          = 20
        }
        'browser.firefox-sanitize' = @{
            WhatItDoes         = 'Clears cookies and selected site data on Firefox shutdown through policy.'
            WhyApply           = 'Reduces stale sessions and persistent browser tracking data.'
            WhyNotApply        = 'You lose persistent logins and some site convenience.'
            RecommendationTier = 'strict'
            AutomationLevel    = 'automatic'
            SectionId          = 'browser'
            SortOrder          = 30
        }
        'account.create-standard-user' = @{
            WhatItDoes         = 'Creates a standard local user account for daily work.'
            WhyApply           = 'Least privilege is one of the strongest practical containment controls on Windows.'
            WhyNotApply        = 'You need to manage a second account and tolerate elevation prompts for admin work.'
            RecommendationTier = 'guided'
            AutomationLevel    = 'guided'
            SectionId          = 'identity'
            SortOrder          = 30
        }
        'app.simplewall-enable-filtering' = @{
            WhatItDoes         = 'Enables SimpleWall filtering if SimpleWall is already installed.'
            WhyApply           = 'Adds outbound filtering that the default Windows workflow does not expose clearly.'
            WhyNotApply        = 'Aggressive outbound filtering can break apps until you tune the rule set.'
            RecommendationTier = 'strict'
            AutomationLevel    = 'automatic'
            SectionId          = 'network'
            SortOrder          = 30
        }
        'firmware.reboot-to-uefi' = @{
            WhatItDoes         = 'Reboots straight into firmware settings.'
            WhyApply           = 'Gives you a direct path to enable Secure Boot or review firmware protections.'
            WhyNotApply        = 'It is disruptive and still depends on you making the right firmware changes manually.'
            RecommendationTier = 'guided'
            AutomationLevel    = 'guided'
            SectionId          = 'firmware'
            SortOrder          = 40
        }
        'secure-boot' = @{
            WhatItDoes         = 'Checks whether Secure Boot is enabled.'
            WhyApply           = 'Secure Boot helps block bootkits and untrusted early boot code.'
            WhyNotApply        = 'Dual-boot or advanced custom setups may intentionally keep it off.'
            RecommendationTier = 'guided'
            AutomationLevel    = 'check-only'
            SectionId          = 'firmware'
            SortOrder          = 20
        }
        'app.bitwarden' = @{
            WhatItDoes         = 'Installs Bitwarden through winget.'
            WhyApply           = 'A password manager is a high-value identity control with low ongoing friction.'
            WhyNotApply        = 'You may already use another password manager or avoid desktop installs on this machine.'
            RecommendationTier = 'optional'
            AutomationLevel    = 'automatic'
            SectionId          = 'apps'
            SortOrder          = 10
        }
        'app.simplewall' = @{
            WhatItDoes         = 'Installs SimpleWall through winget.'
            WhyApply           = 'Provides the outbound filtering tool referenced by the hardening workflow.'
            WhyNotApply        = 'Adds another network control plane that you must maintain.'
            RecommendationTier = 'optional'
            AutomationLevel    = 'automatic'
            SectionId          = 'apps'
            SortOrder          = 20
        }
        'app.helium' = @{
            WhatItDoes         = 'Installs Helium Browser through winget.'
            WhyApply           = 'Provides an alternate browser option for people who do not want their main browser to stay stock.'
            WhyNotApply        = 'Policy and hardening behavior are not validated to the same standard as Firefox in this tool.'
            RecommendationTier = 'optional'
            AutomationLevel    = 'automatic'
            SectionId          = 'apps'
            SortOrder          = 30
        }
        'app.firefox' = @{
            WhatItDoes         = 'Installs Mozilla Firefox through winget.'
            WhyApply           = 'Enables the Firefox-specific policy hardening that Scudo can automate.'
            WhyNotApply        = 'It only makes sense if you actually want Firefox on this system.'
            RecommendationTier = 'optional'
            AutomationLevel    = 'automatic'
            SectionId          = 'apps'
            SortOrder          = 40
        }
        'kernel-dma-protection' = @{
            WhatItDoes         = 'Checks whether Windows reports Kernel DMA Protection.'
            WhyApply           = 'DMA protections matter on systems exposed to Thunderbolt or similar direct-memory-capable ports.'
            WhyNotApply        = 'Some platforms simply do not support it, and Scudo cannot flip the firmware bit for you.'
            RecommendationTier = 'guided'
            AutomationLevel    = 'check-only'
            SectionId          = 'firmware'
            SortOrder          = 30
        }
        'bios-password' = @{
            WhatItDoes         = 'Prompts you to set a BIOS or UEFI password manually.'
            WhyApply           = 'Makes boot-order abuse and casual firmware tampering harder.'
            WhyNotApply        = 'A forgotten firmware password is painful and sometimes platform-specific to recover.'
            RecommendationTier = 'guided'
            AutomationLevel    = 'manual'
            SectionId          = 'firmware'
            SortOrder          = 10
        }
        'account.standard-user' = @{
            WhatItDoes         = 'Explains why daily work should happen under a standard account.'
            WhyApply           = 'Malware running as a standard user is far less dangerous than malware running as admin.'
            WhyNotApply        = 'It adds friction if this machine is mostly used for administrative tasks.'
            RecommendationTier = 'guided'
            AutomationLevel    = 'manual'
            SectionId          = 'identity'
            SortOrder          = 20
        }
        'password-manager' = @{
            WhatItDoes         = 'Explains the password-manager step if you do not want Scudo to install one for you.'
            WhyApply           = 'Unique long passwords are one of the biggest identity upgrades you can make.'
            WhyNotApply        = 'You may already have a trusted password-manager workflow.'
            RecommendationTier = 'guided'
            AutomationLevel    = 'manual'
            SectionId          = 'identity'
            SortOrder          = 10
        }
        'public-usb-guidance' = @{
            WhatItDoes         = 'Explains the public charging and hostile USB-device risk model.'
            WhyApply           = 'This hardening model treats brief physical access and public USB data paths as realistic threat vectors.'
            WhyNotApply        = 'This is awareness guidance, not a Windows setting you can safely flip globally.'
            RecommendationTier = 'guided'
            AutomationLevel    = 'manual'
            SectionId          = 'physical'
            SortOrder          = 20
        }
        'browser-hardening' = @{
            WhatItDoes         = 'Explains the browser hardening model behind hardened Firefox, Helium, cookies, and script restriction.'
            WhyApply           = 'The browser is the biggest practical attack surface on most personal Windows machines.'
            WhyNotApply        = 'Strict browser hardening trades away convenience and website compatibility.'
            RecommendationTier = 'guided'
            AutomationLevel    = 'manual'
            SectionId          = 'browser'
            SortOrder          = 10
        }
        'simplewall-guidance' = @{
            WhatItDoes         = 'Explains where outbound filtering helps and what SimpleWall adds.'
            WhyApply           = 'Outbound prompts and explicit allow rules can expose suspicious traffic that Windows normally lets through.'
            WhyNotApply        = 'You must actively manage rules or you will break normal traffic.'
            RecommendationTier = 'guided'
            AutomationLevel    = 'manual'
            SectionId          = 'network'
            SortOrder          = 40
        }
    }
}

function Get-ScudoDefaultRollbackNote {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Control
    )

    if (Test-ScudoControlRollbackSupported -Control $Control) {
        return 'Scudo can restore the saved prior state for this control.'
    }

    if ($Control.Kind -eq 'manual-only') {
        return 'No rollback. Scudo only records guidance for this step.'
    }

    if ($Control.Kind -eq 'check-only') {
        return 'No rollback needed. This is a read-only check.'
    }

    return 'No Scudo rollback support for this control.'
}

function Get-ScudoControlCatalog {
    $controls = @(
        [pscustomobject]@{
            Id             = 'mitigation.control-flow-guard'
            MenuNumber     = 2
            Title          = 'Apply Control Flow Guard'
            Kind           = 'applyable'
            Category       = 'Exploit protection'
            RequiresAdmin  = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusControlFlowGuard }
            ApplyFunction  = { Set-ScudoControlFlowGuard }
            Guidance       = 'Enable the system-level Control Flow Guard mitigation.'
        }
        [pscustomobject]@{
            Id             = 'defender.asr.office-child-process'
            MenuNumber     = 3
            Title          = 'Apply ASR: Block Office child processes'
            Kind           = 'applyable'
            Category       = 'Microsoft Defender'
            RequiresAdmin  = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusAsrRule -ControlId 'defender.asr.office-child-process' }
            ApplyFunction  = { Set-ScudoAsrRule -ControlId 'defender.asr.office-child-process' }
            Guidance       = 'Block Office applications from creating child processes.'
        }
        [pscustomobject]@{
            Id             = 'defender.asr.obfuscated-scripts'
            MenuNumber     = 4
            Title          = 'Apply ASR: Block obfuscated scripts'
            Kind           = 'applyable'
            Category       = 'Microsoft Defender'
            RequiresAdmin  = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusAsrRule -ControlId 'defender.asr.obfuscated-scripts' }
            ApplyFunction  = { Set-ScudoAsrRule -ControlId 'defender.asr.obfuscated-scripts' }
            Guidance       = 'Block obfuscated scripts through Defender ASR.'
        }
        [pscustomobject]@{
            Id             = 'defender.asr.email-executable-content'
            MenuNumber     = 5
            Title          = 'Apply ASR: Block executable email content'
            Kind           = 'applyable'
            Category       = 'Microsoft Defender'
            RequiresAdmin  = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusAsrRule -ControlId 'defender.asr.email-executable-content' }
            ApplyFunction  = { Set-ScudoAsrRule -ControlId 'defender.asr.email-executable-content' }
            Guidance       = 'Block executable content from email clients and webmail.'
        }
        [pscustomobject]@{
            Id               = 'vbs.memory-integrity'
            MenuNumber       = 6
            Title            = 'Apply Memory Integrity'
            Kind             = 'applyable'
            Category         = 'Virtualization-based security'
            RequiresAdmin    = $true
            RequiresReboot   = $true
            DetectFunction   = { Get-ScudoStatusMemoryIntegrity }
            ApplyFunction    = { Set-ScudoMemoryIntegrity }
            RollbackFunction = { param($Snapshot) Restore-ScudoMemoryIntegrity -Snapshot $Snapshot }
            Guidance         = 'Enable memory integrity through VBS.'
        }
        [pscustomobject]@{
            Id               = 'driver-blocklist'
            MenuNumber       = 7
            Title            = 'Apply Vulnerable Driver Blocklist'
            Kind             = 'applyable'
            Category         = 'Virtualization-based security'
            RequiresAdmin    = $true
            RequiresReboot   = $true
            DetectFunction   = { Get-ScudoStatusDriverBlocklist }
            ApplyFunction    = { Set-ScudoDriverBlocklist }
            RollbackFunction = { param($Snapshot) Restore-ScudoDriverBlocklist -Snapshot $Snapshot }
            Guidance         = 'Enable the Microsoft vulnerable driver blocklist.'
        }
        [pscustomobject]@{
            Id             = 'dns.quad9'
            MenuNumber     = 8
            Title          = 'Apply Quad9 DNS'
            Kind           = 'applyable'
            Category       = 'Networking'
            RequiresAdmin  = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusQuad9Dns }
            ApplyFunction  = { Set-ScudoQuad9Dns }
            Guidance       = 'Set Quad9 IPv4 DNS on active physical adapters.'
        }
        [pscustomobject]@{
            Id             = 'dns.doh'
            MenuNumber     = 9
            Title          = 'Apply DNS over HTTPS'
            Kind           = 'applyable'
            Category       = 'Networking'
            RequiresAdmin  = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusDnsOverHttps }
            ApplyFunction  = { Set-ScudoDnsOverHttps }
            Guidance       = 'Configure Quad9 DNS-over-HTTPS.'
        }
        [pscustomobject]@{
            Id               = 'service.remote-registry.disabled'
            MenuNumber       = 10
            Title            = 'Disable Remote Registry'
            Kind             = 'applyable'
            Category         = 'Services'
            RequiresAdmin    = $true
            RequiresReboot   = $false
            DetectFunction   = { Get-ScudoStatusRemoteRegistry }
            ApplyFunction    = { Set-ScudoRemoteRegistryDisabled }
            RollbackFunction = { param($Snapshot) Restore-ScudoServiceState -ServiceName 'RemoteRegistry' -Snapshot $Snapshot }
            Guidance         = 'Disable the Remote Registry service.'
        }
        [pscustomobject]@{
            Id               = 'service.print-spooler.disabled'
            MenuNumber       = 11
            Title            = 'Disable Print Spooler'
            Kind             = 'applyable'
            Category         = 'Services'
            RequiresAdmin    = $true
            RequiresReboot   = $false
            DetectFunction   = { Get-ScudoStatusPrintSpooler }
            ApplyFunction    = { Set-ScudoPrintSpoolerDisabled }
            RollbackFunction = { param($Snapshot) Restore-ScudoServiceState -ServiceName 'Spooler' -Snapshot $Snapshot }
            Guidance         = 'Disable the Print Spooler service.'
        }
        [pscustomobject]@{
            Id               = 'device-install.restrict-new-devices'
            MenuNumber       = 12
            Title            = 'Restrict new device installation'
            Kind             = 'applyable'
            Category         = 'Physical access'
            RequiresAdmin    = $true
            RequiresReboot   = $false
            DetectFunction   = { Get-ScudoStatusDeviceInstallRestriction }
            ApplyFunction    = { Set-ScudoDeviceInstallRestriction }
            RollbackFunction = { param($Snapshot) Restore-ScudoDeviceInstallRestriction -Snapshot $Snapshot }
            Guidance         = 'Block installation of devices not described by another policy.'
        }
        [pscustomobject]@{
            Id             = 'privacy.telemetry-policy'
            MenuNumber     = $null
            Title          = 'Reduce telemetry policy'
            Kind           = 'applyable'
            Category       = 'Privacy'
            RequiresAdmin  = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusTelemetryPolicy }
            ApplyFunction  = { Set-ScudoTelemetryPolicy }
            RollbackFunction = { param($Snapshot) Restore-ScudoTelemetryPolicy -Snapshot $Snapshot }
            Guidance       = 'Reduce Windows diagnostic data policy to the minimum configured level.'
        }
        [pscustomobject]@{
            Id               = 'privacy.telemetry-services'
            MenuNumber       = $null
            Title            = 'Disable telemetry services'
            Kind             = 'applyable'
            Category         = 'Privacy'
            RequiresAdmin    = $true
            RequiresReboot   = $false
            DetectFunction   = { Get-ScudoStatusTelemetryServices }
            ApplyFunction    = { Set-ScudoTelemetryServicesDisabled }
            RollbackFunction = { param($Snapshot) Restore-ScudoTelemetryServices -Snapshot $Snapshot }
            Guidance         = 'Disable DiagTrack and related telemetry services where available.'
        }
        [pscustomobject]@{
            Id             = 'browser.firefox-noscript'
            MenuNumber     = $null
            Title          = 'Apply Firefox NoScript policy'
            Kind           = 'applyable'
            Category       = 'Browser'
            RequiresAdmin  = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusFirefoxNoScript }
            ApplyFunction  = { Set-ScudoFirefoxNoScript }
            Guidance       = 'Force-install NoScript in Firefox through enterprise policies.'
        }
        [pscustomobject]@{
            Id             = 'browser.firefox-sanitize'
            MenuNumber     = $null
            Title          = 'Apply Firefox shutdown sanitization'
            Kind           = 'applyable'
            Category       = 'Browser'
            RequiresAdmin  = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusFirefoxSanitizeOnShutdown }
            ApplyFunction  = { Set-ScudoFirefoxSanitizeOnShutdown }
            Guidance       = 'Clear cookies and selected site data on Firefox shutdown through enterprise policies.'
        }
        [pscustomobject]@{
            Id             = 'account.create-standard-user'
            MenuNumber     = $null
            Title          = 'Create standard local user'
            Kind           = 'special'
            Category       = 'Identity'
            RequiresAdmin  = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusStandardUserGuidance }
            ApplyFunction  = $null
            Guidance       = 'Create a standard local user account.'
        }
        [pscustomobject]@{
            Id             = 'app.simplewall-enable-filtering'
            MenuNumber     = $null
            Title          = 'Enable SimpleWall filtering'
            Kind           = 'applyable'
            Category       = 'Apps'
            RequiresAdmin  = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusSimpleWallFiltering }
            ApplyFunction  = { Set-ScudoSimpleWallFiltering }
            Guidance       = 'Enable SimpleWall filtering using its command-line install switch.'
        }
        [pscustomobject]@{
            Id             = 'firmware.reboot-to-uefi'
            MenuNumber     = $null
            Title          = 'Reboot to firmware settings'
            Kind           = 'applyable'
            Category       = 'Firmware'
            RequiresAdmin  = $true
            RequiresReboot = $true
            DetectFunction = { Get-ScudoStatusSecureBoot }
            ApplyFunction  = { Restart-ScudoToFirmwareSettings }
            Guidance       = 'Reboot directly into firmware settings so Secure Boot can be enabled manually.'
        }
        [pscustomobject]@{
            Id             = 'secure-boot'
            MenuNumber     = $null
            Title          = 'Check Secure Boot'
            Kind           = 'check-only'
            Category       = 'Firmware'
            RequiresAdmin  = $false
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusSecureBoot }
            ApplyFunction  = $null
            Guidance       = 'Read-only Secure Boot check.'
        }
        [pscustomobject]@{
            Id             = 'app.bitwarden'
            MenuNumber     = $null
            Title          = 'Install Bitwarden'
            Kind           = 'installable'
            Category       = 'Apps'
            RequiresAdmin  = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusBitwarden }
            ApplyFunction  = { Install-ScudoBitwarden }
            Guidance       = 'Install Bitwarden through winget.'
        }
        [pscustomobject]@{
            Id             = 'app.simplewall'
            MenuNumber     = $null
            Title          = 'Install SimpleWall'
            Kind           = 'installable'
            Category       = 'Apps'
            RequiresAdmin  = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusSimpleWall }
            ApplyFunction  = { Install-ScudoSimpleWall }
            Guidance       = 'Install SimpleWall through winget.'
        }
        [pscustomobject]@{
            Id             = 'app.helium'
            MenuNumber     = $null
            Title          = 'Install Helium Browser'
            Kind           = 'installable'
            Category       = 'Apps'
            RequiresAdmin  = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusHelium }
            ApplyFunction  = { Install-ScudoHelium }
            Guidance       = 'Install Helium Browser through winget.'
        }
        [pscustomobject]@{
            Id             = 'app.firefox'
            MenuNumber     = $null
            Title          = 'Install Mozilla Firefox'
            Kind           = 'installable'
            Category       = 'Apps'
            RequiresAdmin  = $true
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusFirefox }
            ApplyFunction  = { Install-ScudoFirefox }
            Guidance       = 'Install Mozilla Firefox through winget.'
        }
        [pscustomobject]@{
            Id             = 'kernel-dma-protection'
            MenuNumber     = $null
            Title          = 'Check Kernel DMA Protection'
            Kind           = 'check-only'
            Category       = 'Firmware'
            RequiresAdmin  = $false
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusKernelDmaProtection }
            ApplyFunction  = $null
            Guidance       = 'Best-effort guidance for Kernel DMA Protection.'
        }
        [pscustomobject]@{
            Id             = 'bios-password'
            MenuNumber     = $null
            Title          = 'Manual: BIOS or UEFI password'
            Kind           = 'manual-only'
            Category       = 'Firmware'
            RequiresAdmin  = $false
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusBiosPassword }
            ApplyFunction  = $null
            Guidance       = 'Manual firmware task.'
        }
        [pscustomobject]@{
            Id             = 'account.standard-user'
            MenuNumber     = $null
            Title          = 'Manual: Use a standard user account'
            Kind           = 'manual-only'
            Category       = 'Identity'
            RequiresAdmin  = $false
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusStandardUserGuidance }
            ApplyFunction  = $null
            Guidance       = 'Move daily work to a standard user account.'
        }
        [pscustomobject]@{
            Id             = 'password-manager'
            MenuNumber     = $null
            Title          = 'Manual: Use a password manager'
            Kind           = 'manual-only'
            Category       = 'Identity'
            RequiresAdmin  = $false
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusPasswordManagerGuidance }
            ApplyFunction  = $null
            Guidance       = 'Bitwarden or another password manager is a manual choice.'
        }
        [pscustomobject]@{
            Id             = 'public-usb-guidance'
            MenuNumber     = $null
            Title          = 'Manual: Public USB and charging guidance'
            Kind           = 'manual-only'
            Category       = 'Physical access'
            RequiresAdmin  = $false
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusUsbGuidance }
            ApplyFunction  = $null
            Guidance       = 'Public USB guidance only.'
        }
        [pscustomobject]@{
            Id             = 'browser-hardening'
            MenuNumber     = $null
            Title          = 'Manual: Browser hardening guidance'
            Kind           = 'manual-only'
            Category       = 'Browser'
            RequiresAdmin  = $false
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusBrowserGuidance }
            ApplyFunction  = $null
            Guidance       = 'Browser guidance only.'
        }
        [pscustomobject]@{
            Id             = 'simplewall-guidance'
            MenuNumber     = $null
            Title          = 'Manual: SimpleWall guidance'
            Kind           = 'manual-only'
            Category       = 'Networking'
            RequiresAdmin  = $false
            RequiresReboot = $false
            DetectFunction = { Get-ScudoStatusSimpleWallGuidance }
            ApplyFunction  = $null
            Guidance       = 'Third-party outbound firewall guidance only.'
        }
    )

    $metadataMap = Get-ScudoControlMetadataMap

    foreach ($control in $controls) {
        $metadata = $metadataMap[$control.Id]
        if ($null -eq $metadata) {
            throw "Missing Scudo metadata for control: $($control.Id)"
        }

        $control | Add-Member -NotePropertyName WhatItDoes -NotePropertyValue $metadata.WhatItDoes -Force
        $control | Add-Member -NotePropertyName WhyApply -NotePropertyValue $metadata.WhyApply -Force
        $control | Add-Member -NotePropertyName WhyNotApply -NotePropertyValue $metadata.WhyNotApply -Force
        $control | Add-Member -NotePropertyName RecommendationTier -NotePropertyValue $metadata.RecommendationTier -Force
        $control | Add-Member -NotePropertyName AutomationLevel -NotePropertyValue $metadata.AutomationLevel -Force
        $control | Add-Member -NotePropertyName SectionId -NotePropertyValue $metadata.SectionId -Force
        $control | Add-Member -NotePropertyName SortOrder -NotePropertyValue $metadata.SortOrder -Force
        $control | Add-Member -NotePropertyName RollbackNote -NotePropertyValue (Get-ScudoDefaultRollbackNote -Control $control) -Force
    }

    return $controls
}

function Get-ScudoControlsForPreset {
    param(
        [Parameter(Mandatory)]
        [string]$PresetId,

        [switch]$IncludeNonAutomatic
    )

    $preset = Get-ScudoPreset -PresetId $PresetId
    if ($null -eq $preset) {
        return @()
    }

    $controls = @(
        Get-ScudoControlCatalog |
            Where-Object { $_.RecommendationTier -in $preset.TierOrder }
    )

    if (-not $IncludeNonAutomatic) {
        $controls = @(
            $controls |
                Where-Object { $_.AutomationLevel -eq 'automatic' }
        )
    }

    $sectionMap = @{}
    foreach ($section in Get-ScudoSectionCatalog) {
        $sectionMap[$section.Id] = [int]$section.DisplayRank
    }

    return @(
        $controls |
            Sort-Object `
                @{ Expression = { $sectionMap[$_.SectionId] } }, `
                @{ Expression = { [int]$_.SortOrder } }, `
                @{ Expression = { $_.Title } }
    )
}
