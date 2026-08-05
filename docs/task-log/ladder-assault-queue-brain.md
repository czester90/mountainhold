# Ladder Assault Queue Brain

## Problem

Jednostki szturmujące drabiny korzystały z prostego `instance_id % 4`, więc kilka orków mogło wybierać ten sam punkt kolejki. Przy większej liczbie wrogów powodowało to klincz pod drabiną, drżenie i sytuacje, w których ork stoi pod murem zamiast poczekać albo wejść po drabinie.

## Zmiana

- Dodano `scripts/enemy/ladder_assault_brain.gd` jako wspólny komponent wyboru aktywnej drabiny, punktu kolejki i rezerwacji wejścia.
- `Enemy` tworzy `LadderAssaultBrain` i używa go w `_try_use_active_ladder()` oraz `_best_active_ladder()`.
- `LadderOrcEnemy` używa tego samego helpera przy wejściu na już postawioną drabinę i przy czekaniu w kolejce.
- `SiegeLadder` przechowuje stabilne `queue_slots` per unit, zwalnia je przy rezerwacji wspinaczki/zwolnieniu i generuje szerszą kolejkę 3 kolumny x wiele rzędów.
- Developer panel dostał linię `LadderAI`, żeby w grze widzieć, czy wrogowie są w stanie `idle`, `ladder`, `queued` albo `reserved`.

## Walidacja

- `godot --headless --path . --script /tmp/load_ladder_stack.gd` ładuje skrypty drabin i wrogów bez błędów parsowania.
- `godot --headless --path . --script /tmp/mountainhold_ladder_queue_probe.gd` potwierdza 10 unikalnych slotów kolejki, minimalny odstęp 1.15m.
- `godot --headless --path . --script /tmp/mountainhold_smoke_quit.gd` przechodzi kontrolowany smoke głównej sceny.

## Uwagi

- Nie uruchamiano `make test`; pełny test zostaje na koniec większego pakietu.
- Ostrzeżenie `Target and up vectors are colinear` pojawia się tylko w sztucznym probe z pionową drabiną `(0,0,0)->(0,10,0)`, nie w głównej scenie.
- Znane headless warningi o RID/ObjectDB przy wyjściu nadal występują i nie są nowe dla tej zmiany.
