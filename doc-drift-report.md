# Scudo Doc-Drift Analysis Report

**Repo:** Microck/scudo  
**Analyzed:** `readme.md` vs source code  
**Date:** 2026-04-05  
**Scope:** readme.md, scudo.ps1, modules/control-catalog.ps1, modules/entrypoint.ps1, modules/reporting.ps1, modules/safety.ps1, modules/gui.ps1

---

## Summary

| Severity | Count |
|----------|-------|
| P0 – Critical | 0 |
| P1 – High | 2 |
| P2 – Medium | 6 |
| P3 – Low | 4 |
| **Total** | **12** |

---

## Findings

### D-01 · readme "optional apps" section title mismatches catalog section ID and title

- **Severity:** P2 – Medium
- **Files:** `readme.md:250`, `modules/control-catalog.ps1:47-52`
- **Expected:** The readme has a section titled `### optional apps` documenting the four app controls. The control-catalog defines the matching section with `Id = 'apps'` and `Title = 'Supporting apps'`.
- **Actual:** The readme says "optional apps" while the catalog's canonical section title is "Supporting apps" (line 49). The menu label (scudo.ps1:609) says "Manage optional apps and browser tools", and the guided walkthrough page heading (scudo.ps1:1224) says "Optional apps and browser tools". There are three different names for the same concept.
- **Recommendation:** Decide on one canonical name. If "Supporting apps" is the catalog truth, update readme section header to match, or vice versa. At minimum, the readme should use the same term the catalog uses.

---

### D-02 · readme does not document the "Supporting apps" section as a distinct control section

- **Severity:** P2 – Medium
- **Files:** `readme.md:129-268`, `modules/control-catalog.ps1:47-52`
- **Expected:** The control-catalog defines 8 sections: firmware, windows, defender, network, physical, browser, identity, and **apps** (with DisplayRank 80).
- **Actual:** The readme documents 7 section headers under `## controls`: "firmware and boot", "windows protections", "microsoft defender", "network", "physical access", "browser", "identity and accounts", and "optional apps". The readme uses "optional apps" as a subheading, which is structurally similar, but does not indicate it is a formal section in the same way the others are. The catalog's formal section title is "Supporting apps" not "optional apps".
- **Recommendation:** Rename the readme section to `### supporting apps` to match the catalog's section title, or update the catalog to use "Optional apps".

---

### D-03 · readme missing "state" field in report documentation

- **Severity:** P1 – High
- **Files:** `readme.md:273-283`, `modules/reporting.ps1:62-84`
- **Expected:** The readme says `scudo --export` reports include these fields: state, section, tier, automation level, rollback note, what the control does, why you might apply it, why you might skip it.
- **Actual:** The actual markdown report (reporting.ps1 lines 70-83) includes many more fields per control: **id**, section, tier, automation, **kind**, state, **rollback-supported**, rollback-note, **summary**, what-it-does, why-apply, why-not-apply, **requires-admin**, **requires-reboot**, and optionally **before**, **after**, and **note** entries. The readme omits: `id`, `kind`, `rollback-supported`, `summary`, `requires-admin`, `requires-reboot`, `before`, `after`, and `note`.
- **Recommendation:** Update the readme's report section to list the full set of fields. At minimum, mention that each report includes id, kind, summary, requires-admin, requires-reboot, and rollback-supported in addition to the currently documented fields. This matters because users relying on the readme won't know what data to expect in exports.

---

### D-04 · readme reports section says "markdown and json" but does not mention file naming or location

- **Severity:** P3 – Low
- **Files:** `readme.md:271`, `modules/reporting.ps1:107-131`
- **Expected:** The readme says "`scudo --export` writes both markdown and json reports."
- **Actual:** The code writes files to `~/Documents/Scudo/Reports/` (or `$PWD/Scudo/Reports/` on non-Windows) with filenames like `scudo-20260405-141500.json` and `scudo-20260405-141500.md`. The readme gives no indication of where the files end up or what they are named.
- **Recommendation:** Add a sentence to the readme indicating the output path and filename pattern, e.g.: "Reports are saved to `Documents\Scudo\Reports\` as `scudo-<timestamp>.json` and `scudo-<timestamp>.md`."

---

### D-05 · readme install method 1 says bootstrap "opens the cli menu immediately" — code confirms `--cli`

- **Severity:** P3 – Low
- **Files:** `readme.md:36`, `get.ps1:47`
- **Expected:** The readme says: "the bootstrap downloads the current repo into `%localappdata%\scudo` and opens the cli menu immediately."
- **Actual:** The get.ps1 bootstrap (line 47) launches `scudo.ps1 --cli`. On Windows, without `--cli`, the entrypoint would normally check if it should launch the GUI (via `Test-ScudoShouldLaunchGui`). The `--cli` flag forces the CLI menu. The readme text is accurate — it does open the CLI menu. However, the readme says "cli menu" while the code actually shows `Start-ScudoMenu` when `--cli` is passed, which is the interactive numbered menu. This is consistent.
- **Recommendation:** No action needed. This is informational confirmation of consistency.

