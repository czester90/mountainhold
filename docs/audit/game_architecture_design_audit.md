# Mountainhold — audyt architektury gry i zgodności z dobrymi praktykami Godot

Data: 2026-07-28

## Werdykt

Projekt jest grywalnym prototypem z sensownymi fundamentami, ale nie jest jeszcze zaprojektowany tak czysto, jak powinien być projektowany docelowy system gry oblężniczej. Największy problem nie polega na pojedynczym błędzie. Problemem jest to, że kilka systemów produkcyjnych nadal działa jak prototyp: generator fortecy, AI wroga, AI łuczników, spawner, recovery, sloty taktyczne, debug i obejścia ruchu są mocno splecione.

W efekcie gra zachowuje się niestabilnie: jeśli zmienia się układ muru, drabina, pozycja łucznika albo wysokość terenu, AI często próbuje „zgadywać” drogę lokalnymi raycastami, fallbackami i ręcznym przesuwaniem. To jest przeciwne do docelowego modelu gry, w którym zamek powinien emitować czytelny model nawigacyjny, a jednostki powinny tylko z niego korzystać.

Krótko: fundamenty są dobre, ale trzeba zatrzymać dokładanie kolejnych wyjątków i zrobić refaktor rdzenia nawigacji/oblężenia.

## Źródła wzorców

Audyt porównuje projekt z oficjalnymi zasadami Godot:

- Godot Scene Organization: sceny powinny mieć pojedynczą odpowiedzialność, luźne zależności i jasno zarządzane relacje między systemami.
- Godot NavigationAgent3D: agent pathfindingu nie porusza ciała sam; rodzic musi używać wyniku w physics step, a `get_next_path_position()` powinno być wywoływane raz na physics frame podczas ruchu.
- Godot NavigationLinks: linki są przeznaczone do połączeń między navmeshami i ruchów typu drabiny, skoki, teleporty lub interaktywne skróty.
- Godot Navigation Performance: nie należy resetować ścieżek co frame, aktualizować wszystkich agentów naraz ani bake’ować z nadmiernie złożonej geometrii.
- Godot Collision Shapes 3D: dynamiczne obiekty powinny używać prostych primitive collision shapes; concave/trimesh jest właściwe głównie dla statycznych poziomów.
- Godot Groups: grupy są dobre do tagowania i decouplingu, ale nie powinny zastępować stabilnego modelu danych/registry dla ciężkich systemów.

## Co jest zaprojektowane dobrze

### 1. Scena gry ma czytelny punkt wejścia

`scenes/play.tscn` jest dobrym centrum runtime: ma fortecę, gracza, spawner fal, rozkazy, HUD, placer sojuszników i debug panel. To jest zgodne z podejściem, w którym scena rozgrywki jest „bird’s eye view” dla systemów.

### 2. Dane jednostek są data-driven

`scripts/characters/unit_stats.gd` i `data/*.tres` to dobry kierunek. Statystyki są oddzielone od logiki postaci, a role/fakcje/progresja są jawne. To trzeba utrzymać i rozszerzać, zamiast dopisywać statystyki w wielu skryptach.

### 3. Podział typów wrogów istnieje

`Enemy`, `RamEnemy`, `BossRamEnemy`, `ArcherEnemy`, `LadderOrcEnemy` i `SiegeLadder` są osobnymi klasami. To jest dobry początek modelu domeny, nawet jeśli baza `Enemy` jest dziś za duża.

### 4. Rozkazy obrońców są wydzielone

`scripts/ally/defender_orders.gd` jest dobrą granicą dla inputu gracza i trybów AI. Mechanika 30% łuczników na każde wezwanie do bramy jest już w odpowiednim miejscu.

### 5. HUD i minimapa są osobnymi systemami UI

`scripts/ui/hud.gd` i `scripts/ui/minimap.gd` nie są wmieszane bezpośrednio w AI. To dobrze. Problem jest bardziej w przepływie danych niż w samym miejscu kodu.

### 6. Aktualne AI używa `CharacterBody3D`

`AllyArcher` i `Enemy` są teraz `CharacterBody3D`, co jest dużym krokiem względem wcześniejszego stanu opisanego w starszym researchu. To oznacza, że projekt idzie w dobrą stronę: ruch może opierać się na `velocity` i `move_and_slide()`.

## Co jest zaprojektowane źle albo ryzykownie

## P0 — aktywne ryzyka, które bezpośrednio psują gameplay

