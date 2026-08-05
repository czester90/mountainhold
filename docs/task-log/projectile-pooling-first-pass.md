# Projectile pooling first pass

## Problem

Salwy łuczników tworzyły dużo strzał runtime. Każda strzała była osobnym `RigidBody3D` z meshem, kolizją i sygnałami. W dużych bitwach to powinno działać z puli, nie przez ciągłe `instantiate()` / `queue_free()`.

## Zmiana

- Dodano `ProjectilePool` dla strzał gracza/sojuszników.
- `scripts/player/arrow.gd` dostał tryb pooled:
  - reset stanu przy `launch()`,
  - czyszczenie listenerów `hit`,
  - `recycle_requested` zamiast `queue_free()` dla strzał z puli.
- `ArcherShooting` i `FpsBowPlayer` pobierają strzały przez `ProjectilePool.acquire_player_arrow()`.
- Recykling jest deferred, żeby nie usuwać `CollisionObject3D` bezpośrednio w callbacku fizyki.

## Walidacja

- `/opt/homebrew/bin/godot --headless --path . --script /tmp/load_projectile_pool_stack.gd`
  - ładuje pool, strzałę, komponent strzelania i gracza bez błędów parsowania.
- `/opt/homebrew/bin/godot --headless --path . --script /tmp/mountainhold_projectile_pool_probe.gd`
  - potwierdza reuse tej samej strzały: `reused=true parent=true visible=true`.
- `/opt/homebrew/bin/godot --headless --path . --script /tmp/mountainhold_approach_perf_compare.gd`
  - nie ma już błędu `Removing a CollisionObject node during a physics callback`.

## Uwaga

Probe headless po tej zmianie nadal jest zmienny i nie pokazał stabilnej poprawy średniego FPS. To oznacza, że samo poolingowanie strzał nie usuwa głównego freezu. Nadal trzeba zrobić:

- pooling/prefab deploy drabin,
- spatial grid dla jednostek,
- scheduler AI/targetowania,
- ewentualnie pooling samych jednostek.
