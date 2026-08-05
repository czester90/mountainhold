# Ladder Lifecycle Debug And Entry Fix

## Problem

Po dodaniu kolejki nadal brakowało widoczności, gdzie dokładnie blokują się drabiny: w kolejce, przy wejściu, czy podczas wspinania. Przyspieszony probe lifecycle pokazał też realny błąd: samo ocenianie kandydatów drabin tworzyło sloty kolejki na wielu drabinach, a `SiegeLadder.queue_point()` ustawiał kolejkę po złej stronie `normal`, czyli potencjalnie bliżej muru zamiast po stronie pola.

## Zmiana

- `SiegeLadder.debug_summary()` raportuje `queued`, `entry`, `climbing`, `capacity`, `hp` i `deployed`.
- Developer panel pokazuje linię `Ladders active:X queue:Y entry:Z climb:A/B broken:C`.
- `LadderAssaultBrain.choose_active_ladder()` używa teraz `queue_preview_point()` i nie tworzy slotów kolejki podczas samego scoringu.
- `SiegeLadder.queue_point()` przenosi kolejkę na stronę pola: `foot + normal * distance`.
- `SiegeLadder.entry_point()` stoi minimalnie przed drabiną (`foot + normal * 0.65`), żeby unit nie próbował wejść w kolizję muru.
- Dodano timeout `ENTRY_RESERVATION_TIMEOUT`, żeby zablokowany ork nie trzymał rezerwacji wejścia bez końca.

## Walidacja

- `godot --headless --path . --script /tmp/load_ladder_stack.gd` ładuje stos drabin/wrogów bez błędów parsowania.
- `godot --headless --path . --script /tmp/mountainhold_ladder_entry_probe.gd` potwierdza capacity wejścia.
- `godot --headless --path . --script /tmp/mountainhold_ladder_lifecycle_probe.gd` po poprawce pokazał `ladders=4 queue=35 entry=3 climb=1 enemies=34 on_wall=1`, czyli lifecycle przeszedł do realnego wspinania i wejścia na mur.

## Uwagi

- Nie uruchamiano `make test`; pełny test zostaje na koniec pakietu.
- Znane headless warningi o RID/ObjectDB przy wyjściu nadal występują.
