# Wall Landing Settle And Ladder Orc Fight

## Problem

Wrogowie wchodzący po drabinie kończyli traversal w bardzo podobnym punkcie `landing`, co tworzyło stos jednostek na koronie muru. Dodatkowo `LadderOrcEnemy` ma własny `_physics_process`, który po wejściu na mur omijał bazowe `Enemy._fight_on_wall()`. Przez to nowy stan `settle` nie był wykonywany i drabiniarze mogli stać po wejściu zamiast ruszać do obrońców.

## Zmiana

- `SiegeLadder` rozdaje stabilne `landing_settle_point_for_unit()` dla jednostek schodzących z drabiny.
- `Enemy` zapamiętuje `_wall_settle_goal` przy starcie traversal po drabinie.
- `Enemy._fight_on_wall()` najpierw wykonuje krótki rozsyp po lądowaniu, a dopiero potem wybiera obrońcę przez `WallAssaultBrain`.
- `wall_assault_debug_summary()` pokazuje `settle`, kiedy unit nadal wychodzi z punktu lądowania.
- `LadderOrcEnemy._physics_process()` po `_on_wall` deleguje do bazowego `_fight_on_wall()`, więc drabiniarze używają tej samej logiki walki na murze co inni wrogowie.

## Walidacja

- `godot --headless --path . --script /tmp/load_ladder_stack.gd` ładuje stos drabin/wrogów bez błędów parsowania.
- `godot --headless --path . --script /tmp/mountainhold_ladder_landing_probe.gd` potwierdza unikalne punkty rozsypu po lądowaniu, minimalny odstęp 0.90m.
- `godot --headless --path . --script /tmp/mountainhold_wall_timeline_probe.gd` po fixie pokazał `on_wall=2 counts={ "target": 2 }`, czyli drabiniarze po wejściu na mur zaczęli wybierać cele zamiast wisieć w `settle`.
- `godot --headless --path . --script /tmp/mountainhold_smoke_quit.gd` przechodzi kontrolowany smoke sceny.

## Uwagi

- Nie uruchamiano `make test`; pełny test zostaje na koniec pakietu.
- Znane headless warningi o RID/ObjectDB przy wyjściu nadal występują.
