# Mountainhold — kontekst dla przyszłych sesji Codex

Stan dokumentu: 2026-07-28. Ten plik jest szybkim punktem wejścia dla kolejnych agentów. Szczegółowa analiza mechanik jest w `docs/current_game_mechanics.md`.

## Najważniejsza zasada

Mountainhold ma być fizyczną grą oblężniczą, nie zbiorem skrótów i teleportów. Postacie nie mogą latać, przeskakiwać przez geometrię, wspinać się po powietrzu ani dostawać „magicznych” pozycji. Jeśli łucznik, wróg albo ork z drabiną zmienia poziom, powinien robić to przez realne przejście: schody, rampę, bramę, mur, okno, drabinę albo jawny `NavigationLink3D`, który odpowiada fizycznie istniejącej geometrii.

## Co to jest za gra

`Mountainhold` to prototyp Godot 4.7: first-person archery castle-siege. Gracz broni górskiej twierdzy w stylu Helmowego Jaru. Fale orków atakują mury, bramę i wewnętrzny stołp. Gracz strzela z łuku, dowodzi łucznikami i próbuje zatrzymać oblężenie zanim padnie brama albo stołp.

Główna scena gry to `scenes/play.tscn`; scena startowa projektu to `scenes/ui/main_menu.tscn`.

## Jak uruchamiać

- `make run` — uruchamia menu główne.
- `make play` — uruchamia bezpośrednio scenę gry.
- `make editor` — otwiera projekt w edytorze Godot.
- `make startup` — szybki headless smoke dla menu.
- `make test` — pełne GdUnit testy; nie uruchamiać automatycznie, bo użytkownik aktualnie testuje ręcznie i prosił, żeby tego nie odpalać bez pytania.

Domyślny Godot w `Makefile`: `/opt/homebrew/bin/godot`.

## Aktualne źródło prawdy

Starsze dokumenty `docs/project_overview.md` i `docs/workflow.md` opisują etap, w którym projekt był głównie środowiskiem bez pełnego gameplayu. Są historyczne i częściowo nieaktualne. Przy pracy nad obecną grą używaj przede wszystkim:

- `CODEX.md` — szybki briefing.
- `docs/current_game_mechanics.md` — szczegółowa analiza systemów.
- `docs/task-log/ladder-deploy-stall-analysis.md` — ważna historia bugów wokół drabin.
- `docs/research/archer_navigation_research.md` — research ruchu łuczników.
- `docs/research/ladder_siege_navigation_research.md` — research oblężenia drabinami.
- `docs/research/world_collision_physics_research.md` — research kolizji i fizyki świata.

## Mapa struktury projektu

- `project.godot` — konfiguracja Godot, autoloady `GameSettings` i `Audio`, main scene.
- `scenes/play.tscn` — skład gry: forteca, gracz, fale, rozkazy, HUD, łucznicy.
- `scenes/castle/fortress.tscn` — środowisko, Terrain3D i `FortressGenerator`.
- `scripts/castle/fortress_generator.gd` — generowanie twierdzy, slotów taktycznych, slotów drabin i połączeń nawigacyjnych.
- `scripts/castle/modules/` — moduły zamku: mury, bramy, schody, wieże, stołp, teren.
- `scripts/player/fps_bow_player.gd` — gracz FPS z łukiem.
- `scripts/player/arrow.gd` — fizyczna strzała gracza.
- `scripts/enemy/` — AI i typy wrogów: piechota, łucznik, taran, boss taran, ork z drabiną, drabina.
- `scripts/ally/` — nasi łucznicy, automatyczne rozmieszczenie i rozkazy.
- `scripts/characters/` — wspólne statystyki i komponenty walki/zdrowia/targetingu.
- `scripts/ui/` — HUD, minimapa, menu, debug panel, pause/game over.
- `data/*.tres` — dane statystyk postaci i jednostek.
- `test/*.gd` — testy GdUnit i probe-style scenariusze.

## Model gameplayu

Główna pętla:

