# scudo

`scudo` is a Windows 11 hardener. It is not a debloater.

The project turns the video advice in [youtube-transcript-2rkihwygevm.md](/home/ubuntu/workspace/unhack/youtube-transcript-2rkihwygevm.md) into a simple Massgrave-style menu, a small CLI surface, a GUI, and transcript-backed control explanations.

## What Scudo Does

- Reviews the machine against the controls discussed in the video.
- Applies the low-friction hardening steps that can be automated safely enough in PowerShell.
- Keeps higher-friction or firmware-only items visible as guided or manual controls instead of pretending they can be fully automated.
- Saves rollback state for the controls where Scudo can reliably restore the prior Windows setting.

## What Scudo Does Not Do

- It does not try to be a Windows optimizer or general-purpose debloater.
- It does not silently flip firmware settings for you.
- It does not guarantee safe rollback for every control in the catalog.
- It does not replace testing on your own machine, especially for Defender ASR, browser restrictions, and network changes.

## Safety Notes

- Run Scudo from an elevated PowerShell session when you plan to apply changes.
- `strict` includes DNS and browser restrictions. Test before adopting it as a default.
- Firmware items such as BIOS password, Secure Boot review, and Kernel DMA Protection are check-only or guided because Windows cannot safely automate the underlying firmware choice.
- Rollback is only available where Scudo records enough prior state to restore it.

## Quick Start

```powershell
git clone <your-private-repo-url>
cd unhack
.\scudo.cmd
```

For direct CLI use:

```powershell
.\scudo.ps1 --help
.\scudo.ps1 --check-all
.\scudo.ps1 --preset baseline
.\scudo.ps1 --show strict
.\scudo.ps1 --gui
```

## Main Commands

```text
scudo
scudo --check-all
scudo --preset baseline
scudo --preset strict
scudo --show <control-id|preset>
scudo --export
scudo --gui
scudo --cli
scudo --version
scudo --help
```

Advanced direct actions:

```text
scudo --action apply --control-id <id>
scudo --action rollback --control-id <id>
scudo --no-pause
```

## Main Menu

Scudo’s CLI menu is intentionally short:

```text
[1] Review this PC
[2] Apply baseline hardening
[3] Apply strict hardening
[4] Guided hardening walkthrough
[5] Browse individual controls
[6] Optional apps and browser tools
[7] Roll back a saved change
[8] Export report
[0] Exit
```

This keeps the first decisions simple:

- `Review this PC` shows current status grouped by transcript section.
- `Baseline` applies lower-friction automatic controls.
- `Strict` adds higher-friction controls that can break workflows.
- `Guided walkthrough` follows the video order and keeps manual items visible.

## Presets

### `baseline`

Use this first. It focuses on Windows protections with a better security-to-friction ratio.

Includes automatic controls from the `baseline` tier:

- Control Flow Guard
- Memory Integrity
- Vulnerable Driver Blocklist
- Telemetry policy reduction
- Telemetry service reduction
- Remote Registry disable

### `strict`

Use this only if you accept more breakage risk and more tuning effort.

Includes everything in `baseline`, plus automatic controls from the `strict` tier:

- Defender ASR rules
- Quad9 DNS
- DNS over HTTPS
- Print Spooler disable
- new device install restriction
- Firefox NoScript policy
- Firefox shutdown sanitization
- SimpleWall filtering when SimpleWall is already installed

### `guided`

This is the transcript-ordered review mode. It includes:

- firmware checks and manual steps
- browser and physical guidance
- least-privilege guidance
- optional identity and app recommendations

## GUI

The GUI is intentionally minimal:

- left side: controls and status
- right side: what it does, why apply it, why skip it, rollback note
- top bar: status refresh, report export, reports folder, elevation relaunch

The palette is:

- base: `#353A3B`
- success: `#77AA77`
- accent: `#F4E3C1`
- danger: `#C52713`

## Control Reference

Each entry below maps back to the transcript and is labeled by tier and automation level.

### Firmware And Boot

#### `bios-password`

- Tier: `guided`
- Automation: `manual`
- What it does: prompts you to set a BIOS or UEFI password manually.
- Why apply it: makes boot-order abuse and casual firmware tampering harder.
- Why skip it: a forgotten firmware password can be painful to recover.
- Rollback: no rollback. Scudo only records guidance for this step.

#### `secure-boot`

- Tier: `guided`
- Automation: `check-only`
- What it does: checks whether Secure Boot is enabled.
- Why apply it: helps block bootkits and untrusted early boot code.
- Why skip it: custom boot setups may intentionally keep it off.
- Rollback: no rollback needed. This is a read-only check.

#### `kernel-dma-protection`

- Tier: `guided`
- Automation: `check-only`
- What it does: checks whether Windows reports Kernel DMA Protection.
- Why apply it: helps on systems exposed to Thunderbolt or similar direct-memory-capable ports.
- Why skip it: some platforms do not support it, and Scudo cannot flip the firmware bit for you.
- Rollback: no rollback needed. This is a read-only check.

#### `firmware.reboot-to-uefi`

