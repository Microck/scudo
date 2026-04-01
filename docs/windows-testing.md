# Windows testing

`scudo` is not a candidate for fake terminal emulation on Linux. The tool depends on real Windows 11 behavior:

- `powershell.exe`
- registry reads and writes
- Windows service management
- `winget`
- transcript logging
- reboot and firmware flows

That means the test stack should separate hosted smoke coverage from real Windows 11 system testing.

## Test lanes

### 1. Hosted CI smoke

Workflow: `.github/workflows/windows-smoke.yml`

What it validates:

- Pester tests for catalog, reporting, and CLI surface
- `scudo -help`
- `scudo --version`
- the explicit Windows 11 guardrail on the hosted Windows Server runner

What it does not validate:

- interactive menu behavior on Windows 11
- apply or rollback flows
- registry and service mutation on a supported client OS
- `winget` app management as an end-user Windows 11 session
- Windows Terminal versus Console Host behavior on a real client machine

Why the guardrail test exists:

- GitHub hosted Windows runners are Windows Server images, not Windows 11 client machines
- `scudo` intentionally refuses to run on non-Windows 11 systems

### 2. Primary local lab

Use a Windows 11 VM on QEMU/KVM as the main test environment.

Recommended baseline:

- 4 vCPUs minimum
- 8 GB RAM minimum
- 64 GB disk
- TPM enabled
- Secure Boot enabled if the VM stack supports it cleanly

Recommended snapshots:

1. Fresh Windows 11 install
2. After updates, `winget`, and Windows Terminal are verified
3. After cloning or copying the repo and installing test prerequisites
4. Before each apply or rollback test batch

### 3. Disposable destructive lane

Use Windows Sandbox inside the Windows 11 VM when you want a clean throwaway session for app installs or riskier checks.

Requirements:

- nested virtualization enabled for the VM
- Windows 11 edition that supports Sandbox
- enough memory headroom for the guest and inner sandbox

Sandbox is good for:

- confirming the launcher works from a clean session
- checking `winget` install behavior
- verifying report and log output paths
- trying destructive flows without polluting the main VM snapshot chain

Sandbox is not the primary lab because Windows Terminal and `winget` availability can need extra setup and the environment is intentionally disposable.

## Terminal hosts to test

The terminal host matters, but only after the OS is real Windows 11.

### Console Host

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scudo.ps1 -- -help
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scudo.ps1 --version
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scudo.ps1 --check-all
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scudo.ps1 --export
```

### Windows Terminal

Set Windows Terminal as the default terminal app, then launch `scudo` both through the UI and directly:

```powershell
wt.exe powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\path\to\scudo.ps1
```

Validate these behaviors:

- banner and menu rendering
- numbered input flow
- elevation relaunch behavior
- transcript creation
- no prompt corruption after apply, rollback, or export actions

## Suggested Windows 11 test matrix

### Read-only checks

Run these first on a clean snapshot:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scudo.ps1 -- -help
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scudo.ps1 --version
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scudo.ps1 --check-all
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scudo.ps1 --export
```

Verify:

- exit codes are sane
- reports land under `Documents\Scudo\Reports`
- logs land under `Documents\Scudo\Logs`
- no mutation occurs from read-only paths

### Safe apply and rollback checks

Start with the controls that already have explicit rollback support.

Examples:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scudo.ps1 --action apply --control-id service.remote-registry.disabled --no-pause
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scudo.ps1 --action rollback --control-id service.remote-registry.disabled --no-pause

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scudo.ps1 --action apply --control-id service.print-spooler.disabled --no-pause
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scudo.ps1 --action rollback --control-id service.print-spooler.disabled --no-pause
```

Verify after each action:

- transcript file updated
- operation snapshot written to `Documents\Scudo\State\Operations`
- latest rollback snapshot created or removed as expected
- service state changed or restored correctly

### Pending reboot safety gate

Use a snapshot where Windows has a known pending reboot state and verify:

- apply is blocked
- rollback is blocked
- the blocking message is explicit

### `winget` and browser flow checks

Run these in the VM or Sandbox, not on hosted CI.

Verify:

- Bitwarden install path
- SimpleWall install path
- Helium install path
- Firefox install path
- Firefox policy merge behavior

## Self-hosted CI option

If you want CI to exercise real apply or rollback flows, add a self-hosted runner on a dedicated Windows 11 VM and label it clearly, for example:

- `self-hosted`
- `windows`
- `windows-11`
- `scudo`

Use that runner only for:

- read-only `--check-all` and `--export`
- tightly scoped apply and rollback tests on isolated controls
- snapshot-backed destructive testing

Do not point destructive jobs at a personal daily-driver machine.
