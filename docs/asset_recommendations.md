# Asset Recommendations

This project currently has a playable low-poly siege prototype, but most units are still procedural
proxy bodies. The best next art step is to replace unit visuals without changing gameplay scenes.

## Style target

- Low-poly / early-3D medieval, readable at distance.
- Muted materials that fit the dark mountain fortress.
- Godot-friendly formats first: glTF / GLB, then FBX if needed.
- Prefer CC0 or clear commercial-use licenses.

## Recommended packs

| Use | Pack | Why it fits | License notes |
| --- | --- | --- | --- |
| Hero / ally / enemy humanoids | Quaternius RPG Character Pack / Animated Knight Pack / modular fantasy outfits | Rigged low-poly fantasy characters with humanoid animation options; good base for infantry, archers, and elite variants. | Quaternius assets are published as free game assets; check each pack page before import. |
| Weapons / props | Quaternius Modular Weapons Pack or Fantasy Props MegaKit | Bows, arrows, shields, swords, crates, banners, and battlefield dressing in a consistent low-poly style. | Fantasy Props MegaKit lists CC0 and glTF support. |
| Castle / siege props | Kenney Castle Kit | Includes castle and siege-themed props in glTF/FBX/OBJ; useful for ram dressing, debris, barricades, and silhouettes. | CC0 1.0 Universal. |
| Retro medieval environment | Kenney Retro Medieval Kit / Retro Fantasy Kit | Strong match for PSX-inspired simple geometry and low-resolution medieval props. | CC0. |
| Paid archer upgrade | YOHA Stylized Archers Pack | Godot 4.5+ tested, animated male/female archers, quick route to better defender/enemy archer silhouettes. | Paid itch.io asset; redistribution prohibited. |
| Bow-only fallback | Kubuz520 Low Poly Bow Arrow and Quiver | Lightweight bow/quiver props if the current bow GLTF needs replacement or variants. | Free download; attribution/link requested by author. |

## Import order

1. Pick one humanoid source for all soldiers first, so silhouettes and animation scale stay consistent.
2. Import one defender archer, one enemy archer, one infantry body, and one ram dressing pass.
3. Wrap each raw asset in `assets/processed/` scenes; do not edit raw imports directly.
4. Connect visuals through unit `type_id` / `role`, leaving combat stats in `data/*.tres`.
5. Capture a small visual audit scene before replacing units in `scenes/play.tscn`.

## Current unit data hooks

- Player hero preset: `res://data/player_hero.tres`
- Ally archer preset: `res://data/ally_archer.tres`
- Enemy infantry preset: `res://data/enemy_infantry.tres`
- Enemy archer preset: `res://data/enemy_archer.tres`
- Enemy ram preset: `res://data/enemy_ram.tres`
- Final boss ram preset: `res://data/enemy_bossram.tres`
