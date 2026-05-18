# Contributing to scudo

## Reporting issues

Open an issue with:

- Windows 11 version (`winver`)
- PowerShell version (`$PSVersionTable.PSVersion`)
- scudo version (`scudo --version`)
- Steps to reproduce
- Expected vs actual behavior

Do not open issues for Windows Server -- scudo intentionally refuses to run on non-Windows 11 systems.

## Testing changes

Run the Pester test suite before opening a PR:

```powershell
pwsh -NoProfile -Command "Invoke-Pester ./tests/"
```

Validate the CLI surface on a real Windows 11 machine or VM before assuming behavior is correct. The hosted CI runs only smoke tests. See [docs/windows-testing.md](docs/windows-testing.md) for local lab guidance.

## Submitting changes

1. Fork the repo and create a topic branch.
2. Keep changes targeted -- do not refactor unrelated code in the same PR.
3. Run `pwsh -NoProfile -Command "Invoke-Pester ./tests/"` and confirm all tests pass.
4. Do not add dependencies without discussion.
5. Follow the existing style: lowercase command names, sentence-case descriptions.
6. Open a PR with a clear description of what changed and why.

## Code structure

- `scudo.ps1` -- entrypoint and orchestration
- `modules/entrypoint.ps1` -- CLI argument parsing and menu routing
- `modules/control-catalog.ps1` -- all hardening controls with metadata
- `gui/` -- WPF UI definitions

Control descriptions in the README should match the `WhatItDoes`, `WhyApply`, `WhyNotApply` fields in the catalog. If you add or rename a control, update both.
