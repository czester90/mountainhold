# Tests

Automated tests for Mountainhold, using **GdUnit4** (`addons/gdUnit4/`, v6.2.x, MIT).

## Run all tests (headless)

```bash
GODOT_BIN=/opt/homebrew/bin/godot bash addons/gdUnit4/runtest.sh -a res://test
```

Exit code 0 = all green. Reports (JUnit XML + HTML) are written to `reports/` (gitignored).
Run a single suite with `-a res://test/enemy_test.gd`.

## Suites (characterization / smoke — lock behaviour before the component refactor)

- `enemy_test.gd` — besieger stats, `take_damage`, death signal, gate-attack cooldown (isolated).
- `ally_test.gd` — archer stats + target acquisition in/out of range (isolated, LOS clear).
- `siege_smoke_test.gd` — full `scenes/play.tscn` via GdUnit4 `scene_runner`: fortress builds,
  player fire spawns an arrow, gate-HP decreases + loss condition.

## Writing tests

Extend `GdUnitTestSuite`; methods named `test_*` are discovered. Use `scene_runner("res://…tscn")`
for scene/integration tests (`simulate_frames`, input sim, node access via `runner.scene()`),
`auto_free()` for isolated nodes, and fluent asserts (`assert_int(...).is_equal(...)`).

## Legacy harnesses (still valid, run directly, no framework)

- `scenes/mechanics_test.tscn` — drives the real player via `test_wish` through 10 traversal/combat
  scenarios (PASS/FAIL print). Superseded incrementally by `siege_smoke_test.gd`.
- `scenes/qa.tscn` — screenshot sweep to `screenshots/qa2/` (**run WINDOWED, not `--headless`** —
  the dummy renderer returns a null viewport texture).
- `scenes/probe.tscn` — raycast surface-height scans + module snap positions (recalibrate waypoints
  after geometry changes).
