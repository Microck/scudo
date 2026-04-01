# scudo

`scudo` is a Windows 11 hardening CLI built around the controls discussed in the transcript notes for the referenced video.

The interface is intentionally simple:

- plain terminal output
- numbered menu
- keyboard-only input
- one control applied at a time

## What v1 does

- checks the current state of supported controls
- applies selected Windows-native hardening controls
- installs selected third-party apps through `winget`
- adds browser, privacy, and account tooling where Windows exposes a defensible automation path
- writes a transcript log for Windows runs
- saves per-control state snapshots before successful changes
- offers rollback only for controls with isolated, captured prior state
- keeps firmware-only and physical-only steps as guided actions
- exports Markdown and JSON reports

## Menu layout

Running `scudo` opens this menu:

```text
[1] Check all controls
[2] Apply Control Flow Guard
[3] Apply ASR: Block Office child processes
[4] Apply ASR: Block obfuscated scripts
[5] Apply ASR: Block executable email content
[6] Apply Memory Integrity
[7] Apply Vulnerable Driver Blocklist
[8] Apply Quad9 DNS
[9] Apply DNS over HTTPS
[10] Disable Remote Registry
[11] Disable Print Spooler
[12] Restrict new device installation
[13] Check firmware and boot items
[14] Install recommended apps
[15] Show browser and account steps
[16] Export report
[17] Roll back a saved control state
[0] Exit
```

## Third-party installers

The install submenu currently supports:

- Bitwarden
- SimpleWall
- Helium Browser
- Mozilla Firefox

## Additional automation added after research

- reduce telemetry policy to the minimum configured level
- disable telemetry services where available
- write Firefox enterprise policies to:
  - force-install NoScript
  - merge into the existing `policies.json` instead of overwriting it
  - clear cookies, site settings, and offline site data on shutdown
  - disable Firefox telemetry and studies
- create a standard local user account
- enable SimpleWall filtering through its documented command-line switch
- reboot directly to firmware settings for manual Secure Boot enablement

## Files

- `scudo.cmd` launches the tool on Windows.
- `scudo.ps1` contains the menu loop and command-line entrypoint.
- `modules/control-actions.ps1` contains the detection and apply logic.
- `modules/safety.ps1` contains preflight checks, transcript logging, and saved-state handling.
- `modules/control-catalog.ps1` contains the control definitions.
- `modules/reporting.ps1` contains the report exporter.
- `tests/scudo.tests.ps1` contains Pester tests.
- `tests/scudo-cli.tests.ps1` covers the CLI help, version, and platform guardrails.
- `.github/workflows/windows-smoke.yml` runs hosted CI smoke coverage.
- `docs/windows-testing.md` documents the real Windows 11 VM and Sandbox test flow.

## Notes

- Target platform is Windows 11.
- Administrator rights are required for the apply actions.
- Scudo blocks apply and rollback actions when Windows has a pending reboot.
- Rollback is intentionally limited to isolated controls: selected registry-backed settings and selected service changes.
- App installs, Defender ASR rules, DNS changes, Firefox policy changes, firmware actions, and account creation do not have Scudo rollback support yet.
- Secure Boot and Kernel DMA still require manual firmware action.
- Helium browser hardening is still manual because policy compatibility was not verified to the same standard as Firefox.
- Firefox policy automation currently targets Mozilla Firefox only.
- Reports default to `Documents\Scudo\Reports` on Windows.
- Logs default to `Documents\Scudo\Logs` and saved state snapshots default to `Documents\Scudo\State` on Windows.
- Hosted GitHub Actions Windows runners are useful only for smoke coverage because they are Windows Server images, not Windows 11 clients.
- Full apply and rollback validation should happen in a Windows 11 VM. See `docs/windows-testing.md`.