---

### D-06 · readme baseline preset omits `privacy.telemetry-services`

- **Severity:** P1 – High
- **Files:** `readme.md:102-108`, `modules/control-catalog.ps1:201-209`
- **Expected:** The baseline preset in the code includes all controls with `RecommendationTier = 'baseline'`: `mitigation.control-flow-guard`, `vbs.memory-integrity`, `driver-blocklist`, `privacy.telemetry-policy`, `privacy.telemetry-services`, and `service.remote-registry.disabled` (6 controls).
- **Actual:** The readme's baseline section (lines 102-108) lists: control flow guard, memory integrity, vulnerable driver blocklist, telemetry reduction, and remote registry disable. It **omits `privacy.telemetry-services`** even though that control has `RecommendationTier = 'baseline'` in the catalog (line 205). Users reading the readme will not know that disabling telemetry services is part of the baseline preset.
- **Recommendation:** Add `- telemetry services disable` (or similar wording) to the baseline list in the readme to match the actual baseline tier controls.

---

### D-07 · readme strict preset omits `app.simplewall-enable-filtering` nuance

- **Severity:** P2 – Medium
- **Files:** `readme.md:123`, `modules/control-catalog.ps1:237-244`
- **Expected:** The readme says strict includes "simplewall filtering when simplewall is already installed."
- **Actual:** The code has `app.simplewall-enable-filtering` at `RecommendationTier = 'strict'` with `AutomationLevel = 'automatic'`. However, the `Get-ScudoControlsForPreset` function (line 734-738) filters by `AutomationLevel -eq 'automatic'`, so it IS included in the strict preset. The readme's phrasing "when simplewall is already installed" is accurate since the detection function checks for simplewall. No drift here.
- **Recommendation:** No action needed.

---

### D-08 · readme does not document `--preset guided` as a valid command

- **Severity:** P2 – Medium
- **Files:** `readme.md:56-67`, `modules/control-catalog.ps1:72-78`
- **Expected:** The preset catalog defines three presets: `baseline`, `strict`, and `guided`. The command surface section of the readme (lines 56-67) only shows `scudo --preset baseline` and `scudo --preset strict`. There is no `scudo --preset guided` example.
- **Actual:** The `guided` preset exists in `Get-ScudoPresetCatalog` with `ApplyMode = 'guided'` and `TierOrder = @('guided')`. The `Get-ScudoControlsForPreset` function would return controls with tier `guided` when called with preset ID `guided`. The entrypoint logic (scudo.ps1:1904-1905) would process `--preset guided`. However, the guided preset includes only controls with `AutomationLevel` of `'manual'`, `'check-only'`, or `'guided'` — none with `'automatic'`. Since `Get-ScudoControlsForPreset` filters to `AutomationLevel -eq 'automatic'` by default, `--preset guided` would likely return zero automatic controls. This is a design choice (guided is meant to be interactive), but it's still a valid preset ID that could be passed on the CLI.
- **Recommendation:** Either add `scudo --preset guided` to the command surface section (noting it enters guided walkthrough mode), or explicitly state that guided mode is only available through the interactive menu option [4].

---

### D-09 · readme section header "optional apps" differs from all three code-level names

- **Severity:** P3 – Low
- **Files:** `readme.md:250`
- **Expected:** Consistent naming across readme, catalog, and menu.
- **Actual:** Three different names exist:
  - readme.md:250 — "optional apps"
  - control-catalog.ps1:49 — "Supporting apps" (section title)
  - scudo.ps1:609 — "Manage optional apps and browser tools" (menu label)
  - scudo.ps1:1224 — "Optional apps and browser tools" (page heading)
