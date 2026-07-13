# MCSTEEG Castle & Fort Builder Pack — Asset Audit (Stage 01)

## Source

- **Pack:** MCSTEEG *Castle and Fort Builder Pack*
- **Origin on disk:** `~/Downloads/Castel Pack/`
- **Copied read-only into project:** `res://assets/raw/mcsteeg_castle/`
  - `Castles_and_Forts.glb` — **imported** (primary)
  - `source/` — `.blend`, two `.fbx`, `Textures/`, `Photoshop/` — kept for
    reference, **excluded from Godot import** via `source/.gdignore`
- Raw copies are `chmod a-w` (read-only) so they cannot be edited accidentally.

## Formats available & import decision

| Format | Present | Decision |
| --- | --- | --- |
| **GLB** | ✅ `Castles_and_Forts.glb` (716 KB, glTF 2.0, Blender I/O v4.1) | **Used** — self-contained, embeds textures, clean node names |
| GLTF | — | n/a |
| FBX | ✅ two variants | reference only |
| OBJ | ❌ | n/a |
| BLEND | ✅ | reference only (not imported — no Blender import pipeline configured) |

The GLB is a **single combined file containing 26 separate, cleanly-named mesh
nodes** — i.e. it is a **modular kit**, not one welded mesh. Godot imported it
without errors and extracted three embedded textures.

## Materials & textures (3 materials, 3 textures, all present)

| Material | Texture (embedded PNG) | Used by |
| --- | --- | --- |
| `Walls` | `Walls.png` (stone/wood atlas) | all stone & wood pieces |
| `Iron` | `Window_iron.png` | gate door, window bars |
| `Glass_window` | `Window_1.png` | glazed window |

- **No missing textures** — all three resolve after import (verified in catalog render).
- Most pieces use the single `Walls` atlas → good candidates for MultiMesh /
  batching in later stages.

## Global findings (read before Stage 05)

1. **Everything is built on a 2 m module grid.** Piece footprints are 2×2 or
   2×4 m; heights are a uniform **2.0 m**.
2. **Walls are 2 m tall, not 6 m.** To reach the ~6 m wall target from the spec
   we must **stack modules vertically** (e.g. 3 × 2 m), *not* scale them. A wall
   run then reads as: plain base course(s) + a `*_walkway` course on top (the
   walkway variants already carry a battlement/parapet — see catalog render).
3. **Native walls are thin vs the spec.** Plain walls are **0.40 m** thick;
   `*_walkway` variants are **1.20 m** deep (wall + walk platform). The spec
   targets ~2–2.5 m structural thickness and ~1.8–2.2 m clear walk. This is the
   **single biggest reconciliation decision** — see *Open questions* below.
4. **Gate opening is short.** `Gate_*` pieces are 4 m wide with an opening only
   ~2 m tall (piece height 2.05 m). The spec wants a ~3.5 m × ~4 m opening.
   Reaching 4 m of clear height needs stacked gate pieces or a bespoke connector.
5. **No collision in the source.** No `-col`/`-colonly` nodes; every piece is
   render-only. Simple primitive collision will be authored in the wrapper
   PackedScenes (Stage 05+), per the project rules.
6. **Pivots are snapping-friendly.** Almost every piece pivots at its **base
   (Y=0) and is XZ-centred**, so grid snapping is trivial. Exceptions: the
   `*_walkway` pieces are offset −0.40 m in X (the walk platform sits to one
   side — the interior face), and window/door inserts are offset to sit in a
   wall face. `Scaffle_Ramp` pivots below origin (−1.10 m) and needs a manual
   offset when placed.
7. **Orientation convention.** Wall length runs along **local Z**; wall
   thickness along **local X**; the exterior face normal is **+X** and the
   wall-walk sits on the **−X** (interior) side. Towers/roofs are radially
   symmetric.
8. **Scale is consistent** across the whole kit (Blender → glTF at 1 unit = 1 m;
   verified: the 1 m reference cube fills exactly one grid square).

## Per-asset records (26 pieces, sizes = world-space AABB, metres)

Type legend: **W**=wall, **WW**=wall+walk (rampart), **G**=gate, **T**=tower,
**R**=roof, **B**=building, **P**=prop, **I**=insert.

