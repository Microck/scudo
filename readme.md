<div align="center">
  <img src="/assets/scudo-logo.svg" alt="scudo logo" width="150" height="150" />

  <h1>scudo</h1>

  <p><strong>windows 11 hardening with a simple menu, direct actions, and rollback-aware guidance</strong></p>

  <p>
    <img src="https://img.shields.io/badge/windows-11-111111?style=flat-square" alt="windows 11" />
    <img src="https://img.shields.io/badge/powershell-5.1%2B-111111?style=flat-square" alt="powershell 5.1+" />
    <img src="https://img.shields.io/badge/version-0.2.0-111111?style=flat-square" alt="version 0.2.0" />
  </p>
</div>

<p align="center">
  <img src="/assets/scudo-banner.png" alt="scudo banner" width="1100" />
</p>

`scudo` is a hardener, not a debloater. it takes the usual windows 11 hardening steps, puts them behind a dead-simple menu, and keeps the tradeoffs visible so you can decide what to apply instead of blindly flipping every switch.

---

## Table of Contents

- [Features](#features)
- [Quick Start](#quick-start)
- [Install & Run](#install--run)
- [Menu Layout](#menu-layout)
- [Presets](#presets)
- [Controls](#controls)
- [Third-Party Installers](#third-party-installers)
- [Additional Automation](#additional-automation)
- [Project Structure](#project-structure)
- [Important Notes](#important-notes)
- [Testing](#testing)
- [Contributing & Support](#contributing--support)

---

## Features

- **Check current state** of supported Windows security controls
- **Apply** selected Windows-native hardening controls
- **Install** recommended third-party security apps through `winget`
- **Configure** browser, privacy, and account tooling via Windows automation paths
- **Transcript logging** — full session logs for every Windows run
- **State snapshots** — per-control state captured before each successful change
- **Rollback** — revert controls that have isolated, captured prior state
- **Reporting** — export Markdown and JSON reports of control states
- **Guided actions** — firmware-only and physical-only steps shown with clear instructions

## Quick Start

### Prerequisites

- **Windows 11** (target platform)
- **PowerShell 5.1+** (included with Windows 11)
- **Administrator rights** — required for apply and rollback actions
- **`winget`** — needed for third-party app installation (built into Windows 11 App Installer)

### Install & Run

#### Method 1 — Bootstrap (recommended)

Open PowerShell as Administrator and run:

```powershell
irm https://raw.githubusercontent.com/Microck/scudo/main/get.ps1 | iex
```

If GitHub raw is blocked, try the DoH fallback:

```powershell
iex (curl.exe -fsSL --doh-url https://1.1.1.1/dns-query https://raw.githubusercontent.com/Microck/scudo/main/get.ps1 | Out-String)
```

The bootstrap downloads scudo into `%localappdata%\scudo` and opens the CLI menu immediately. Re-run to update.

#### Method 2 — Local Clone

```powershell
git clone https://github.com/Microck/scudo.git
cd scudo
.\scudo.cmd
```

### Command-Line Options

```powershell
.\scudo.cmd --version    # Print version and exit
.\scudo.cmd --help       # Print help text and exit
.\scudo.cmd --check-all  # Check all controls and exit
.\scudo.cmd --preset <baseline|strict>  # Apply a preset
.\scudo.cmd --show <control-id|preset>  # Show details for a control
.\scudo.cmd --export     # Export state report
.\scudo.cmd --gui        # Launch WPF GUI
.\scudo.cmd --cli        # Launch CLI menu
```

> Note: Method 1 installs to `%localappdata%\scudo` with self-update via bootstrap. Method 2 runs the repo in-place and requires a manual `git pull` to update.

## Menu Layout

```text
[1]  Check all controls
[2]  Apply Control Flow Guard
[3]  Apply ASR: Block Office child processes
[4]  Apply ASR: Block obfuscated scripts
[5]  Apply ASR: Block executable email content
[6]  Apply Memory Integrity
[7]  Apply Vulnerable Driver Blocklist
[8]  Apply Quad9 DNS
[9]  Apply DNS over HTTPS
[10] Disable Remote Registry
[11] Disable Print Spooler
[12] Restrict new device installation
[13] Check firmware and boot items
[14] Install recommended apps
[15] Show browser and account steps
[16] Export report
[17] Roll back a saved control state
[0]  Exit
```

## Presets

### baseline

Use this first. It keeps the higher-value, lower-friction controls together.

baseline currently focuses on:

- control flow guard
- memory integrity
- vulnerable driver blocklist
- telemetry policy and services reduction
- remote registry disable

### strict

Use this if you are willing to accept more breakage and more tuning work.

strict adds:

- defender asr rules
- quad9 dns
- dns over https
- print spooler disable
- new device install restriction
- firefox noscript policy
- firefox shutdown sanitization
- simplewall filtering when simplewall is already installed

### guided

guided mode walks the catalog section by section and keeps the manual items visible instead of hiding them.

guided covers controls that require manual action or firmware access:

- **firmware** — bios-password, secure-boot, kernel-dma-protection, firmware.reboot-to-uefi
- **identity** — account.create-standard-user, account.standard-user, password-manager

## Controls

Each control is described with the same three questions:

- **what it does**
- **why apply it**
- **why skip it**

### firmware and boot

- `bios-password`
  - **what it does:** reminds you to set a bios or uefi password manually.
  - **why apply it:** makes boot-order abuse and casual firmware tampering harder.
  - **why skip it:** forgetting a firmware password is painful.
- `secure-boot`
  - **what it does:** checks whether secure boot is on.
  - **why apply it:** raises the bar for bootkits and untrusted early boot code.
  - **why skip it:** custom boot setups may intentionally leave it off.
- `kernel-dma-protection`
  - **what it does:** checks whether windows reports kernel dma protection.
  - **why apply it:** matters on systems exposed to thunderbolt or similar direct-memory-capable ports.
  - **why skip it:** some platforms simply do not support it.
- `firmware.reboot-to-uefi`
  - **what it does:** reboots directly into firmware settings.
  - **why apply it:** gives you a fast path to review secure boot and related protections.
  - **why skip it:** disruptive, and the actual setting changes are still manual.

### windows protections

- `mitigation.control-flow-guard`
  - **what it does:** turns on system-level control flow guard checks.
  - **why apply it:** makes control-flow hijacking harder.
  - **why skip it:** rare legacy software can rely on weaker mitigation behavior.
- `vbs.memory-integrity`
  - **what it does:** enables memory integrity.
  - **why apply it:** isolates kernel integrity decisions and blocks a large class of low-level tampering.
  - **why skip it:** can cost performance and expose bad old drivers.
- `driver-blocklist`
  - **what it does:** enables microsoft's vulnerable driver blocklist.
  - **why apply it:** stops known-bad signed drivers from being reused by attackers.
  - **why skip it:** old hardware or niche software can depend on outdated drivers.
- `privacy.telemetry-policy`
  - **what it does:** reduces windows diagnostic data policy.
  - **why apply it:** cuts background telemetry without disabling core protections.
  - **why skip it:** support-heavy or managed environments may want fuller diagnostics.
- `privacy.telemetry-services`
  - **what it does:** disables selected telemetry-related services.
  - **why apply it:** removes background services many personal systems do not need.
  - **why skip it:** can reduce troubleshooting visibility.
- `service.remote-registry.disabled`
  - **what it does:** disables remote registry.
  - **why apply it:** removes an unnecessary remote administration surface.
  - **why skip it:** some remote-management workflows still need it.
- `service.print-spooler.disabled`
  - **what it does:** disables print spooler.
  - **why apply it:** reduces attack surface on machines that do not print.
  - **why skip it:** you lose printing until you restore it.

### microsoft defender

- `defender.asr.office-child-process`
  - **what it does:** blocks office apps from launching child processes.
  - **why apply it:** cuts off a common document and macro execution path.
  - **why skip it:** can break unusual office automations and internal templates.
- `defender.asr.obfuscated-scripts`
  - **what it does:** blocks script content that looks intentionally obfuscated.
  - **why apply it:** targets common droppers, loaders, and script abuse patterns.
  - **why skip it:** can interfere with custom admin scripts or vendor tooling.
- `defender.asr.email-executable-content`
  - **what it does:** blocks executable content launched from email paths.
  - **why apply it:** reduces the chance that a phishing attachment gets to run.
  - **why skip it:** some environments still deliver legitimate installers through email.

### network

- `dns.quad9`
  - **what it does:** points active physical adapters at quad9.
  - **why apply it:** adds a resolver that blocks known malicious domains.
  - **why skip it:** can conflict with vpn, split-dns, or managed network setups.
- `dns.doh`
  - **what it does:** enables dns over https for the configured resolver.
  - **why apply it:** adds privacy and integrity to dns lookups.
  - **why skip it:** can interfere with captive portals or enterprise filtering.
- `app.simplewall-enable-filtering`
  - **what it does:** enables simplewall filtering if simplewall is installed.
  - **why apply it:** gives you explicit outbound filtering instead of silent default allow.
  - **why skip it:** outbound filtering needs tuning or it will break apps.

### physical access

- `device-install.restrict-new-devices`
  - **what it does:** blocks installation of newly attached devices unless another policy allows them.
  - **why apply it:** helps against quick rogue-usb attacks.
  - **why skip it:** makes normal hardware changes more annoying.

### browser

- `browser.firefox-noscript`
  - **what it does:** force-installs noscript in firefox through policy.
  - **why apply it:** gives you high-friction but high-value script restriction.
  - **why skip it:** many sites break until you allow what should run.
- `browser.firefox-sanitize`
  - **what it does:** clears cookies and selected site data on firefox shutdown.
  - **why apply it:** reduces stale sessions and persistent tracking data.
  - **why skip it:** you lose persistent logins and some convenience.

### identity and accounts

- `password-manager`
  - **what it does:** explains the password-manager step if you do not want scudo to install one.
  - **why apply it:** unique long passwords are still one of the highest-value identity upgrades.
  - **why skip it:** you may already use a password manager you trust.
- `account.standard-user`
  - **what it does:** explains why daily work should happen under a standard account.
  - **why apply it:** malware running as a standard user is far less dangerous than malware running as admin.
  - **why skip it:** it adds friction if the machine is mostly used for admin work.
- `account.create-standard-user`
  - **what it does:** creates a standard local user for daily work.
  - **why apply it:** least privilege is still one of the strongest containment controls on windows.
  - **why skip it:** you need to manage a second account and tolerate elevation prompts.

### optional apps

- `app.bitwarden`
  - **what it does:** installs bitwarden through winget.
  - **why apply it:** low-friction password-manager path.
  - **why skip it:** only useful if you actually want bitwarden.
- `app.simplewall`
  - **what it does:** installs simplewall through winget.
  - **why apply it:** provides the outbound filtering tool used by scudo's optional network path.
  - **why skip it:** adds another network control plane to maintain.
- `app.helium`
  - **what it does:** installs helium browser through winget.
  - **why apply it:** gives you an alternate browser path if you do not want your main browser to stay stock.
  - **why skip it:** scudo does not currently apply browser policy automation to helium.
- `app.firefox`
  - **what it does:** installs firefox through winget.
  - **why apply it:** unlocks the firefox-specific policy controls that scudo can automate.
  - **why skip it:** only useful if you actually want firefox installed.

## Third-Party Installers

The install submenu (`[14]`) supports:

| Application | Description                    |
|------------ | -------------------------------|
| Bitwarden   | Open-source password manager   |
| SimpleWall  | Lightweight outbound firewall  |
| Helium      | Privacy-focused browser        |
| Firefox     | Mozilla Firefox browser        |

## Additional Automation

Beyond the core menu controls, Scudo includes post-research automation:

- **Telemetry reduction** — minimizes telemetry policy and disables telemetry services
- **Firefox enterprise policies** — automatically configures:
  - Force-install NoScript extension
  - Merge into existing `policies.json` (preserves manual edits)
  - Clear cookies, site settings, and offline data on shutdown
  - Disable Firefox telemetry and studies
- **Local account creation** — creates a standard local user account
- **SimpleWall filtering** — enables filtering via its documented CLI switch
- **Firmware reboot** — reboots directly to firmware settings for Secure Boot enablement

## Project Structure

```
scudo/
├── scudo.cmd                           # Windows launcher (batch wrapper)
├── scudo.ps1                           # Menu loop and CLI entrypoint
├── modules/
│   ├── control-actions.ps1             # Detection and apply logic
│   ├── safety.ps1                      # Preflight checks, transcript logging, state handling
│   ├── control-catalog.ps1             # Control definitions and metadata
│   └── reporting.ps1                   # Markdown and JSON report exporter
├── tests/
│   ├── scudo.tests.ps1                 # Pester unit/integration tests
│   └── scudo-cli.tests.ps1             # CLI help, version, and platform guard tests
├── docs/
│   └── windows-testing.md              # Windows 11 VM and Sandbox test flow
└── .github/workflows/
    └── windows-smoke.yml               # Hosted CI smoke coverage
```

## Important Notes

- **Target platform:** Windows 11 only.
- **Administrator rights** are required for apply and rollback actions.
- **Pending reboot guard:** Scudo blocks apply and rollback when Windows has a pending reboot.
- **Rollback scope** is intentionally limited to isolated controls (selected registry-backed settings and service changes). The following do **not** have Scudo rollback support:
  - App installs
  - Defender ASR rules
  - DNS changes
  - Firefox policy changes
  - Firmware actions
  - Account creation
- **Secure Boot and Kernel DMA** require manual firmware configuration.
- **Helium browser** hardening is manual — policy compatibility has not been verified to the same standard as Firefox.
- **Firefox policy automation** targets Mozilla Firefox only.

### Default Paths

| Item            | Default Location           |
|---------------- | -------------------------- |
| Reports         | `Documents\Scudo\Reports`  |
| Logs            | `Documents\Scudo\Logs`      |
| State snapshots | `Documents\Scudo\State`     |

## Testing

Scudo uses [Pester](https://pester.dev/) for testing. CI runs on GitHub Actions across `ubuntu-latest` (syntax/guardrail tests) and `windows-2025` (smoke tests).

> **Note:** Hosted GitHub Actions Windows runners are Windows Server images, not Windows 11 client. Full apply/rollback validation should be performed in a Windows 11 VM. See [`docs/windows-testing.md`](docs/windows-testing.md) for the recommended test flow.

To run tests locally on Windows:

```powershell
Invoke-Pester -Path .\tests\
```

## Contributing & Support

- **Issues:** [https://github.com/Microck/scudo/issues](https://github.com/Microck/scudo/issues)
- **Discussions:** [https://github.com/Microck/scudo/discussions](https://github.com/Microck/scudo/discussions)

For PR and issue guidelines, see [contributing.md](contributing.md).
