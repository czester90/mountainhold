# Ladder Entry Reservations

## Problem

Po dodaniu stabilnych slotów kolejki jednostka nadal mogła dostać rezerwację wspinaczki i zacząć `TraversalController` od punktu `foot`, nawet jeśli fizycznie stała jeszcze w kolejce za drabiną. To tworzyło ryzyko krótkiego przeskoku/teleportu do stopy drabiny i błędnego stanu `_climbing` u drabiniarzy.

## Zmiana

- `SiegeLadder` ma teraz osobne `entry_reservations`, czyli etap między kolejką a realnym wspinaniem.
- Tylko jednostka z rezerwacją wejścia może zejść z kolejki do `entry_point()` przy capacity drabiny.
- `reserve_climb()` przenosi jednostkę z rezerwacji wejścia do aktywnych wspinaczy i czyści jej slot kolejki.
- `Enemy._try_use_active_ladder()` najpierw prowadzi jednostkę do stopy drabiny, a dopiero potem uruchamia `TraversalController`.
- `LadderOrcEnemy` po postawieniu drabiny nie próbuje od razu startować wspinaczki z miejsca deployu; wraca przez kolejkę i etap wejścia.
- Naprawiono stan `_climbing`: drabiniarz ustawia go tylko wtedy, gdy faktycznie ruszył traversal po drabinie.

## Walidacja

- `godot --headless --path . --script /tmp/load_ladder_stack.gd` ładuje stos drabin/wrogów bez błędów parsowania.
- `godot --headless --path . --script /tmp/mountainhold_ladder_entry_probe.gd` potwierdza capacity wejścia: przy `climb_capacity=1` druga jednostka nie wchodzi do entry, gdy pierwsza ma rezerwację.
- `godot --headless --path . --script /tmp/mountainhold_smoke_quit.gd` przechodzi kontrolowany smoke głównej sceny.

## Uwagi

- Nie uruchamiano `make test`; pełny test zostaje na koniec pakietu.
- Znane headless warningi o RID/ObjectDB przy wyjściu nadal występują.
