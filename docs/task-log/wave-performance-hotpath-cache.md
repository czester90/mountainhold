# Wave performance hotpath cache

## Objaw

Podczas aktywnej fali gra mocno tnie, a po wybiciu wrogów wraca płynność. To wskazuje na koszt zależny od liczby jednostek, a nie na sam zamek lub render sceny.

## Główna przyczyna

`CombatRegistry.active_enemies()`, `active_allies()`, `active_rams()` i `active_ladders()` synchronizowały grupy Godot oraz prunowały listy przy każdym wywołaniu. W trakcie fali te metody są wołane przez łuczników, wrogów, minimapę, HUD, developer panel, separację jednostek i targetowanie.

Przy 20 łucznikach i kilkudziesięciu wrogach robiło się z tego wiele pełnych skanów grup i kopii list w jednej klatce.

## Zmiana

- `CombatRegistry` synchronizuje/prunuje grupy maksymalnie raz na bieżący process/physics frame.
- Kolejne wywołania w tej samej klatce zwracają kopię już utrzymywanej listy bez ponownego `get_nodes_in_group`.
- `AllyArcher` nie wykonuje pełnego acquire celu co physics tick. Target jest odświeżany co około 0.22–0.30 s albo natychmiast, gdy obecny cel ginie, wychodzi poza scenę lub poza zasięg.

## Dlaczego to powinno pomóc

Najdroższe operacje były proporcjonalne do liczby jednostek i liczby systemów pytających o stan walki. Cache usuwa mnożnik „każdy system x każdy frame x pełny skan grupy”. Throttle targetowania usuwa drugi mnożnik „każdy łucznik x 60 razy/s x wszyscy wrogowie x raycast LOS”.

## Walidacja

- `/opt/homebrew/bin/godot --headless --path . --script /tmp/load_perf_stack.gd` ładuje `CombatRegistry` i `AllyArcher` bez błędów parsowania.
- `/opt/homebrew/bin/godot --headless --path . --script /tmp/mountainhold_wave_perf_smoke.gd` przechodzi realną scenę przez pierwsze sekundy fali: `samples=625 avg_fps=88.7 max_enemies=15`.

## Następny krok

Jeśli po tej zmianie nadal tnie podczas dużej fali, kolejne miejsce do profilowania to liczba raycastów LOS/ballistic arc oraz separacja jednostek przy zagęszczeniu pod drabinami.
