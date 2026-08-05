# Staged Workflow & Approval Gates

> **STALE / HISTORICAL:** ten dokument opisuje dawny staged workflow środowiska. Aktualny kontekst gry i dalszy plan są w `CODEX.md`, `docs/current_game_mechanics.md` i `docs/task-log/godot_mechanics_refactor_plan.md`.

This project is built in small, strictly separated stages. **No stage begins
until the previous one is explicitly approved by the human reviewer.** Even if a
later stage looks trivial, it is not started early.

## Per-stage process

Every stage follows the same steps:

- **A — Inspection.** Inspect the current project; list dirs, scenes, scripts,
  asset formats, conflicts; state exactly which files will be created, modified,
  and left untouched.
- **B — Implementation plan.** Objective, scene hierarchy, files to create,
  dimensions, test method, acceptance criteria.
- **C — Implementation.** Only the current approved stage.
- **D — Automated validation.** Project import, startup, parser check,
  missing-resource / broken-path detection, scene loading, basic collision and
  scale checks.
- **E — Visual validation.** Run the test scene, capture screenshots into
  `res://screenshots/stage_XX/`.
- **F — Human test package.** Exact scene, launch command, controls, expected
  result, known limitations, checklist, screenshots, files created/modified.
- **G — Stop.** End with `STATUS: WAITING FOR HUMAN REVIEW` and wait.

Approval is given by the reviewer replying:

```
APPROVE STAGE XX
```

or a numbered list of corrections.

## Standard review screenshot angles

1. Front Overview
2. Elevated Overview
3. Ground-Level Approach
4. Courtyard View
5. Wall-Walk View
6. Side Profile
7. Scale Comparison

(Stage 00 has no fortress yet, so it captures the applicable subset:
front overview, elevated overview, ground approach, scale reference.)

## Global rules

- Work only on the current approved stage; do not implement future-stage features.
- No gameplay systems (enemies, combat, bows, weapons, destruction, waves,
  health, UI, inventory, economy, upgrades, multiplayer, procedural gameplay,
  save systems).
- Never modify raw imported assets; reuse via wrapper PackedScenes.
- Prefer simple collision primitives; avoid trimesh collision on everything.
- No decoration before layout is approved; don't hide structural problems with props.
- Prefer reusable scenes / MultiMesh over hundreds of unique nodes.
- Avoid extreme and non-uniform scaling.
- Descriptive, consistent node names.
- Do not delete or archive project files without explicit permission.

## Stage map

| Stage | Title | Status |
| --- | --- | --- |
| 00 | Project creation | Complete — approved |
| 01 | MCSTEEG asset import & audit | Complete — approved |
| T1 | Heightmap audit (Terrain3D + Motion Forge) | Complete — awaiting review |
| T2 | Heightmap fortress preparation (approved crop) | Blocked on T1 approval |
| 02 | Movement & inspection camera | Not started |
| 03 | Complete graybox composition | Not started |
| 04 | Terrain & cliff graybox refinement | Not started |
| 05 | First MCSTEEG wall test section | Not started |
| 06 | First tower test | Not started |
| 07 | Gatehouse test | Not started |
| 08 | Fortress asset replacement | Not started |
| 09 | Final low-poly terrain | Not started |
| 10 | Neutral environment art pass | Not started |

## Validation commands (macOS)

```bash
GODOT=/opt/homebrew/bin/godot
cd /Users/michalmrzyglod/dev/mountainhold

# Import / parser pass (headless)
"$GODOT" --headless --path . --import

# Run the current stage test scene headless for a fixed number of frames
"$GODOT" --headless --path . scenes/test/project_startup_test.tscn --quit-after 90

# Regenerate the Stage 00 review screenshots (opens a window briefly)
"$GODOT" --path . scenes/test/stage_00_capture.tscn
```
