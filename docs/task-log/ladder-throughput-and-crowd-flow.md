# Ladder throughput and crowd flow

## Objaw

Na screenach `shot_084`–`shot_087` drabiny stoją przy murze, ale większość orków stoi pod nimi. Czasem pojedynczy wróg zaczyna wspinaczkę, reszta wygląda jak zablokowana kolejka.

## Przyczyna

Drabina miała `climb_capacity = 1`, jedno wejście i jeden tor wspinania. Przy większej fali wyglądało to jak bug AI, bo tłum realnie czekał na jeden wolny slot. Dodatkowo próg wejścia `LADDER_ENTRY_REACHED = 0.55` był zbyt ciasny przy kolizji kilku jednostek przy stopie drabiny.

## Zmiana

- `SiegeLadder` ma teraz domyślnie `climb_capacity = 3`.
- Drabina przydziela boczne pasy wspinania (`0`, `-0.55m`, `+0.55m`), więc kilku orków nie próbuje iść po identycznej linii.
- `entry_point_for_unit()` daje osobny punkt wejścia dla jednostki.
- `climb_points_for_unit()` daje osobny segment wspinania dla jednostki.
- Kolejka pod drabiną ma większe odstępy, żeby mniej się klinowała.
- Próg wejścia w `Enemy` wzrósł do `0.95m`, żeby jednostka stojąca bardzo blisko drabiny nie czekała bez sensu przez mikrokolizję.

## Walidacja

- `/opt/homebrew/bin/godot --headless --path . --script /tmp/load_ladder_perf_stack.gd`
  - ładuje `SiegeLadder`, `LadderAssaultBrain` i `Enemy` bez błędów parsowania.
- `/opt/homebrew/bin/godot --headless --path . --script /tmp/mountainhold_ladder_capacity_probe.gd`
  - `capacity=3 entry_ok=3 climb_ok=3 offsets=[0.0, 0.55, -0.55]`.
- `/opt/homebrew/bin/godot --headless --path . --script /tmp/mountainhold_ladder_throughput_probe.gd`
  - przy wyłączonym ogniu łuczników dla testu: `ladders=4 climbing=2 entry=3 on_wall=2 enemies=34`.

## Następny krok

Jeśli gameplay dalej wygląda zbyt mało epicko, większą bitwę trzeba zwiększać po tej kolejności: najpierw przepustowość drabin i koszt AI, potem większe fale. Samo podbicie liczby jednostek przed stabilizacją tłumu będzie tylko produkować lagi i korki.
