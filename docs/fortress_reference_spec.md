# Fortress Reference Spec — "Helm's Deep" target

Distilled from 4 reference images (LOTR film still, collectible diorama, aerial
render, UE render). This is the visual target the modular build works toward.
Muted, grounded, weathered — not a bright fantasy palace.

## Overall composition (the "D")

- A fortress wedged into a **rock gorge**: grey cliffs enclose the left, right
  and rear. The buildable ground is the flat/low **coombe** in front.
- A long, gently **curved curtain wall** (the *Deeping Wall*) sweeps across the
  valley and ties into the cliff at its far end — the curved side of the "D".
- Where the curtain meets the keep, a massive **round drum tower** anchors the bend.
- The **keep/bailey** is a stack of round + rectangular terraces climbing the
  rock, topped by a **great hall** built into the cliff — the rear/flat side.
- Enemy approach = the open coombe in front of the curtain wall.

## Element breakdown (with target dims + MCSTEEG mapping)

1. **Deeping curtain wall**
   - Long, gently curved, **level wall-walk** on top; **merlon parapet on the
     OUTER edge only** (open on the courtyard side).
   - Height ~6 m; **thick** (walk ~2 m clear) — currently too thin (single 0.4 m
     module) → should be **double thickness**.
   - Far end runs **into the cliff**; near end meets the drum tower.
   - MCSTEEG: `Wall_2x4` courses + `Wall_2x4_walkway` (parapet) top, stacked; two
     rows back-to-back for thickness.

2. **Round drum tower** (the signature piece)
   - Big **cylinder**, ~10–12 m diameter, taller than the wall (~9–12 m), with a
     battlemented crown and a walkable top reached from the wall-walk.
   - Angled **buttresses** at the base. Currently approximated by a ring of flat
     modules (octagonal, thin) → wants a **fatter, rounder** ring + conical/flat cap.
   - MCSTEEG: ring of `Wall_2x2`(+walkway); optionally `Roof_Cone` cap; `Tower_*`.

3. **Gatehouse**
   - A **large arched gate** (wooden doors) flanked by square towers with
     battlements; a **ramp/causeway** climbs to it along the tower base.
   - Opening target ~3.5 m wide × ~4 m high (kit gate opening is only ~2 m → stack
     two gate courses or a bespoke arch).
   - MCSTEEG: `Gate_2x4` + `Gate_Door`, flanking stacked towers; custom ramp.

4. **Inner bailey / courtyard**
   - A **round terraced courtyard** ringed by a low wall, inside the drum tower line.
   - Flat plateau floor. This is where the grand stair begins.

5. **Ramps + grand staircase**
   - **Curved ramps** hug the round tower; a **broad grand staircase** rises from
     the bailey up to the great-hall terrace.
   - Currently only 2 straight utility stairs → wants a wide central stair +
     curved ramp.

6. **Great hall** (rear, into the cliff)
   - Rectangular hall with a **row of ~5–6 arched openings (arcade)** + small
     windows above, set against the rock at the highest terrace.
   - MCSTEEG: `Building_Shape_Beveled_rectangle` masses + `Gate_2x4` arches as an
     arcade + `Window_*`; roof `Roof_rectangle`. (No true arcade asset — approximate.)

7. **Rock cliffs / backdrop**
   - Rugged grey rock frames left/right/rear and the wall's far anchor.
   - Currently the smooth heightmap hill → later replaced by low-poly cliff geometry.

## Material / mood

- **Muted grey ashlar** with a **green mossy** tint, weathered, low gloss.
- Cool overcast daylight; long soft shadows; slight aerial haze.
- No bright colours except small faction banners (green/white horse of Rohan).

## Build order (proposed, modular, each reviewed)

- **A.** Fix ground adhesion + entrances (this pass): flatten refresh, seat all
  columns, stairs onto the wall, tower platforms. ✅ in progress
- **B.** Thicken the curtain wall (double row) + outer-only parapet; anchor the
  far end into the cliff.
- **C.** Fatter, rounder drum tower with a proper walkable crown + buttresses.
- **D.** Proper gatehouse: taller arched gate + flanking towers + approach ramp.
- **E.** Inner bailey ring + grand staircase + curved ramp.
- **F.** Great hall (arched arcade) set into the rear cliff.
- **G.** Cliff geometry backdrop; then material/mood pass (moss, haze, lighting).

## Known kit limitations vs target

- Kit walls thin (0.4 m) → double up for thickness.
- Kit towers square 2 m → build round from rings; true round/buttressed drum
  needs many segments or custom geometry.
- Kit gate opening ~2 m tall → stack/бespoke for the ~4 m arch.
- No arcade / grand-stair / ramp assets → approximate from boxes + gate arches.
