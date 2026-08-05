# Wall Assault Brain

## Problem

Wrogowie, którzy weszli po drabinie na mur, nadal używali częściowo zaszytej w `Enemy` logiki: wybierali obrońcę lokalnie, a gdy nie mieli celu, szli do twardo wpisanego punktu nacisku. To było kruche przy dynamicznym schemacie zamku i utrudniało debugowanie przypadków, w których ork stoi na murze albo ignoruje łuczników.

## Zmiana

- Dodano `scripts/enemy/wall_assault_brain.gd` jako osobny komponent decyzyjny dla wroga na murze.
- `Enemy` tworzy `WallAssaultBrain` obok `UnitLocomotion` i `TraversalController`.
- Wybór obrońcy po wejściu na mur idzie przez `CombatRegistry`, uwzględnia łuczników i gracza, dystans poziomy, różnicę wysokości oraz trasę po grafie zamku.
- Ruch do obrońcy używa wspólnego `CastlePathfinder`, zamiast lokalnej kopii algorytmu w `Enemy`.
- Usunięto twardy pressure point `(301, y, 500)`; fallback wybiera najbliższy sensowny slot taktyczny zamku, a w ostateczności gracza albo pozostanie na miejscu.
- Dodano `wall_assault_debug_summary()` i linię `WallAI` w developer panelu.

## Walidacja

- `godot --headless --path . --script /tmp/load_enemy_wall.gd` ładuje `WallAssaultBrain` i `Enemy` bez błędów parsowania.
- `godot --headless --path . --script /tmp/mountainhold_wall_brain_unit_probe.gd` potwierdza wybór najbliższego łucznika jako celu.
- `godot --headless --path . --script /tmp/mountainhold_smoke_quit.gd` przechodzi kontrolowany smoke głównej sceny.

## Uwagi

- Nie uruchamiano `make test`, zgodnie z decyzją, że pełny zestaw idzie dopiero na końcu większego pakietu zmian.
- Znane ostrzeżenia Godot przy wyjściu headless o RID/ObjectDB dalej występują i nie są traktowane jako nowe dla tej zmiany.