- Tier: `guided`
- Automation: `guided input`
- What it does: reboots straight into firmware settings.
- Why apply it: gives you a direct path to review Secure Boot and related firmware protections.
- Why skip it: it is disruptive and the actual firmware changes are still manual.
- Rollback: no Scudo rollback support for this control.

### Windows Protections

#### `mitigation.control-flow-guard`

- Tier: `baseline`
- Automation: `automatic`
- What it does: turns on system-level Control Flow Guard checks.
- Why apply it: raises the cost of memory-corruption exploits that try to redirect execution.
- Why skip it: rare legacy software may depend on weaker mitigation settings.
- Rollback: no Scudo rollback support for this control.

#### `vbs.memory-integrity`

- Tier: `baseline`
- Automation: `automatic`
- What it does: enables Memory Integrity through virtualization-based security.
- Why apply it: isolates kernel integrity decisions and blocks low-level tampering paths.
- Why skip it: may cost some performance and can clash with old drivers.
- Rollback: Scudo can restore the saved prior state for this control.

#### `driver-blocklist`

- Tier: `baseline`
- Automation: `automatic`
- What it does: enables Microsoft’s vulnerable driver blocklist.
- Why apply it: blocks known-bad signed drivers that attackers reuse for kernel leverage.
- Why skip it: old hardware or niche software can depend on outdated drivers.
- Rollback: Scudo can restore the saved prior state for this control.

#### `privacy.telemetry-policy`

- Tier: `baseline`
- Automation: `automatic`
- What it does: reduces Windows diagnostic data policy to the minimum configured level.
- Why apply it: reduces background telemetry exposure without disabling core protections.
- Why skip it: managed or support-heavy environments may want more telemetry.
- Rollback: Scudo can restore the saved prior state for this control.

#### `privacy.telemetry-services`

- Tier: `baseline`
- Automation: `automatic`
- What it does: disables telemetry-related services where Windows exposes a stable switch.
- Why apply it: reduces always-on background services that are not essential on many personal systems.
- Why skip it: can reduce diagnostic visibility on managed endpoints.
- Rollback: Scudo can restore the saved prior state for this control.

#### `service.remote-registry.disabled`

- Tier: `baseline`
- Automation: `automatic`
- What it does: disables the Remote Registry service.
- Why apply it: removes a remotely reachable administration surface many personal machines do not need.
- Why skip it: some remote-management workflows still rely on it.
- Rollback: Scudo can restore the saved prior state for this control.

#### `service.print-spooler.disabled`

- Tier: `strict`
- Automation: `automatic`
- What it does: disables the Print Spooler service.
- Why apply it: shrinks attack surface on systems that do not need printing.
- Why skip it: you lose printing until the service is restored.
- Rollback: Scudo can restore the saved prior state for this control.

### Microsoft Defender

#### `defender.asr.office-child-process`

- Tier: `strict`
- Automation: `automatic`
- What it does: blocks Microsoft Office apps from launching child processes.
- Why apply it: cuts off a common macro and document-based malware path.
- Why skip it: can break unusual Office automations or line-of-business templates.
- Rollback: no Scudo rollback support for this control.

#### `defender.asr.obfuscated-scripts`

- Tier: `strict`
- Automation: `automatic`
- What it does: blocks script content that looks intentionally obfuscated.
- Why apply it: targets common droppers, loaders, and script abuse patterns.
- Why skip it: can interfere with custom admin scripts or vendor tooling.
- Rollback: no Scudo rollback support for this control.

#### `defender.asr.email-executable-content`

- Tier: `strict`
- Automation: `automatic`
- What it does: blocks executable content launched from email clients and webmail paths.
- Why apply it: reduces the chance that a phishing attachment gets to execute.
- Why skip it: can frustrate environments that still pass legitimate installers through email.
- Rollback: no Scudo rollback support for this control.

### Network

#### `dns.quad9`

- Tier: `strict`
- Automation: `automatic`
- What it does: points active physical adapters at Quad9.
- Why apply it: uses a resolver that actively blocks known malicious domains.
- Why skip it: can conflict with VPNs, split-DNS, or managed-network requirements.
- Rollback: no Scudo rollback support for this control.

#### `dns.doh`

- Tier: `strict`
- Automation: `automatic`
- What it does: enables DNS over HTTPS for the configured resolver.
- Why apply it: adds privacy and integrity to DNS lookups.
- Why skip it: can interfere with enterprise filtering or captive portals.
- Rollback: no Scudo rollback support for this control.

#### `app.simplewall-enable-filtering`

- Tier: `strict`
- Automation: `automatic`
- What it does: enables SimpleWall filtering if SimpleWall is already installed.
- Why apply it: adds explicit outbound filtering that Windows does not expose clearly by default.
- Why skip it: aggressive outbound filtering can break apps until you tune rules.
- Rollback: no Scudo rollback support for this control.

#### `simplewall-guidance`

- Tier: `guided`
- Automation: `manual`
- What it does: explains where outbound filtering helps and what SimpleWall adds.
- Why apply it: outbound prompts can expose suspicious traffic that Windows would normally allow.
- Why skip it: you must actively manage rules or you will break normal traffic.
- Rollback: no rollback. Scudo only records guidance for this step.

