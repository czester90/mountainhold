# Mountain Fortress Environment — Project Overview

A grounded, low-poly mountain fortress **environment** built in Godot 4.7 for
macOS. This repository builds the environment only, in strictly gated stages.
There is **no gameplay** here yet: no enemies, combat, weapons, waves, health,
UI systems, economy, progression, or save systems.

## Engine & target

- **Engine:** Godot 4.7 stable
- **Renderer:** Forward+ (`rendering/renderer/rendering_method = forward_plus`)
- **Language:** GDScript
- **Platform:** macOS desktop 3D
- **Language of all code/docs/config:** English

## Scale convention

- **1 Godot unit = 1 meter.**
- **Character reference height = 1.8 m** (the reference capsule in every test scene).

Target fortress dimensions (built in later stages, listed here as the contract):

| Element | Target |
| --- | --- |
| Wall height | ~6 m |
| Wall thickness | ~2–2.5 m |
| Wall-walk clear width | ~1.8–2.2 m |
| Battlement height | ~1.1–1.3 m |
| Tower height | ~9–10 m |
| Tower width / diameter | ~7–8 m |
| Gate opening | ~3.5 m wide × ~4 m high |
| Gatehouse depth | ~7–9 m |
| Courtyard | ~30 × 35 m |
| Enemy approach depth | ~70–90 m |

## Visual direction

Grounded, dark, raw. Late-1990s / early-2000s PC-game look, PSX-inspired
low-poly geometry, muted stone colours, realistic architectural proportions.
No cartoon terrain, no toy shapes, no fantasy/palace ornamentation.

## Directory structure

```
res://
├── assets/
│   ├── raw/            mcsteeg_castle/ (untouched imports), reference/
│   ├── processed/      fortress/, terrain/, props/  (wrapper PackedScenes)
│   ├── materials/
│   └── textures/
├── scenes/
│   ├── catalog/        asset inspection scenes
│   ├── environment/    fortress/, terrain/, props/
│   ├── characters/     environment inspector (later stage)
│   ├── cameras/
│   ├── test/           per-stage test scenes
│   └── ui/
├── levels/             full composed levels
├── scripts/
│   ├── editor/         validation / tooling (e.g. screenshot capture)
│   ├── environment/
│   └── test/
├── docs/
├── screenshots/        stage_XX/ review captures
└── tests/
```

Directories for combat / enemies / waves / weapons / economy / progression are
intentionally **not** created.

## Asset sources

- **Castle structures** (later stages): *MCSTEEG Castle and Fort Builder Pack*,
  copied read-only into `assets/raw/mcsteeg_castle/`. Raw imports are never
  edited; reusable pieces are exposed via wrapper PackedScenes in
  `assets/processed/`.
- **Terrain / cliffs:** custom low-poly geometry (procedural / hand-built /
  Blender), not cartoon terrain packs. Large forms first; rocks only later to
  hide transitions.

## Current status

- **Stage 00 — Project creation: complete, awaiting review.**
  Clean project, directory structure, neutral config, Forward+ startup test
  scene with a 1.8 m reference capsule and a live debug readout.

See `docs/workflow.md` for the staged process and approval gates.
