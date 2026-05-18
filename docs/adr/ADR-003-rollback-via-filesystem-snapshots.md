# ADR-003: Rollback via Filesystem-Based State Snapshots

| Field    | Value       |
|----------|-------------|
| Number   | ADR-003     |
| Status   | Accepted    |
| Date     | 2025-04-04  |

## Context

Scudo applies system-level security hardening controls that modify the Windows registry, Group Policy settings, Windows Defender configuration, and firewall rules. Users need the ability to undo these changes -- either to revert a specific control or to restore the system to its pre-hardening state.

The rollback system must handle:
- Controls that modify registry values (e.g., enabling Credential Guard, configuring ASR rules).
- Controls with diverse state representations -- some are boolean registry keys, others are multi-value policies or Defender preferences.
- Selective rollback of individual controls, not just full-system restore.
- Persistent state that survives reboots and tool restarts.

Two broad approaches were considered:

1. **Filesystem-based JSON snapshots** -- Before applying each control, capture the control's current state as a JSON file on disk. Rollback reads the snapshot and restores the recorded values.
2. **Registry backup (`.reg` export)** -- Use `reg.exe export` or PowerShell registry drives to dump affected registry keys to `.reg` files before modification. Rollback re-imports the `.reg` file.
3. **System Restore points** -- Leverage Windows System Restore (`Checkpoint-Computer`) to create restore points before applying controls.

## Decision

We chose filesystem-based JSON snapshots stored under the user's `Documents/Scudo/State/` directory.

The implementation in `modules/safety.ps1` uses a two-tier state model:

- **Operations log** (`State/Operations/`): Timestamped JSON files recording every apply and rollback action with before/after status, control metadata, and transcript path. This provides a full audit trail.
- **Latest snapshots** (`State/Latest/`): A single JSON file per control ID representing the most recent applied state. On rollback, this file is deleted to indicate the control is no longer managed.

Before each control is applied, `Save-ScudoOperationState` captures the control's `BeforeStatus` (the result of its check function) alongside metadata. If the control declares a `RollbackFunction`, the snapshot enables that function to restore the prior state.

This approach was chosen over registry export because:
- **Uniform representation**: Scudo controls modify diverse targets (registry, Defender preferences, firewall rules, file-system settings). A registry-only backup cannot capture non-registry state. JSON snapshots store whatever the control's check function returns, regardless of the backing store.
- **Selective rollback**: JSON snapshots are keyed by control ID, enabling per-control rollback without restoring unrelated settings.
- **Human readability**: JSON files can be inspected with any text editor, giving users confidence in what will be restored.
- **No elevated tooling required**: `.reg` file export/import and System Restore both require specific privileges and have edge cases (64-bit vs 32-bit registry redirection, System Restore size limits).

System Restore was rejected because it captures the entire system state (not per-control), requires significant disk space, and provides coarse rollback granularity unsuitable for undoing individual hardening controls.

## Consequences

**Positive:**
- Rollback is granular -- individual controls can be reversed without affecting others.
- Snapshots capture arbitrary state representations (registry values, Defender configurations, policy settings) in a uniform JSON format.
- The operations log provides a complete audit trail of all apply and rollback actions with timestamps.
- No dependency on `reg.exe`, System Restore, or external backup tools.
- Snapshots are stored in the user's Documents folder -- visible, inspectable, and easy to back up manually.

**Negative:**
- Rollback is only available for controls that explicitly implement a `RollbackFunction`. Controls without rollback support (e.g., firmware-level changes) cannot be automatically reversed.
- Snapshots capture the state as reported by each control's check function -- if the check function has a bug or misses a side effect, rollback may be incomplete.
- Filesystem-based state is vulnerable to user deletion or corruption -- if a snapshot file is removed, rollback information is lost.
- The snapshot represents the last apply operation only -- there is no stack of historical states to roll back through multiple apply/rollback cycles (though the operations log preserves the history for manual review).
- No transactional guarantees -- if a control partially applies (e.g., sets 3 of 5 registry keys before failing), the snapshot records the pre-apply state, but rollback may not correctly handle the partially-applied intermediate state.
