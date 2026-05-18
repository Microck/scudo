# ADR-001: PowerShell as the Implementation Language

| Field    | Value       |
|----------|-------------|
| Number   | ADR-001     |
| Status   | Accepted    |
| Date     | 2025-04-04  |

## Context

Scudo is a Windows 11 hardening utility that applies security controls across firmware, OS, Defender, network, physical, browser, identity, and application layers. It interacts deeply with Windows-specific APIs including the registry, Group Policy, Windows Management Instrumentation (WMI/CIM), Windows Defender cmdlets, and the Windows Presentation Foundation (WPF) for its GUI.

Several languages were considered for the implementation:

- **PowerShell** -- native Windows scripting language with direct access to .NET, registry, WMI/CIM, and Defender cmdlets.
- **Python** -- cross-platform general-purpose language with libraries like `winreg` and `pywin32` for Windows management.
- **Go** -- compiled, single-binary distribution with `golang.org/x/sys/windows` for Win32 API access.
- **C# / .NET** -- compiled language with first-class Windows API access, but heavier toolchain requirements.

Key requirements influencing the choice:
1. Direct, idiomatic manipulation of Windows security settings (registry keys, Group Policy objects, Defender ASR rules, firewall rules).
2. Minimal dependency footprint -- users should not need to install runtimes or package managers.
3. Administrator-level operations that integrate naturally with Windows security primitives.
4. Ability to produce a WPF GUI without external UI frameworks.

## Decision

We chose PowerShell as the sole implementation language for Scudo.

PowerShell is pre-installed on every supported Windows 11 target, eliminating the need for users to install Python, Go toolchains, or .NET SDKs. More importantly, the operations Scudo performs -- reading and writing registry keys (`Get-ItemPropertyValue`, `Set-ItemProperty`), invoking WMI/CIM queries (`Get-CimInstance`), configuring Windows Defender (`Set-MpPreference`, `Add-MpPreference`), and managing Windows Firewall rules -- are all first-class PowerShell cmdlets. No wrapper layers or FFI bindings are required.

The WPF GUI is constructed by loading XAML markup via `[xml]` casting and `InitializeComponent()`-style pattern, which is idiomatic in PowerShell and requires no additional frameworks.

PowerShell's `Start-Transcript` / `Stop-Transcript` mechanism provides built-in audit logging of every console interaction, which Scudo leverages directly in its safety module (`modules/safety.ps1`).

## Consequences

**Positive:**
- Zero runtime dependencies on target machines -- PowerShell 5.1 ships with Windows 11.
- Direct access to Windows security APIs without bridging layers, reducing code complexity and failure modes.
- WPF GUI support through native .NET interop -- no Electron or external UI toolkit needed.
- PowerShell transcripts provide out-of-the-box audit logging.
- Users can inspect, audit, and modify the source code with a text editor, increasing trust for a security tool.

**Negative:**
- PowerShell execution policies and AMI (Anti-Malware Interface) may flag or block the script on hardened systems, requiring bypass instructions.
- Limited cross-platform portability -- Scudo cannot run on Linux or macOS (which is acceptable given the Windows-only scope).
- PowerShell's object pipeline and loose typing can make the codebase harder to statically analyze compared to compiled languages.
- Distribution is file-based rather than a single compiled binary -- users receive a directory of `.ps1` files rather than an executable.
- Performance is adequate for a configuration tool but would be unsuitable for high-throughput or latency-sensitive workloads.
