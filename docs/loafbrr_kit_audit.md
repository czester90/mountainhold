# Loafbrr "Castle Wall Kit" — Audit & Adoption Assessment

## Source

- **Pack:** loafbrr *Castle Wall Kit* — https://loafbrr.itch.io/castle-wall-kit
- **On disk:** `~/Downloads/LoafbrrAssets/CastleWallKit`
- **Copied into project:** `assets/raw/loafbrr_castle_wall_kit/` (only `gltf/` + `textures/`
  — the kit's own `.tscn`/`.tres`/MeshLibs use kit-root `res://` paths that don't
  resolve here, so we load the gltf directly and build materials in code).
- **Licence:** **CC0 1.0** (public domain, no attribution). No AI used.

## Facts

| Property | Value |
| --- | --- |
| Pieces | **116** meshes, **4 materials** (BrickWall, BrickTrims, BrickFloor, WallStickers) |
| Module | **6 m × 6 m** grid (matches our ~6 m wall height!) |
| Style | low-poly, **PBR brick** (BaseColor + Normal + MRAO), trimsheet UV, 1k textures |
| Formats | Unity, **Godot** (native), Blender, FBX, glTF |
| Source geometry | one self-contained `.gltf` (base64 buffer, no external images) |
| Note | textures are wired via the kit's `.tres` materials, **not** in the gltf |

## Categorised inventory ("split")

Two wall families: **`Courtine_*`** = full-height curtain-wall body pieces;
**`Wall_*`** = wall/parapet-level pieces. Both on the 6 m grid.

| Group | Pieces | Use |
| --- | --- | --- |
| **Curtain wall (Courtine)** | Wall, Slits, Slit, Door_Square, Door_Arch, Window_Square, Window_Arch | tall curtain-wall body, 6×6×0.77 m |
| **Wall (upper)** | Wall_Wall, Wall_Slits, Wall_Slit, Wall_Door/Window_* | wall/parapet level |
| **Battlements** | Wall_Battlements (+ corner round/bevel/square), 45° | **crenellated tops** (1 m tall cap) |
| **Machicolations** | Wall_Machicolation (+ corners), 45° | overhanging defensive top (1.85 m) |
| **Corners** | Wall_Corner + Courtine_Corner: **round / bevel / square** (+ slits) | **turn the wall / junctions** |
| **Floor (wall-walk)** | Wall_Floor, Wall_Floor_Round, Wall_Floor_Beveled | 6×6 walk-top decking |
| **Stairs** | **Stairs, Stairs_Wall_A, Stairs_Wall_B**, bartizan_stairs, bartizan_corner_stairs | **stairs that hug the wall** (medieval) |
| **Bartizans** | corners (round/bevel/square, slits, bottom/top) + halves | overhanging corner **turrets** |
| **Pillars** | Pillar (1.8×6×1.8), Pillar_Top | slender towers / posts |
| **Arc / gate** | Courtine_Half_Arc_*, Arc_Wall_Top, Half_Arc_Tunnel_* | **arched gate / tunnel** |
| **Bridge / ramp** | Wall_Bridge_Arc_Floor, Half_Arc_A/B (+ walls) | causeway / ramp |
| **Brattice** | Brattice_Wall_1/2 | wooden **hoardings** |
| **Door stickers (decals)** | portcullis, gate_arch, gate_square, door, windows | gate/window inserts |
| **45° parts** | walls, battlements, machicolation, floor, courtine variants | octagonal / 45° layouts |

Sample measured dims (m): Courtine_Wall 6×6×0.77 · Corner_Round/Square 6×6×6 ·
Battlements 6×1×0.77 · Machicolation 6×1.85×0.77 · Wall_Floor 6×0×6 ·
Stairs 6×6×6 · Stairs_Wall_A/B 6×6 (flat, against wall) · Pillar 1.8×6×1.8.

## Recommendation — **YES, adopt it now**

This kit is a far better fit than MCSTEEG (generic 2 m bits) or the current
plain-box solids:

1. **Purpose-built modular castle** with the exact parts the design needs.
2. **CC0**, Godot-native, **6 m module = our wall height** (level tops for free).
3. **Directly fixes both of your current complaints:**
   - *Wall running into the towers* → use the **Corner** pieces (round/bevel/square)
     to turn the wall and meet towers cleanly at 6 m cells.
   - *Stairs must hug the wall (medieval)* → **Stairs_Wall_A/B** are exactly that —
     flights flush against the inner wall face.
4. **Proper battlements & machicolations** as real geometry (no more box merlons).
5. **Arched gate + tunnel + bridge** pieces for a real gatehouse & causeway.
6. **PBR brick textures** → the muted stone look, retiring the flat-grey boxes.

Trade-off: the fortress builder is reworked to a **6 m grid** (straight segments +
corner pieces form the D; round corners / bartizans / pillars make towers). Loaded
at runtime via `GLTFDocument` to sidestep a headless-import quirk; brick materials
(BaseColor/Normal/MRAO) built in code and assigned per surface by material name.

## Proposed rebuild plan (on approval)

- **A.** Runtime-load the gltf; build 3 brick materials; catalog scene to verify look.
- **B.** Curtain wall on the D arc from 6 m Courtine segments + Corner pieces at
  bends; Wall_Floor walk; Battlements on top.
- **C.** Towers from round corners / bartizans / pillars at the bends & flanks.
- **D.** Gate from the arc/tunnel + portcullis pieces; bridge causeway.
- **E.** Stairs_Wall flights, one per curtain span, hugging the wall.
- **F.** Keep the horseshoe terrain enclosure.

## Assembly findings (validated on a piece test)

How the pieces actually snap (from reading the author's example scene + a wall/
tower/stair assembly test):

- **Wall** = `Courtine_Wall` (6 m panel) with `Wall_Battlements` (6 m) on the top
  edge as the crenellated parapet + a floor for the walk. Do NOT hand-build
  merlons from boxes — the kit battlement piece aligns 1:1 with the panel.
- **Battlements** are the `Wall_Battlements` / `Wall_Battlements_Corner_*` pieces,
  sat on the wall/tower top edge. They are 6 m, so they only look right on a 6 m
  grid (a hexagon of radius 6 has chord 6 → they fit a hex tower with no overhang).
- **Stairs** = the kit `Stairs` piece (6×6×6, solid steps) placed seated on the
  ground in a grid cell, climbing 6 m to the wall-walk. Not a floating box ramp.
- **Round tower**: 4× `*_Corner_Round` do NOT close into a drum by simple
  90° rotation about the shared centre; a hexagon of 6 `Courtine_Wall` panels
  (radius 6) is the reliable round-ish tower here.
- **Tower access** is from the wall-walk (platform at walk height) — no internal
  tower stair.