| # | Source name | Type | W×H×D (m) | Surf | Materials | Collision | Modular | Likely use | Notes / limitations |
|---|---|---|---|---|---|---|---|---|---|
| 0 | `Wall_2x2` | W | 0.40 × 2.00 × 2.00 | 1 | Walls | none | ✅ | Straight wall, 2 m run | Plain (no walk/parapet); thin |
| 1 | `Wall_2x4` | W | 0.40 × 2.00 × 4.00 | 1 | Walls | none | ✅ | Straight wall, 4 m run | Plain; base course for stacking |
| 2 | `Gate_2x4` | G | 0.56 × 2.05 × 4.00 | 1 | Walls | none | ✅ | Gate opening segment | Opening ~2 m tall only |
| 3 | `Tower_top_1` | T | 2.00 × 2.16 × 2.00 | 1 | Walls | none | ✅ | Tower crown / crenellated top | Caps a stacked tower |
| 4 | `Tower_Mid` | T | 2.00 × 2.00 × 2.00 | 1 | Walls | none | ✅ | Tower shaft (solid) | Stack to height |
| 5 | `Scaffle` | P | 0.80 × 1.70 × 2.00 | 1 | Walls | none | ✅ | Wooden defensive platform | Wood on Walls atlas |
| 6 | `Scaffle_Ramp` | P | 0.80 × 1.70 × 1.87 | 1 | Walls | none | ✅ | Ramp up to platform | **Pivot −1.10 Y** — offset on place |
| 7 | `Roof_Cone` | R | 2.63 × 2.23 × 2.63 | 1 | Walls | none | ✅ | Round tower roof | Overhangs 2 m footprint |
| 8 | `Gate_Door` | I | 0.13 × 1.48 × 1.14 | 1 | Iron | none | ✅ | Door leaf in gate | Only 1.48 m tall; single leaf; offset pivot |
| 9 | `Wall_2x2_walkway` | WW | 1.20 × 2.00 × 2.00 | 1 | Walls | none | ✅ | Rampart w/ walk, 2 m | Walk on −X; parapet on top |
| 10 | `Wall_2x4_walkway` | WW | 1.20 × 2.00 × 4.00 | 1 | Walls | none | ✅ | Rampart w/ walk, 4 m | Walk on −X; parapet on top |
| 11 | `Gate_2x4_doorway` | G | 0.56 × 2.05 × 4.00 | 1 | Walls | none | ✅ | Gate passage w/ doorway | Pairs with `Gate_2x4` |
| 12 | `Wall_corner_walkwayh` | WW | 1.20 × 2.00 × 1.20 | 1 | Walls | none | ✅ | Rampart corner | Turns the wall-walk 90° |
| 13 | `Wall_2x4_walkway_beveled` | WW | 1.20 × 2.00 × 4.00 | 1 | Walls | none | ✅ | Rampart variant (beveled) | Visual variety |
| 14 | `Tower_mid_hollow` | T | 2.00 × 2.00 × 2.00 | 1 | Walls | none | ✅ | Tower shaft (hollow) | Interior access / stair well |
| 15 | `Tower_Doorway` | T | 2.00 × 2.00 × 2.00 | 1 | Walls | none | ✅ | Tower base w/ door | Ground entry to tower |
| 16 | `Wall_2x2_ruined` | W | 0.40 × 2.00 × 2.00 | 1 | Walls | none | ✅ | Damaged wall, 2 m | Decorative / breach |
| 17 | `Wall_2x4_ruined` | W | 0.40 × 2.00 × 4.00 | 1 | Walls | none | ✅ | Damaged wall, 4 m | Decorative / breach |
| 18 | `Tower_mid_hollow_ruined` | T | 1.99 × 2.00 × 1.99 | 1 | Walls | none | ✅ | Damaged hollow tower | Decorative |
| 19 | `Building_Shape_Beveled_cube` | B | 2.00 × 2.00 × 2.00 | 1 | Walls | none | ✅ | Courtyard building block | Generic mass |
| 20 | `Building_Shape_Beveled_rectangle` | B | 2.00 × 2.00 × 4.00 | 1 | Walls | none | ✅ | Courtyard building block | Generic mass |
| 21 | `Roof_rectangle` | R | 2.25 × 0.68 × 4.50 | 1 | Walls | none | ✅ | Gable roof for building | Matches 2×4 building |
| 22 | `Roof_Cube` | R | 2.51 × 0.61 × 2.51 | 1 | Walls | none | ✅ | Pyramid roof | Matches 2×2 building |
| 23 | `Gate_2x4_Beveled` | G | 0.56 × 2.05 × 4.00 | 1 | Walls | none | ✅ | Gate segment (beveled) | Variant of `Gate_2x4` |
| 24 | `Window_bars` | I | 0.26 × 1.43 × 1.14 | 2 | Walls, Iron | none | ✅ | Barred window insert | Sits in a wall face; offset pivot |
| 25 | `Window_glass` | I | 0.26 × 1.43 × 1.14 | 2 | Walls, Glass_window | none | ✅ | Glazed window insert | Sits in a wall face; offset pivot |

## Coverage vs the fortress shopping list

| Needed | Covered by | Gap |
| --- | --- | --- |
| Walls | `Wall_2x2/2x4` (+ ruined) | thin; stack for height |
| Wall corners | `Wall_corner_walkwayh` | walk-corner only; plain corner = butt-join two walls |
| Wall ends | (none explicit) | terminate against tower / cliff instead |
| Towers | `Tower_Mid`, `_hollow`, `_Doorway`, `Tower_top_1` (+ ruined) | build by stacking; ~2 m diameter footprint |
| Gates | `Gate_2x4`, `_doorway`, `_Beveled`, `Gate_Door` | opening short (~2 m) — see finding #4 |
| Stairs | **(none)** | use `Scaffle_Ramp`, or build stair geometry, or tower interior |
| Battlements | built into `*_walkway` + `Tower_top_1` | not a standalone piece |
| Wooden platforms | `Scaffle`, `Scaffle_Ramp` | ramp pivot quirk |
| Defensive props | `Scaffle` family, windows, door | limited |

## Open questions for the fortress build (decide at/ before Stage 05)

1. **Wall thickness & scale.** The kit is thin (0.40 m plain / 1.20 m rampart)
   vs the spec's 2–2.5 m. Options: (a) accept the kit's thinner look as the
   grounded style; (b) place walls as a double back-to-back run to read ~2.4 m
   thick; (c) apply a modest uniform upscale (~1.5–1.8×) accepting altered
   texture scale and grid. **Recommendation: (b)** — keeps the 2 m grid and
   texture scale intact while satisfying thickness/walk-width targets.
2. **Wall height.** Stack 3 × 2 m courses (2 plain + 1 `*_walkway` on top) for a
   ~6 m rampart with integral parapet. Confirm this reading is acceptable.
3. **Gate height.** Native opening ~2 m. To approach the ~4 m target, stack two
   gate courses or author a bespoke connector arch. Confirm desired approach.
4. **Stairs.** No dedicated stair asset. Prefer (a) `Scaffle_Ramp`, (b) simple
   custom stair geometry, or (c) tower-interior stairs?

*(These are recorded, not actioned — Stage 01 is audit only.)*
