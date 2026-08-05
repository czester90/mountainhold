# Defender AI debug snapshot

Date: 2026-07-28

## Summary

Added a visible debug snapshot for every friendly archer and surfaced it in the developer panel.

This makes defender behavior inspectable: target, line of sight, firing slot, cooldown, movement state and current reason are now visible without guessing from screenshots.

## Problem

When archers stood still or did not shoot, the game did not clearly explain why. The developer panel showed movement state counts, but not the combat decision state:

- no target;
- target but no LOS;
- moving to a slot;
- has LOS but waiting on cooldown;
- fire disabled;
- forced gate behavior;
- reserved firing slot.

Without that, every screenshot required manual investigation.

## Implementation

### Files modified

1. `scripts/ally/ally_archer.gd` — adds `defender_debug_snapshot()` and records `_last_debug_reason`.
2. `scripts/ui/developer_panel.gd` — adds `DefAI` summary and top archer focus rows.

## Debug fields

Each archer snapshot includes:

- display name, level and kills;
- current order;
- navigation state and driver;
- target label and distance;
- LOS flag;
- forced-gate flag;
- reserved firing slot flag;
- cooldown;
- current reason.

## Developer panel output

The panel now shows:

```text
DefAI target:19 los:17 slot:12 | cooldown:17, no_los:2, no_target:1
  Wall Archer Orc 32m LOS slot cd0.8
```

This gives immediate feedback when archers are blocked, have no target, are repositioning, or simply waiting on cooldown.

## Validation

Full `make test` intentionally not run during this step; the user wants it only at the end.

Defender debug probe:

```text
/opt/homebrew/bin/godot --headless --path . -s /tmp/mountainhold_defender_debug_probe.gd
DefAI target:19 los:17 slot:12 | cooldown:17, no_los:2, no_target:1
defender debug probe ok snapshots=20
```

Controlled scene smoke:

```text
/opt/homebrew/bin/godot --headless --path . -s /tmp/mountainhold_smoke_quit.gd
controlled smoke ok
```

Known Godot shutdown ObjectDB/RID leak warnings still appear in headless runs and are not new to this change.