### 1. Brakuje jednego źródła prawdy dla nawigacji zamku

Obecnie nawigacja jest rozproszona:

- `FortressGenerator` tworzy sloty i `castle_navigation_edge`;
- `AllyArcher` buduje własną trasę fallback po edge’ach;
- `Enemy` buduje własną trasę po wall graph;
- `WaveSpawner` sam wybiera sloty drabin i trasy assault;
- `AllyPlacer` duplikuje stałe geometrii generatora;
- minimapa sama skanuje moduły zamku.

To łamie podstawową zasadę dla gry z modularnym zamkiem: zamek powinien emitować jeden spójny model `CastleNavigationModel` / `CastleTacticalModel`, a wszystkie systemy powinny pytać ten model.

Skutek:

- zmieniasz schemat muru i część systemów nadal zakłada stare `CX`, `CZ`, `WALL_R`;
- łucznik może stać na powierzchni, ale nie mieć dojścia;
- wróg może widzieć slot drabiny, ale nie mieć prawidłowej trasy;
- minimapa i AI mogą rozumieć mapę inaczej.

### 2. `AllyArcher` jest za duży i ma zbyt wiele odpowiedzialności

`scripts/ally/ally_archer.gd` ma około 984 linie i robi naraz:

- statystyki;
- HP i śmierć;
- targeting;
- rozkazy;
- wybór celu;
- strzelanie i balistykę;
- line of sight;
- repositioning po złym strzale;
- fallback pathfinding;
- native `NavigationAgent3D`;
- ruch po powierzchniach;
- separację od innych jednostek;
- stuck detection;
- recovery po spadku.

To nie jest stabilna struktura dla AI, które ma być inteligentne. Każda poprawka jednej części może przypadkiem zmienić inną. To jest też powód, dlaczego łucznicy mogą drżeć: kilka intencji ruchu konkuruje w jednej klasie.

Najbardziej podejrzany fragment: `_walk_towards_on_surfaces()` i `_move_character()` nadal robią lokalny surface search, ręczne step-up przez `test_move()` i awaryjne `global_position += ...`. To już nie jest brutalny teleport całej trasy, ale nadal jest lokalnym obejściem zamiast pełnego nav corridor.

### 3. `Enemy` jest za duży i miesza state machine z locomotion

`scripts/enemy/enemy.gd` ma około 730 linii i miesza:

- wspólny model postaci;
- route following;
- gate/keep objective;
- ladder detection;
- ladder queue;
- ladder climb;
- wall fighting;
- targeting obrońców;
- attack logic;
- local avoidance;
- stuck recovery;
- fall/burial recovery;
- wizualizację i flash.

To utrudnia stabilne naprawianie wrogów. Przykład: wspinanie po drabinie robi `global_position = _climb_from.lerp(_climb_to, _climb_t)`. Dla drabiny to może być akceptowalny scripted traversal, ale powinno być wydzielone jako jawny `TraversalController`, a nie ukryte w bazowym `Enemy`.

### 4. `LadderOrcEnemy` nadpisuje `_physics_process`

`LadderOrcEnemy` ma własny `_physics_process`. To oznacza, że łatwo rozjechać wspólne gwarancje ruchu i recovery z bazowego `Enemy`. Przy tak wrażliwej mechanice jak drabiny powinien istnieć wspólny tick:

- baza robi bezpieczeństwo fizyki;
- subclass robi tylko `_tick_state(delta)` albo `_tick_behavior(delta)`;
- traversal i recovery są centralne.

Obecnie drabiniarz ma też własne `global_position = _climb_from.lerp(...)`, niezależne od bazowego climb. To jest drugi równoległy model wspinania.

### 5. Spawner jest jednocześnie spawnerem, siege directorem i lane managerem

`scripts/enemy/wave_spawner.gd` powinien zarządzać falami. Obecnie robi znacznie więcej:

- skład fali;
- spawn placement;
- alive tracking;
- gate/keep HP;
- wybór lane’ów;
- wybór ladder slots;
- crew creation;
- escort spawning;
- terrain/physics ground helpers;
- rozpraszanie wrogów.

To powinno być rozdzielone. `WaveSpawner` powinien pytać `SiegeDirector`, gdzie ma wysłać ekipę, a nie znać szczegóły zamku.

### 6. `AllyPlacer` nie jest naprawdę dynamiczny

