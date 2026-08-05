# Siege lane spread and roles

## Problem

Ekipy z drabinami za często wyglądały jakby szły jednym pasem pod okolice bramy, mimo że castle model wystawia wiele slotów drabinowych na murze. Nie można jednak po prostu włączyć wszystkich slotów, bo zewnętrzne punkty na obecnym terenie leżą na stromych podejściach/górze i wcześniej powodowały spawny na szczytach oraz zacinanie jednostek.

## Zmiana

- `SiegeDirector` nadal filtruje sloty po powierzchni `wall`, odległości od bramy, wysokości, fizycznym gruncie i spadku terenu.
- Wybór slotów dla rezerwacji drabin, punktów ataku i spawnów używa teraz kolejności rozproszonej od skrajnych bezpiecznych slotów do środka, zamiast brać sortowanie centralne po kolei.
- `WaveSpawner` oznacza jednostki metadanymi `siege_role`, żeby debug/minimapa mogły odróżniać `ladder_carrier`, `ladder_escort`, `wall_assault` i `gate_engine`.
- Liczba fizycznych jednostek w falach pozostaje kontrolowana: obecny plan daje 34, 45, 60 i 77 aktywnych ciał, więc nie dokładamy ślepo tłumu ponad wcześniejsze problemy z FPS.

## Walidacja

- `/opt/homebrew/bin/godot --headless --path . --script /tmp/mountainhold_siege_balance_probe.gd`
  - fala 1: 4 ekipy drabin, 34 fizyczne jednostki
  - fala 2: 5 ekip drabin, 45 fizycznych jednostek
  - fala 3: 6 ekip drabin, 60 fizycznych jednostek
  - fala 4: 7 ekip drabin, 77 fizycznych jednostek
- `/opt/homebrew/bin/godot --headless --path . --script /tmp/mountainhold_siege_spread_probe.gd`
  - bezpieczne sloty: `[515.5, 484.5, 516.9, 483.1, 518.2, 481.8, 519.6, 480.4]`
  - rezerwacje po poprawce: `[480.4, 519.6, 481.8, 518.2, 483.1, 516.9, 484.5, 515.5]`

## Znane ostrzeżenia

Godot nadal wypisuje znane ostrzeżenia headless przy wyjściu (`ObjectDB`/`RID`/`resources still in use`). Nie były one nowym błędem tej zmiany.