### Physical Access

#### `device-install.restrict-new-devices`

- Tier: `strict`
- Automation: `automatic`
- What it does: blocks installation of newly attached devices unless another policy already allows them.
- Why apply it: helps against quick physical attacks with rogue USB devices.
- Why skip it: makes legitimate hardware changes more annoying.
- Rollback: Scudo can restore the saved prior state for this control.

#### `public-usb-guidance`

- Tier: `guided`
- Automation: `manual`
- What it does: explains the public charging and hostile USB-device risk model.
- Why apply it: the transcript treats brief physical access and public USB data paths as real threats.
- Why skip it: this is awareness guidance, not a Windows setting you can safely automate.
- Rollback: no rollback. Scudo only records guidance for this step.

### Browser

#### `browser-hardening`

- Tier: `guided`
- Automation: `manual`
- What it does: explains the browser hardening model behind hardened Firefox, Helium, cookies, and script restriction.
- Why apply it: the browser is the biggest practical attack surface on most personal Windows machines.
- Why skip it: strict browser hardening trades away convenience and site compatibility.
- Rollback: no rollback. Scudo only records guidance for this step.

#### `browser.firefox-noscript`

- Tier: `strict`
- Automation: `automatic`
- What it does: force-installs NoScript in Firefox through enterprise policy.
- Why apply it: gives a high-friction but high-value option for script-restricted browsing.
- Why skip it: breaks many modern sites until you explicitly allow what should run.
- Rollback: no Scudo rollback support for this control.

#### `browser.firefox-sanitize`

- Tier: `strict`
- Automation: `automatic`
- What it does: clears cookies and selected site data on Firefox shutdown through policy.
- Why apply it: reduces stale sessions and persistent tracking data.
- Why skip it: you lose persistent logins and some convenience.
- Rollback: no Scudo rollback support for this control.

### Identity And Accounts

#### `password-manager`

- Tier: `guided`
- Automation: `manual`
- What it does: explains the password-manager step if you do not want Scudo to install one for you.
- Why apply it: unique long passwords are one of the biggest identity upgrades you can make.
- Why skip it: you may already have a trusted password-manager workflow.
- Rollback: no rollback. Scudo only records guidance for this step.

#### `account.standard-user`

- Tier: `guided`
- Automation: `manual`
- What it does: explains why daily work should happen under a standard account.
- Why apply it: malware running as a standard user is far less dangerous than malware running as admin.
- Why skip it: it adds friction if the machine is mostly used for administrative work.
- Rollback: no rollback. Scudo only records guidance for this step.

#### `account.create-standard-user`

- Tier: `guided`
- Automation: `guided input`
- What it does: creates a standard local user account for daily work.
- Why apply it: least privilege is one of the strongest practical containment controls on Windows.
- Why skip it: you need to manage a second account and tolerate elevation prompts.
- Rollback: no Scudo rollback support for this control.

### Supporting Apps

These are optional helpers. They are not part of the hardening baseline by themselves.

#### `app.bitwarden`

- Tier: `optional`
- Automation: `automatic`
- What it does: installs Bitwarden through `winget`.
- Why apply it: a password manager is a high-value identity control with low ongoing friction.
- Why skip it: you may already use another password manager.
- Rollback: no Scudo rollback support for this control.

#### `app.simplewall`

- Tier: `optional`
- Automation: `automatic`
- What it does: installs SimpleWall through `winget`.
- Why apply it: provides the outbound filtering tool referenced by the hardening workflow.
- Why skip it: adds another network control plane to maintain.
- Rollback: no Scudo rollback support for this control.

#### `app.helium`

- Tier: `optional`
- Automation: `automatic`
- What it does: installs Helium Browser through `winget`.
- Why apply it: gives you an alternate browser option if you do not want your main browser to stay stock.
- Why skip it: Scudo does not validate Helium policies to the same level as Firefox.
- Rollback: no Scudo rollback support for this control.

#### `app.firefox`

- Tier: `optional`
- Automation: `automatic`
- What it does: installs Mozilla Firefox through `winget`.
- Why apply it: enables the Firefox-specific policy hardening Scudo can automate.
- Why skip it: only useful if you actually want Firefox installed.
- Rollback: no Scudo rollback support for this control.

## Reports

`scudo --export` writes:

- JSON report
- Markdown report

The report includes:

- state
- section
- tier
- automation level
- rollback note
- what the control does
- why to apply it
- why to skip it

## Verification Status

The current repo includes:

- Pester unit and CLI tests
- a Windows GUI
- transcript-backed control metadata
- batch presets and direct-action commands

Real Windows testing still matters for:

- ASR rules in your environment
- DNS changes
- outbound filtering behavior
- device-install restriction on the hardware you actually plug in

## Last Reviewed

- Transcript source: [youtube-transcript-2rkihwygevm.md](/home/ubuntu/workspace/unhack/youtube-transcript-2rkihwygevm.md)
- Current README review date: `2026-04-02`