- **Recommendation:** Pick one canonical name and use it everywhere. Suggest: "Supporting apps" in the catalog and readme section header, "Manage optional apps and browser tools" as the menu label (since it's more descriptive in a menu context).

---

### D-10 · readme badge says "powershell 5.1+" but code uses features compatible with PS 5.1

- **Severity:** P3 – Low
- **Files:** `readme.md:10`, `scudo.ps1` (throughout)
- **Expected:** Badge says "powershell 5.1+"
- **Actual:** The code uses `Set-StrictMode -Version Latest`, `[ordered]@{}`, `[pscustomobject]@{}`, `foreach-object`, and other features that work fine in PowerShell 5.1. The code does not use any PowerShell 7+ exclusive features. Badge is accurate.
- **Recommendation:** No action needed.

---

### D-11 · readme menu option [6] label slightly differs from code

- **Severity:** P2 – Medium
- **Files:** `readme.md:90`, `scudo.ps1:609`
- **Expected:** The readme documents menu option [6] as: `[6] manage optional apps and browser tools`
- **Actual:** The code (scudo.ps1:609) says: `Write-ScudoMenuOption -Key '6' -Label 'Manage optional apps and browser tools'`. This is an exact match (case-insensitive). Verified consistent.
- **Recommendation:** No action needed. Confirmed consistent.

---

### D-12 · Short flag aliases `-h` and `-help` are undocumented

- **Severity:** P2 – Medium
- **Files:** `readme.md:56-67`, `modules/entrypoint.ps1:34-39`
- **Expected:** Users should know all valid flag variants.
- **Actual:** The entrypoint accepts `-h` (line 37), `-help` (line 34), and `--help` (line 31) as help flags. The readme only documents `--help`. The `-h` shorthand is a common convention users might try, but it's not mentioned anywhere in the readme.
- **Recommendation:** Add a note in the readme command surface or help section that `-h` and `-help` are also accepted as aliases for `--help`.

---

## Additional Observations (Informational, Not Drift)

### A-01 · Version consistency verified

- `scudo.ps1:9` — `$script:ScudoVersion = '0.2.0'`
- `modules/reporting.ps1:32` — `scudoVersion = '0.2.0'`
- Task header mentions "version 0.2.0"
- The readme does **not** explicitly state a version number (no "version 0.2.0" text in the body). This is fine — the version is shown via `--version` and in the banner. No drift.

### A-02 · Install instructions verified

- Method 1: `irm https://raw.githubusercontent.com/Microck/scudo/main/get.ps1 | iex` — confirmed `get.ps1` exists at repo root and downloads from `codeload.github.com/Microck/scudo/zip/refs/heads/main`.
- Method 2: `git clone` + `.\scudo.cmd --cli` — confirmed `scudo.cmd` exists and passes args through to `scudo.ps1`.
- The readme says bootstrap downloads to `%localappdata%\scudo` — confirmed in `get.ps1:9` as `Join-Path $env:LOCALAPPDATA 'scudo'`.

### A-03 · CLI flags verified against entrypoint.ps1

All flags documented in readme are present in `Get-ScudoParsedArguments`:
| Flag in readme | In entrypoint.ps1 |
|---|---|
| `--check-all` | Line 43 ✅ |
| `--preset <id>` | Line 49 ✅ |
| `--show <target>` | Line 53 ✅ |
| `--export` | Line 46 ✅ |
| `--gui` | Line 68 ✅ |
| `--cli` | Line 71 ✅ |
| `--version` | Line 40 ✅ |
| `--help` | Line 31 ✅ |
| `--action apply\|rollback` | Line 57 ✅ |
| `--control-id <id>` | Line 61 ✅ |
| `--no-pause` | Line 65 ✅ |

The entrypoint also accepts `-help` and `-h` (lines 34-38) which are **not documented** in the readme. Minor omission.

### A-04 · All control IDs cross-referenced

Every control ID in the catalog (`Get-ScudoControlMetadataMap`) has a corresponding entry in the readme's `## controls` section, and vice versa. The 28 controls are:

**Catalog controls → Readme documented:**
1. `mitigation.control-flow-guard` ✅
2. `defender.asr.office-child-process` ✅
3. `defender.asr.obfuscated-scripts` ✅
4. `defender.asr.email-executable-content` ✅
5. `vbs.memory-integrity` ✅
6. `driver-blocklist` ✅
7. `dns.quad9` ✅
8. `dns.doh` ✅
9. `service.remote-registry.disabled` ✅
10. `service.print-spooler.disabled` ✅
11. `device-install.restrict-new-devices` ✅
12. `privacy.telemetry-policy` ✅
13. `privacy.telemetry-services` ✅
14. `browser.firefox-noscript` ✅
15. `browser.firefox-sanitize` ✅
16. `account.create-standard-user` ✅
17. `app.simplewall-enable-filtering` ✅
18. `firmware.reboot-to-uefi` ✅
19. `secure-boot` ✅
20. `app.bitwarden` ✅
21. `app.simplewall` ✅
22. `app.helium` ✅
23. `app.firefox` ✅
24. `kernel-dma-protection` ✅
25. `bios-password` ✅
26. `account.standard-user` ✅
27. `password-manager` ✅

**No controls in readme missing from catalog. No controls in catalog missing from readme.** ✅

### A-05 · Description text comparison (WhatItDoes/WhyApply/WhyNotApply)

The readme's control descriptions are **paraphrased summaries** of the catalog's `WhatItDoes`, `WhyApply`, and `WhyNotApply` strings — they are not verbatim copies. This is by design (the readme is user-facing prose, the catalog is functional metadata). The semantic meaning is consistent across all 27 controls. No significant drift detected.

---

## Prioritized Fix Recommendations

| Priority | Finding | Action |
|----------|---------|--------|
| **P1** | D-03 | Add missing report fields to readme (id, kind, summary, requires-admin, requires-reboot, rollback-supported) |
| **P1** | D-06 | Add `privacy.telemetry-services` to baseline preset list in readme |
| **P2** | D-01 | Align section naming ("Supporting apps" vs "optional apps") |
| **P2** | D-02 | Use canonical section title from catalog in readme |
| **P2** | D-08 | Document or clarify `--preset guided` availability |
| **P2** | D-12 | Document `-h` and `-help` aliases in readme |
| **P3** | D-04 | Add report output path to readme |
| **P3** | D-09 | Consolidate to one canonical name for apps section |