Komentarz mówi, że placer adaptuje się do strukturalnych zmian, ale kod duplikuje stałe `FortressGenerator`: `centre`, `wall_r`, `tower_project`, `apex`, `open_half`, `runs`, `keep_x`. To jest częściowo proceduralne, ale nie dynamiczne.

Jeśli generator zmieni geometrię, placer może dalej raycastować stare oczekiwane punkty. Poprawny model: placer powinien czytać `castle_tactical_slot_*`, scoring LOS i reachability, a nie sam odtwarzać geometrię fortecy.

### 7. NavigationAgent3D jest przygotowany, ale domyślnie wyłączony

`AllyArcher` tworzy `NavigationAgent3D`, ale `use_native_navigation` jest domyślnie `false`, a fallback nadal jest głównym driverem. To oznacza, że mimo użycia `CharacterBody3D` gra nadal w praktyce polega na custom surface walkerze.

To jest zrozumiałe jako etap migracji, ale nie powinno zostać docelowo.

### 8. Grupy są używane bardzo szeroko jako runtime registry

Grupy Godot są dobre do tagowania i decouplingu, ale w projekcie są używane też jako główny sposób wyszukiwania prawie wszystkiego: enemy, ally, sloty, drabiny, debug actors, tactical slots, navigation edges. To działa w małym prototypie, ale przy większej liczbie jednostek i dynamicznych falach będzie kosztowne i podatne na stale refs.

Docelowo powinien powstać lekki `GameStateRegistry` albo `CombatRegistry`, który:

- cache’uje aktywnych wrogów;
- cache’uje aktywnych obrońców;
- usuwa martwe/hidden/out-of-world jednostki;
- dostarcza minimapie i HUD-owi te same dane co AI.

## P1 — architektura do poprawy, zanim gra urośnie

### 1. `FortressGenerator` robi za dużo

`scripts/castle/fortress_generator.gd` ma około 544 linie i odpowiada za:

- layout fortecy;
- instantiate modułów;
- terrain base;
- cave/causeway/keep/ring/walls;
- tactical slots;
- ladder slots;
- navigation edges;
- `NavigationLink3D`;
- procedural `NavigationRegion3D`;
- sally ports;
- ground helpers.

Generator powinien budować zamek, ale model danych powinien być osobnym obiektem/API. Dzisiaj logika gameplayu jest zbyt blisko sposobu konstrukcji fortecy.

### 2. Navmesh jest za prymitywny jak na potrzeby AI

Generator tworzy pasy nawigacyjne z prostych stripów i linków. To lepsze niż nic, ale nie jest pełnym walkable model:

- nie opisuje szerokości przejść;
- nie opisuje pojemności schodów;
- nie opisuje okien/strzelnic;
- nie ma osobnych warstw dla ground/wall/interior/ladder;
- vertical edges są problematyczne i wymagają ręcznej filtracji.

Docelowo castle navigation musi rozróżniać:

- ground/courtyard;
- wall walk;
- tower roof;
- gate gallery;
- keep interior/roof;
- stairs/ramp links;
- ladder links.

### 3. Kolizje nie mają centralnej specyfikacji warstw

Warstwy są wpisywane ręcznie w wielu miejscach przez `1 << n`. To jest podatne na błąd. Potrzebny jest jeden plik, np. `scripts/core/collision_layers.gd` albo autoload/config:

- `WORLD`;
- `ENEMY`;
- `PLAYER_ARROW`;
- `ALLY`;
- `PLAYER`;
- `LADDER_HITBOX`;
- `ENEMY_PROJECTILE`.

Wtedy każdy skrypt importuje semantyczne nazwy, a nie liczby.

### 4. Recovery ukrywa błędy świata

`Enemy` i `AllyArcher` mają recovery, które snapuje jednostkę na podłoże po spadku albo zakopaniu. To jest potrzebny emergency layer, ale nie może być normalną częścią ruchu. Jeśli recovery odpala często, to znaczy, że spawn, collision albo navgraph są złe.

Docelowo debug panel powinien liczyć recovery events per unit i pokazać je na czerwono.

### 5. UI skanuje świat zamiast dostawać snapshot

HUD i minimapa cyklicznie skanują grupy. Przy większej liczbie jednostek, drabin i pocisków to zacznie boleć. Lepszy model:

- `GameStateRegistry` trzyma aktywne jednostki;
- HUD pyta registry;
- minimapa pyta registry i `CastleModel`;
- AI też korzysta z tych samych list.

## P2 — repo hygiene i legacy

### 1. Archiwum jest w projekcie Godot

