# Wall contact performance

## Objaw

Gra działa lepiej w polu, ale zaczyna mocno szarpać gdy wróg zbliża się pod mur, ustawia się przy drabinach i wchodzi na mur. Po wejściu kilku orków na mur spadki są dużo mocniejsze.

## Przyczyny

- `WallAssaultBrain.choose_defender()` liczył trasę przez `CastlePathfinder` do obrońcy nawet wtedy, gdy obrońca był na tym samym poziomie i mógł być wybrany bezpośrednio.
- `Enemy._fight_on_wall()` pytał wall brain o cel co physics frame, więc każdy ork na murze mógł wielokrotnie liczyć drogie ścieżki do wielu obrońców.
- Separacja jednostek pod murem odświeżała się zbyt często i sprawdzała do 8 sąsiadów przy dużym zagęszczeniu.
- HUD sortował roster obrońców co klatkę, mimo że te dane nie muszą być aktualizowane 60 razy na sekundę.

## Zmiana

- Wróg na murze cache’uje cel obrońcy przez około `0.42–0.60s`.
- Wróg cache’uje fallback pressure point przez około `0.7–0.95s`.
- Wall brain nie liczy trasy dla bezpośredniego celu na tym samym poziomie.
- Separacja tłumu odświeża się wolniej (`0.32s` + jitter) i bierze maksymalnie 5 sąsiadów.
- HUD roster odświeża listę/statystyki obrońców co `0.35s`, nie co frame.

## Walidacja

- `/opt/homebrew/bin/godot --headless --path . --script /tmp/load_wall_perf_stack.gd`
  - ładuje `Enemy`, `HUD` i `WallAssaultBrain` bez błędów parsowania.
- `/opt/homebrew/bin/godot --headless --path . --script /tmp/mountainhold_wall_perf_probe.gd`
  - przy wyłączonym ogniu łuczników dla kontroli lifecycle: `avg_fps=125.5 enemies=34 climbing=3 on_wall=4`.

## Uwaga

W probe nadal był pojedynczy niski `min_fps`, prawdopodobnie ze spike’u tworzenia dużej liczby obiektów albo momentu deploy drabin. Jeśli gracz dalej czuje sekundowe szarpnięcie, następnym krokiem jest rozłożenie spawn/deploy kosztów na kilka klatek i ograniczenie kosztu tworzenia mesh/material dla drabin oraz jednostek.