1. `FortressGenerator` buduje twierdzę i rejestruje sloty na murach, przy bramie, przy stołpie i dla drabin.
2. `AllyPlacer` stawia naszych łuczników na realnych powierzchniach zamku.
3. `WaveSpawner` odpala fale wrogów.
4. Tarany idą do bramy i tylko one powinny ją niszczyć.
5. Drabiniarze idą pod rozproszone sloty na murze, niosą drabinę w ekipie, rozstawiają ją po czasie i umożliwiają wspinanie.
6. Zwykli orkowie i łucznicy korzystają z aktywnych drabin, zamiast atakować bramę.
7. Nasi łucznicy dobierają cele, zmieniają pozycję pod linię strzału i wykonują rozkazy gracza.
8. HUD pokazuje stan bramy, stołpu, gracza, fale, licznik wrogów, panel rozkazów, roster i minimapę.

## Sterowanie i debug

- `1` — każ łucznikom atakować taran.
- `2` — każ atakować wrogich łuczników.
- `3` — każ atakować najbliższych wrogów.
- `4` — przywołaj więcej łuczników do bramy; każde kolejne naciśnięcie zwiększa pulę o 30%, aż do 100%.
- `5` — wycofaj łuczników do stołpu.
- `0` — tryb auto.
- `P` — zapisuje screenshot do `res://screenshots/player/shot_NNN.png`.
- `F3` albo `Tab` — panel developerski; na Macu `F3` bywa przechwycony przez system, więc `Tab` jest bezpieczniejszy.

## Statystyki i progresja

Statystyki są w `UnitStats` (`scripts/characters/unit_stats.gd`) i w zasobach `data/*.tres`.

Jednostki mają poziom, zabicia, XP, HP, obronę, pancerz, prędkość, zasięg wzroku, obrażenia wręcz, obrażenia dystansowe, interwał ataku i parametry strzał. Bohater i nasi łucznicy skalują się co próg zabójstw: 5, 10, 20, 40 itd. Każdy bonusowy poziom daje +10% do skalowanych statystyk, w tym ataku, obrony i zasięgu.

## Krytyczne reguły implementacji

- Nie naprawiać problemów przez teleportowanie jednostek na mury.
- Nie dodawać sztucznych podestów jako „mostków” bez zgody użytkownika.
- Nie pozwalać zwykłym orkom stawiać drabin. Drabina wymaga orków z drabiną, minimalnej liczby pomocników i czasu rozstawiania.
- Drabiny wolno stawiać tylko przy murach, nie na wieżach ani gate towerach.
- Jeśli wróg lub łucznik nie może dojść fizycznie, trzeba poprawić topologię zamku/nawigacji, a nie wymuszać pozycję.
- Licznik wrogów i minimapa powinny ignorować martwe, ukryte, nieaktywne, spadające albo usunięte jednostki.
- Każdy nowy moduł zamku powinien rejestrować swoje sloty i realne połączenia tak, aby AI działało dynamicznie po zmianie schematu.

## Znane ograniczenia

- Dynamiczna nawigacja po murach i wieżach jest najważniejszym długiem technicznym. Obecny system ma mieszankę realnych krawędzi, fallbacków i zabezpieczeń przed „wspinaniem po ścianie”.
- Wrogowie są obecnie celowo chronieni przed używaniem fałszywych pionowych krawędzi, bo wcześniej powodowało to wejście po wieży albo po powietrzu.
- To oznacza, że pełne szturmowanie wysokich dachów bram/wież przez wrogów wymaga realnego, fizycznego graphu schodów/przejść.
- Łucznicy nadal wymagają szczególnej ostrożności: strzał powinien być wykonywany tylko przy prawdziwej linii strzału, a przy blokadzie murem/podłogą jednostka musi zmienić pozycję.

## Bezpieczna walidacja bez blokowania użytkownika

Użytkownik często testuje ręcznie przez `P` i screenshoty. Dla Codexa najlepsze są krótkie, headless walidacje:

- parse/load check przez tymczasowy skrypt Godot, który ładuje kluczowe skrypty;
- krótkie odpalenie `scenes/play.tscn` z timeoutem 5–8 s;
- dedykowane probe skrypty w `/tmp`, które sprawdzają grupy, sloty, liczniki, pozycje i stany AI.

Nie odpalaj `make test`, dopóki użytkownik nie poprosi albo nie potwierdzi.

