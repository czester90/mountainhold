# Heightmap Audit — Motion Forge "Grand Mountain"

Stage: **Heightmap Audit** (terrain, before fortress graybox). Nothing is cropped
or committed here — this stage inspects the source and **proposes** a terrain
area for human approval.

## Source

| Property | Value |
| --- | --- |
| Pack | Motion Forge Pictures — *Grand Mountain Height Map* |
| On disk | `~/Downloads/Grand Mountain Height Map Shared` |
| Copied read-only to | `res://assets/raw/terrain/motion_forge/` (EXR + PNG) |
| Licence | **CC0 1.0** (no attribution required) |
| Formats available | **EXR (32-bit float)**, TIF (32-bit float), PNG (16-bit) |
| Format used | **EXR** (float, highest precision, no banding) |
| Resolution | **4096 × 4096** |
| Bit depth | EXR/TIF 32-bit float · PNG 16-bit (avoid 8-bit) |

## Measured data (from the EXR, sampled)

| Metric | Value |
| --- | --- |
| Raw value range | **min 0.00000 · max 0.07389** (span 0.07389 — *not* 0–1) |
| Peak location | pixel (2264, 2248) ≈ normalized **(0.55, 0.55)** — near centre |
| Edge heights | **all four edges ≈ 0.0** |
| Banding / stepping | **none** — 989 / 1000 distinct levels among samples (smooth float) |
| Distribution | one dominant low bucket (flat plain) + thin tail to the peak |

### Apparent terrain shape

A **single, steep, isolated peak rising from a flat plain**, roughly centred,
with sharp radiating ridges and gullies down its flanks. It is **not** a rolling
range — it is one dramatic massif.

- **Useful valleys:** the **flat plain surrounding the mountain** (height ≈ 0) is
  a broad, readable natural **enemy-approach corridor**; gullies between the
  radiating spurs give secondary draws.
- **Useful ridges:** the radiating spurs and steep flanks are strong candidates
  for **left/right cliff connections** and a **rear mountain backdrop**.
- **Terrain edge problems:** **none.** The massif is fully contained; every
  border is flat/zero, so there is generous margin and no cut-off mountain at any
  edge — cropping anywhere central is safe.

### Is the supplied diffuse map usable?

**Not as the final material.** The diffuse is 8-bit, saved **linear** (the readme
says it "may look washed out … increase the gamma"), and its baked lighting/colour
does not match this project's **dark, raw, muted** direction. Recommendation: use
a **custom muted rock material** for the final terrain (Stage 09/10) and keep the
diffuse only as optional reference. For this audit the terrain uses Terrain3D's
**neutral-grey** debug shading + a vertex grid (measurement markers) — no textures.

### Estimated memory

| Item | Estimate |
| --- | --- |
| EXR on disk | ~105 MB |
| Full 4096² loaded as float Image | ~268 MB RAM (**why we downsample immediately**) |
| Downsampled 1024² RF preview image | ~4 MB |
| Terrain3D regions (16 × 256², preview) | ~a few MB |

## The inspection preview (what the screenshots show)

To inspect the **whole** mountain compactly without a 4 km world (and without
cropping the source), the full map was **downsampled to 1024²** and imported into
Terrain3D as a **1024 × 1024 m** preview at vertex spacing 1.0, vertical
`scale = 2400` → **peak ≈ 177 m**. This is an *inspection* terrain, not the final
compact world. Scale relationship: **1 preview-metre = 4 source-pixels**.

## Recommendations (for the Fortress Preparation stage — pending approval)

| Recommendation | Value |
| --- | --- |
| **Recommended crop area** | preview **x[208–592], z[308–692]** (384 × 384 m) → source-px **x[832–2368], z[1232–2768]** (a 1536² window), on the **west flank** facing the plain |
| **Recommended final world** | **384 × 384 m** terrain, **160 × 180 m** playable region |
| **Recommended vertical scale** | target **50–80 m max relief across the playable area** — this is *less* than the preview's 177 m peak, so lower `scale` (≈ 900–1100) or exclude the sharp summit from the playable band; tune once the plateau base elevation is fixed |
| Fortress orientation | wall faces **west** (down onto the flat plain = approach); peak is the **rear (east) backdrop**; spurs form **left/right cliffs** |

### Important finding — the site is steep

The mountain flanks are steep everywhere (local relief 40–75 m over 50 m spans on
the mid-slope; see `scripts/editor/sample_terrain.gd`). **There is no natural flat
bench** on the mountain. Any fortress placement therefore requires a **carved
foundation plateau** (that is exactly the Fortress Preparation stage's job:
flatten only the footprint + courtyard + terrace, with natural transitions).
The proposed location is shown as a starting point — the reviewer may prefer to
slide it lower toward the toe (gentler) or onto the south-east shoulder.

## Reproduce

```bash
GODOT=/opt/homebrew/bin/godot
cd /Users/michalmrzyglod/dev/mountainhold
"$GODOT" --headless --path . --script res://scripts/editor/analyze_heightmap.gd   # stats + API
"$GODOT" --headless --path . --script res://scripts/editor/sample_terrain.gd       # height/relief grid
"$GODOT" --path . scenes/test/heightmap_import_test.tscn                            # interactive
"$GODOT" --path . scenes/test/heightmap_audit_capture.tscn                          # screenshots
```
