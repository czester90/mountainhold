# Unit Collision Debug And Separation

## Problem

Postacie miały fizyczne `CharacterBody3D` i collision shapes, ale debug panel nie pokazywał, czy aktywne jednostki faktycznie mają warstwy, maski i kształty kolizji. Dodatkowo bazowy `Enemy` separował się tylko od innych wrogów, a nie od łuczników/gracza na tym samym poziomie. `LadderOrcEnemy` w ścieżce dojścia do kolejki drabiny używał własnego `_physics_process` i omijał bazowy stuck recovery.

## Zmiana

- `Enemy._unit_separation_vector()` używa teraz wspólnej listy aktywnych wrogów, sojuszników i gracza, więc AI próbuje nie wciskać się w obrońców po wejściu na mur.
- `LadderOrcEnemy._try_enter_deployed_ladder()` wywołuje `_update_stuck_recovery()` podczas dojścia do kolejki drabiny.
- `Enemy` i `AllyArcher` dostały `collision_debug_snapshot()` z `layer`, `mask`, `shapes` i `floor`.
- Developer panel pokazuje `Collision units:X no_shape:Y bad_mask:Z`.

## Walidacja

- `godot --headless --path . --script /tmp/load_collision_stack.gd` ładuje zmienione skrypty bez błędów parsowania.
- `godot --headless --path . --script /tmp/mountainhold_collision_probe.gd` pokazał `checked=28 missing_shapes=0 bad_masks=0`.
- `godot --headless --path . --script /tmp/mountainhold_collision_timeline_probe.gd` po przyspieszonym starciu pokazał `checked=29 stuck=0 recoveries=0 close_overlaps=0`.
- `godot --headless --path . --script /tmp/mountainhold_smoke_quit.gd` przechodzi kontrolowany smoke sceny.

## Uwagi

- Nie uruchamiano `make test`; pełny test zostaje na koniec pakietu.
- Znane headless warningi o RID/ObjectDB przy wyjściu nadal występują.
