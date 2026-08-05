# Archer Reposition And Ballistic LOS

## Problem

Łucznicy mieli logikę szukania lepszej pozycji po braku LOS, ale ruch do wybranego punktu był przypadkowo wcięty pod `return`, więc kod był martwy. W praktyce łucznik mógł znaleźć potencjalną pozycję, po czym dalej stać. Dodatkowo LOS sprawdzał prostą linię do punktu celu, ale strzała leci łukiem balistycznym, więc mogła zostać wypuszczona mimo tego, że jej tor uderzy w mur albo podłogę.

## Zmiana

- Naprawiono martwy kod w `AllyArcher._reposition_for_target()`: łucznik faktycznie idzie do znalezionej pozycji ogniowej.
- `ArcherShooting` dostał `has_clear_ballistic_launch()`, który próbkowanym raycastem po torze strzały sprawdza świat przed wypuszczeniem strzały.
- `AllyArcher._shoot_at()` używa ballistic guard; jeśli tor jest zablokowany, nie tworzy strzały, ustawia `blocked_arc` i wymusza repozycjonowanie.

## Walidacja

- `godot --headless --path . --script /tmp/load_archer_stack.gd` ładuje stos łucznika bez błędów parsowania.
- `godot --headless --path . --script /tmp/mountainhold_archer_ballistic_probe.gd` potwierdza, że cel za ścianą blokuje strzał przed wystrzeleniem (`clear=false`).
- `godot --headless --path . --script /tmp/mountainhold_archer_state_probe.gd` potwierdza 20 łuczników z komponentem `ArcherShooting` i debug snapshotami.
- `godot --headless --path . --script /tmp/mountainhold_smoke_quit.gd` przechodzi kontrolowany smoke sceny.

## Uwagi

- Nie uruchamiano `make test`; pełny test zostaje na koniec pakietu.
- Znane headless warningi o RID/ObjectDB przy wyjściu nadal występują.
