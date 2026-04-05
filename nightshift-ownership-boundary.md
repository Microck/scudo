# Ownership Boundary Analysis — Scudo

**Task:** Ownership Boundary Suggester
**Repo:** Microck/scudo
**Date:** 2026-04-04
**Tool:** Nightshift v3 (GLM 5.1)

## Summary

Scudo is a Windows 11 hardening CLI with 6 source files totaling ~3,500 lines. The ownership boundaries are well-defined by module, but two files have grown large enough to warrant attention.

---

## Module Ownership Map

| Module | Lines | Domain Owner | Responsibility |
|--------|-------|-------------|----------------|
| `scudo.ps1` | ~1640 | UI / orchestration | Menu system, UI rendering, text wrapping, page navigation, argument parsing dispatch |
| `modules/control-actions.ps1` | ~1249 | Security controls | Registry operations, service management, ASR rules, DNS config, Firefox policies, winget installs |
| `modules/control-catalog.ps1` | ~753 | Data / catalog | Control definitions, section catalog, preset catalog — pure data, no side effects |
| `modules/gui.ps1` | ~983 | GUI / WinForms | Windows Forms interface, event handlers, layout |
| `modules/safety.ps1` | ~289 | State / rollback | Snapshot save/restore, preflight checks, operation logging |
| `modules/reporting.ps1` | ~131 | Export | Markdown/JSON report generation |
| `modules/entrypoint.ps1` | ~109 | CLI args | Argument parsing, GUI-vs-CLI decision logic |

---

## Boundary Assessment

### Clean Boundaries (no changes needed)

1. **`modules/control-catalog.ps1`** — Pure data definitions. No imports, no side effects. Ideal ownership boundary. Any change to control definitions touches only this file.

2. **`modules/safety.ps1`** — Isolated state management. Reads/writes JSON snapshots to disk. No coupling to UI or control logic beyond the `Control` parameter shape.

3. **`modules/reporting.ps1`** — Single-responsibility export module. Takes data in, writes files out.

4. **`modules/entrypoint.ps1`** — Minimal CLI arg parser. No dependencies beyond stdlib.

### Boundary Concerns

#### P2 — `scudo.ps1` combines UI primitives with orchestration

`scudo.ps1` (1640 lines) defines both:
- **UI primitives**: `Write-ScudoText`, `Get-ScudoWrappedLines`, `Write-ScudoMenuOption`, `Write-ScudoBanner` (~400 lines)
- **Orchestration/page functions**: `Show-ScudoMenu`, `Show-ScudoGuidedWalkthrough`, `Show-ScudoRollbackPage`, etc. (~1200 lines)

The UI primitives have no dependency on the control catalog or safety modules. They could be extracted into `modules/ui.ps1` (~400 lines), leaving `scudo.ps1` as the pure orchestrator (~1200 lines).

**Recommendation:** Extract UI primitives when scudo.ps1 grows past 2000 lines or when a non-menu consumer needs `Write-ScudoText` directly.

#### P2 — `modules/control-actions.ps1` mixes detection and mutation

At 1249 lines, this file contains paired `Get-ScudoStatus*` (detection) and `Set-Scudo*` (mutation) functions for every control. The detection functions are read-only; the mutation functions write to registry/services/filesystem.

The catalog (`control-catalog.ps1`) references these by function name (`DetectFunction`, `ApplyFunction`, `RollbackFunction`), so the coupling is by convention (string-based dispatch), not by file structure.

**Recommendation:** No split needed now. The pairing pattern (detect + apply in same file) is consistent and aids discoverability. If the control count doubles, consider grouping by domain (network controls, registry controls, app installs).

#### P3 — `modules/gui.ps1` duplicates orchestration logic from `scudo.ps1`

GUI page functions (`Show-ScudoGuiMainPage`, `Show-ScudoGuiFirmwarePage`, etc.) duplicate the navigation flow from the CLI menu functions in `scudo.ps1`. Both call the same control-catalog and control-actions functions.

**Recommendation:** Acceptable duplication — CLI and GUI have fundamentally different interaction models (Read-Host vs WinForms events). Merging them would add complexity for no practical benefit.

---

## Dependency Graph

```
entrypoint.ps1 ─────┐
control-catalog.ps1 ─┤
control-actions.ps1 ─┤── dot-sourced by scudo.ps1
safety.ps1 ──────────┤
reporting.ps1 ───────┤
gui.ps1 ─────────────┘

gui.ps1 ── uses ──> control-catalog.ps1, control-actions.ps1, safety.ps1
                  (also dot-sourced via scudo.ps1)
```

No circular dependencies. All modules are dot-sourced at startup (no lazy loading).

---

## Cross-Cutting Concerns

| Concern | Where | Notes |
|---------|-------|-------|
| `New-ScudoStatus` shape | `control-actions.ps1` | The status object (State, Summary, BeforeValue, AfterValue, Notes) is the main contract between modules. No type enforcement — relies on PSCustomObject convention. |
| `$script:ScudoRoot` | `scudo.ps1` | Set once at startup, used to resolve module paths and data files. Global mutable state. |
| `$script:ScudoVersion` | `scudo.ps1` | Hardcoded version string. Used in banner and would be used by any update checker. |

---

## Recommendations

1. **No immediate refactoring needed.** The 6-module structure is well-aligned with domain boundaries for a 3500-line PowerShell project.
2. **Extract `modules/ui.ps1`** if scudo.ps1 exceeds 2000 lines (currently 1640). The UI primitives are self-contained.
3. **Document the `New-ScudoStatus` contract** with a comment block specifying required/optional fields. This is the most important implicit interface in the codebase.
4. **Consider domain-grouped control files** only if the control count exceeds 50 (currently ~30 controls).
