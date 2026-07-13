# Dependencies

## Engine

- **Godot 4.7.stable.official** (`5b4e0cb0f`), Forward+, macOS (Apple Silicon + Intel).

## Terrain3D (GDExtension)

- **Version:** `v1.0.2-stable` (released 2026-05-19)
- **Location:** `res://addons/terrain_3d/`
- **Source:** https://github.com/TokisanGames/Terrain3D/releases/tag/v1.0.2-stable
- **Plugin enabled:** yes (`project.godot` → `[editor_plugins]`)
- **`compatibility_minimum`:** 4.4
- **Official support:** Godot **4.4 – 4.6+** (release notes: "brings support for Godot 4.6";
  maintainer re 4.7: *"I don't know about 4.7"*). There is **no** stable release
  explicitly targeting 4.7.
- **macOS binary:** universal Mach-O (`arm64` + `x86_64`) framework, **unsigned**.
  The `com.apple.quarantine` xattr was stripped from `addons/terrain_3d/bin/`
  after download (`xattr -dr com.apple.quarantine`) so Gatekeeper allows loading.

### Verification on Godot 4.7 (this machine, 2026-07-13)

Because no stable build officially targets 4.7, it was **verified empirically**
(project rule: no unverified *development* builds — this is a stable build, tested):

- `ClassDB.class_exists("Terrain3D")` → **true**; instantiation → **ok**.
- `Terrain3DData.import_images()` of the Motion Forge heightmap → **16 regions,
  height range (−0.000002, 177.45) m**, no errors.
- Full audit scene imports + renders + collides headless and windowed on 4.7.

**Fallback if a future Godot update breaks the extension:** generate terrain as a
plain Godot `ArrayMesh` from the heightmap (no plugin). The heightmap analysis
and import maths already live in `scripts/`.

## Source assets (copied read-only, not committed as blobs)

- **MCSTEEG Castle and Fort Builder Pack** — `assets/raw/mcsteeg_castle/` (GLB).
- **Motion Forge "Grand Mountain" Height Map** — `assets/raw/terrain/motion_forge/`
  (EXR + PNG). **Licence: CC0 1.0** (no attribution required).
  Large binaries are git-ignored; re-copy from `~/Downloads/Grand Mountain Height Map Shared`.
