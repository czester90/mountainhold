# Archer shooting component

Date: 2026-07-28

## Summary

Extracted projectile launch and ballistic aim compensation from `AllyArcher` into `ArcherShooting`.

`AllyArcher` still owns combat decisions, target choice, cooldown, kill progression and murder-hole bonus timing. The new component only performs the physical shot setup.

## Problem

`AllyArcher` mixed too many responsibilities:

- decide whether to shoot;
- choose target point;
- compute projectile lead/drop;
- instantiate and launch arrow;
- connect hit callbacks;
- handle kill progression.

This made every change to archer AI risky because low-level projectile launch code lived inside the same method as higher-level defender decisions.

## Implementation

### Files modified

1. `scripts/ally/archer_shooting.gd` — new component for lead/drop aim and arrow launch.
2. `scripts/ally/ally_archer.gd` — creates `ArcherShooting` and delegates `_shoot_at()` projectile launch to it.

## Key details

- `ArcherShooting.shoot()` returns the spawned arrow, flight time and computed aim point.
- `AllyArcher` still connects the `hit` signal so progression stays local.
- Murder-hole delayed damage still uses the returned flight time.
- Fire enable/disable flag remains in `AllyArcher`.
- No target selection logic moved in this slice.

## Validation

Full `make test` intentionally not run during this step; the user wants it only at the end.

Archer shooting probe:

```text
/opt/homebrew/bin/godot --headless --path . -s /tmp/mountainhold_archer_shooting_probe.gd
allies=20 missing_shooting=0 snapshots=20
archer shooting probe ok
```

Defender debug probe:

```text
/opt/homebrew/bin/godot --headless --path . -s /tmp/mountainhold_defender_debug_probe.gd
DefAI target:19 los:18 slot:12 | cooldown:18, no_los:1, no_target:1
defender debug probe ok snapshots=20
```

Known Godot shutdown ObjectDB/RID leak warnings still appear in headless runs and are not new to this change.