`archive_prebuilder_refactor_2026_07_14/` siedzi w katalogu projektu. Jeśli nie ma `.gdignore`, Godot może skanować stare sceny/skrypty/UID-y. To robi hałas i zwiększa ryzyko konfliktów.

Zalecenie: dodać `.gdignore` w archiwum albo wynieść archiwum poza projekt.

### 2. Istnieją nieaktualne dokumenty

`docs/project_overview.md` i `docs/workflow.md` opisują etap, w którym projekt nie miał pełnego gameplayu. Dodałem `CODEX.md` i `docs/current_game_mechanics.md` jako aktualne źródło prawdy, ale starsze dokumenty powinny dostać banner `STALE / HISTORICAL`, żeby przyszły agent ich nie potraktował jako aktualnych.

### 3. Dużo test/probe/capture scen żyje obok runtime

To nie jest błąd sam w sobie, ale repo robi się hałaśliwe. `scripts/test`, `scenes/test`, `scripts/editor`, `scenes/*_check.tscn` są przydatne, ale powinny mieć jasno opisany status: produkcja, probe, capture, archive.

### 4. Bardzo dużo plików jest nieśledzonych

`git status` pokazuje ogromny zestaw `??` dla aktualnych scen, skryptów, data, addonów i screenshotów. To ryzyko procesu: trudno będzie odróżnić świadome zmiany od artefaktów. Przed większym refaktorem trzeba ustalić, co ma wejść do repo, co do `.gitignore`, a co do archiwum.

## Ocena zgodności z dobrym projektowaniem gry

| Obszar | Ocena | Komentarz |
| --- | --- | --- |
| Główna scena gry | Dobra | `play.tscn` jest sensownym composition root. |
| Data-driven stats | Dobra | `UnitStats` + `.tres` to właściwy kierunek. |
| Podział jednostek | Średnia | Typy są osobne, ale baza `Enemy` robi za dużo. |
| AI łuczników | Słaba/średnia | Działa, ale jest monolitem z fallback movement. |
| AI wrogów | Średnia | Ma potrzebne stany, ale brak czystego locomotion/state split. |
| Drabiny | Średnia | Model crew/deploy jest dobry, ale traversal i lifecycle są kruche. |
| Nawigacja zamku | Słaba | Brak jednego autorytatywnego castle navigation modelu. |
| Kolizje | Średnia | Postacie mają collidery, ale brak centralnej specyfikacji warstw i ground contract. |
| UI/HUD | Dobra/średnia | Oddzielone, ale data flow przez grupy powinien przejść na registry. |
| Performance | Ryzykowna | Duże skany grup i fallback pathing mogą boleć przy większych falach. |
| Repo hygiene | Słaba | Archiwa/screenshoty/untracked pliki robią bałagan. |

## Docelowa architektura

### 1. `CastleModel`

Nowy model twierdzy tworzony przez generator:

- `walk_surfaces`;
- `portals`;
- `stairs_links`;
- `tower_links`;
- `gate_slots`;
- `keep_slots`;
- `archer_slots`;
- `ladder_slots`;
- `wall_lanes`;
- `minimap_footprints`.

Systemy nie powinny znać `CX`, `WALL_R`, `RUNS`. Mają pytać `CastleModel`.

### 2. `SiegeDirector`

Odpowiada za oblężenie:

- wybór wall lane;
- rezerwację lane;
- wybór spawn/muster/approach/foot/top dla drabin;
- rozproszenie fal;
- przypisanie escortów;
- aktywne drabiny;
- strategię ataku po przebiciu bramy.

`WaveSpawner` zostaje tylko od fal, timingów i HP strategicznych obiektów.

### 3. `UnitLocomotion`

Wspólny komponent dla `Enemy` i `AllyArcher`:

- ruch `CharacterBody3D`;
- gravity;
- floor snap;
- collision-based step handling;
- local avoidance;
- stuck detection;
- emergency recovery jako ostatnia deska ratunku;
- debug counters.

### 4. `TraversalController`

Osobny kontroler dla drabin, schodów specjalnych i innych przejść:

- entering traversal;
- queue;
- occupancy;
- scripted movement po linku;
- exit validation;
- release capacity;
- failure recovery.

Dzięki temu ladder climb nie będzie skopiowany w `Enemy` i `LadderOrcEnemy`.

### 5. `DefenderAI`

Rozdzielić `AllyArcher`:

