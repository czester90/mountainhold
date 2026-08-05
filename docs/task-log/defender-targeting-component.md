# Defender targeting component

Date: 2026-07-28

## Summary

Extracted the first slice of defender target selection into `DefenderTargeting`.

`AllyArcher` now asks a component for target, aim point, LOS state and forced-gate state. The older local targeting methods remain as fallback while this refactor is staged.

## Problem

`AllyArcher._acquire()` was responsible for:

- applying player orders;
- prioritising rams, archers, closest enemies and gate threats;
- checking line of sight;
- choosing blocked fallback targets;
- setting internal LOS/forced-gate fields.

That made it hard to tell whether a bug lived in target choice, movement, LOS, or shooting.

## Implementation

### Files modified

1. `scripts/ally/defender_targeting.gd` — new component for order-aware target selection.
2. `scripts/ally/ally_archer.gd` — creates `DefenderTargeting` and delegates `_acquire()` to it.

## Key details

- The component returns a dictionary with `target`, `aim`, `has_los` and `forced_gate`.
- It uses `CombatRegistry` active enemies when available.
- It preserves existing order behavior: ram, enemy archer, closest, defend gate and retreat keep.
- It keeps blocked-target fallback so archers can decide to reposition instead of becoming idle.
- Existing local methods in `AllyArcher` stay temporarily as fallback during staged migration.

## Validation

Full `make test` intentionally not run during this step; the user wants it only at the end.

Defender targeting probe:

```text
/opt/homebrew/bin/godot --headless --path . -s /tmp/mountainhold_defender_targeting_probe.gd
allies=20 enemies=8 missing_targeting=0 with_target=19
defender targeting probe ok
```

Defender debug probe:

```text
/opt/homebrew/bin/godot --headless --path . -s /tmp/mountainhold_defender_debug_probe.gd
DefAI target:19 los:19 slot:11 | cooldown:19, no_target:1
defender debug probe ok snapshots=20
```

Known Godot shutdown ObjectDB/RID leak warnings still appear in headless runs and are not new to this change.
