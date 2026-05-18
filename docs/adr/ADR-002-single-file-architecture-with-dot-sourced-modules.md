# ADR-002: Single-File Architecture with Dot-Sourced Modules

| Field    | Value       |
|----------|-------------|
| Number   | ADR-002     |
| Status   | Accepted    |
| Date     | 2025-04-04  |

## Context

Scudo consists of a main entry point (`scudo.ps1`, ~1924 lines) and six module files in a `modules/` directory:

| Module                   | Responsibility                                      |
|--------------------------|-----------------------------------------------------|
| `control-actions.ps1`    | Per-control apply/check/status helper functions      |
| `control-catalog.ps1`    | Section and preset definitions, control registry     |
| `safety.ps1`             | Preflight checks, snapshots, operation state, transcripts |
| `reporting.ps1`          | Markdown and JSON report generation                  |
| `entrypoint.ps1`         | CLI argument parsing and main entry flow             |
| `gui.ps1`                | WPF-based graphical interface                        |

These modules are loaded at the top of `scudo.ps1` using PowerShell's dot-sourcing operator:

```powershell
. (Join-Path -Path $script:ScudoRoot -ChildPath 'modules/control-actions.ps1')
. (Join-Path -Path $script:ScudoRoot -ChildPath 'modules/safety.ps1')
# ... etc.
```

Alternatives considered:
1. **PowerShell modules (`.psm1` / `.psd1`)** -- Formal module system with explicit exports, versioning, and `Import-Module`.
2. **Monolithic single file** -- All code in one `.ps1` file with no modular separation.
3. **Binary module (C# compiled)** -- A compiled DLL exposing PowerShell cmdlets.

## Decision

We use dot-sourced script files organized in a `modules/` directory rather than formal PowerShell modules (`.psm1`/`.psd1`).

The primary motivation is **deployment simplicity and discoverability**. Scudo is distributed as a single directory that users clone or download. Dot-sourcing ensures all functions are loaded into the caller's scope with no module path configuration, no `Install-Module` step, and no `PSModulePath` manipulation. A user runs `.\scudo.ps1` and everything works.

Formal PowerShell modules introduce infrastructure overhead -- manifest files (`.psd1`), module versioning semantics, `PSModulePath` requirements, and a publishing workflow -- that provide no meaningful benefit for a self-contained tool that is not published to the PowerShell Gallery.

The module files provide **logical separation of concerns** (safety checks vs. catalog definitions vs. reporting) without the ceremony of the formal module system. Functions share a single scope, which simplifies cross-module calls (e.g., `safety.ps1` functions call `control-actions.ps1` functions like `Test-ScudoWindows` without import boilerplate).

A monolithic single file was rejected because the combined codebase (~3400 lines across all files) would make navigation and maintenance significantly harder without providing any runtime benefit.

## Consequences

**Positive:**
- Zero-configuration deployment -- clone and run, no module installation or path setup required.
- Flat function scope allows direct cross-module calls without `Import-Module` or `using module` statements.
- Users can easily inspect individual module files to understand what a specific subsystem does.
- Adding a new module is as simple as creating a `.ps1` file and adding one dot-source line to `scudo.ps1`.
- No module manifest maintenance, no versioning ceremony for an unreleased library.

**Negative:**
- No encapsulation -- all functions from all modules are visible in the global session scope, increasing the risk of name collisions with user-defined functions.
- No explicit export control -- PowerShell modules allow `Export-ModuleMember` to define a public API surface; dot-sourcing exposes everything.
- Testing requires loading all modules together rather than testing individual modules in isolation (though the current test suite handles this by dot-sourcing the same files).
- Module load order matters -- if a function in `safety.ps1` depends on a function from `control-actions.ps1`, the latter must be dot-sourced first. This is managed by explicit ordering in `scudo.ps1` but is fragile under refactoring.
- No built-in module versioning or dependency management.