- `DefenderBrain` — wybór intencji;
- `DefenderTargeting` — wybór celu;
- `DefenderPositioning` — scoring slotów i LOS;
- `ArcherShooting` — balistyka i cooldown;
- `DefenderLocomotion` — wykonanie ruchu.

`AllyArcher` powinien zostać cienkim aktorem składającym komponenty.

### 6. `CombatRegistry`

Jeden cache aktywnych jednostek:

- `active_enemies`;
- `active_allies`;
- `active_rams`;
- `active_ladders`;
- `player`;
- filtrowanie `is_active_enemy()`, dead, hidden, out-of-world.

HUD, minimapa, targeting i debug czytają to samo źródło.

## Kolejność napraw

### Faza 0 — higiena i bezpieczeństwo

1. Dodać `.gdignore` do archiwów albo wynieść archiwa poza projekt.
2. Oznaczyć stare docs jako historyczne.
3. Dodać centralne stałe collision layers.
4. Dodać licznik recovery/stuck events do debug panelu.

### Faza 1 — jedno źródło danych zamku

1. Wyciągnąć z `FortressGenerator` lekki `CastleModel`.
2. Przenieść tactical slots, ladder slots, nav edges i minimap footprints do modelu.
3. Przerobić `AllyPlacer`, `DefenderOrders`, `WaveSpawner`, `Minimap`, `Enemy`, `AllyArcher`, żeby czytały model zamiast duplikować geometrię.

### Faza 2 — siege director

1. Dodać `SiegeDirector`.
2. Przenieść lane selection i ladder crew assignment z `WaveSpawner`.
3. Wymusić, że każda drabina przechodzi przez crew/deploy/lane flow.
4. Dodać walidację, że lane ma fizyczny ground i top na murze.

### Faza 3 — locomotion/traversal

1. Wyciągnąć `UnitLocomotion`.
2. Wyciągnąć `TraversalController`.
3. Usunąć duplikację climb z `Enemy` i `LadderOrcEnemy`.
4. Włączyć `NavigationAgent3D` jako domyślny driver dopiero po pokryciu navmesh/linków.

### Faza 4 — AI łuczników

1. Rozbić `AllyArcher`.
2. Pozycje wybierać przez scoring slotów: LOS, zasięg, bezpieczeństwo, dojście, blokada przez innych.
3. Przy złym strzale nie robić lokalnego chaotycznego kroku, tylko rezerwować lepszy slot.
4. Ruch przez przejścia/stairs/slots z capacity.

### Faza 5 — performance/data flow

1. Dodać `CombatRegistry`.
2. Ograniczyć masowe `get_nodes_in_group()` w `_process`.
3. Rozłożyć ciężkie zapytania pathfindingu na tick groups.
4. Przenieść minimapę na cache danych.

## Najważniejsze decyzje projektowe

### Decyzja 1: nie poprawiać AI kolejnymi hardcoded punktami

Każdy kolejny hardcoded punkt `Vector3(...)` poprawi jeden screenshot i popsuje następny layout. Potrzebny jest model zamku i sloty generowane z modułów.

### Decyzja 2: recovery jest alarmem, nie normalną mechaniką

Jeśli jednostka używa recovery, debug powinien to raportować. Normalny ruch nie może regularnie polegać na snapowaniu do ziemi.

### Decyzja 3: drabina jest traversal object

Drabina nie jest tylko visualem i nie jest tylko linkiem. To obiekt gameplayowy: ma ekipę, deployment, HP, queue, capacity, top/foot, stan aktywacji i release.

### Decyzja 4: dynamiczny zamek wymaga API, nie kopiowania stałych

Jeśli w przyszłości mury mają być generowane różnie, żaden gameplay system nie może odtwarzać `FortressGenerator` własnymi stałymi.

## Rekomendacja końcowa

Nie jesteśmy jeszcze w architekturze „tak jak powinno się projektować grę” dla docelowej wersji. Jesteśmy w typowym stadium dobrego, ale przeciążonego prototypu: dużo funkcji działa, ale działa dzięki aktywnym obejściom.

Najlepszy następny ruch to nie kolejna drobna poprawka łucznika albo drabiny. Najlepszy ruch to mały, kontrolowany refaktor fundamentu:

1. `CastleModel`;
2. `SiegeDirector`;
3. `UnitLocomotion` / `TraversalController`;
4. dopiero potem poprawki konkretnych zachowań.

To powinno zmniejszyć liczbę losowych błędów, bo AI przestanie zgadywać geometrię, a zacznie korzystać z jednego, jawnego kontraktu świata.

