# Mountainhold — plan refaktoru pod mechaniki Godot

Data: 2026-07-28

Cel: zaplanować naprawę architektury tak, żeby gra korzystała z mechanik Godot zamiast lokalnych obejść: `CharacterBody3D`, `NavigationAgent3D`, `NavigationRegion3D`, `NavigationLink3D`, collision layers/masks, grupy jako tagi, a nie główny registry świata.

Ten dokument jest planem. Nie implementuje zmian.

## Zasada główna

Nie poprawiamy już oblężenia przez dokładanie kolejnych `Vector3(...)`, sztucznych podestów, ręcznych teleportów albo specjalnych ifów pod jeden screenshot.

Docelowo:

- zamek emituje jeden model nawigacyjny i taktyczny;
- jednostki są `CharacterBody3D`;
- ruch poziomy idzie przez `velocity` + `move_and_slide()`;
- trasy idą przez `NavigationAgent3D`;
- przejścia specjalne, czyli schody specjalne, drabiny i wejścia do wież, są `NavigationLink3D` + jawny traversal state;
- drabina jest gameplay object z HP, kolejką, capacity i linkiem;
- HUD/minimapa/AI korzystają z tych samych aktywnych danych, nie skanują każdy po swojemu.

## Jakich mechanik Godot chcemy używać

### `CharacterBody3D`

Użycie:

- gracz;
- nasi łucznicy;
- piechota;
- wrodzy łucznicy;
- drabiniarze;
- opcjonalnie tarany jako `CharacterBody3D` albo cięższy `CharacterBody3D` z box colliderem.

Zasady:

- dynamiczne postacie mają primitive collision shapes, zwykle `CapsuleShape3D` albo `BoxShape3D`;
- ruch tylko w `_physics_process`;
- nie ustawiamy normalnego ruchu przez `global_position`;
- `global_position` wolno używać przy initial spawn, kontrolowanym traversal state, death/drop visual albo emergency recovery;
- recovery liczymy jako błąd/ostrzeżenie, nie normalną mechanikę.

### `NavigationRegion3D`

Użycie:

- generowany navmesh dla dziedzińca, murów, rampartów, bramy, wież i stołpu;
- źródłem powinny być proste boxy/rectanglowe powierzchnie gameplayowe, nie pełna detaliczna geometria wizualna;
- osobne warstwy logiczne: ground, wall, interior, ladder/attacker.

Zasady:

- navmesh musi odpowiadać realnym collision surfaces;
- nie bake’ujemy ciężkich visual meshów runtime, bo to kosztowne;
- generated modules powinny emitować simplified navigation source geometry.

### `NavigationAgent3D`

Użycie:

- każdy ruszający się łucznik i wróg ma agenta;
- target ustawiamy, gdy intencja się zmienia, nie co frame;
- `get_next_path_position()` wołamy raz na physics frame podczas aktywnego ruchu;
- agent podaje cel ruchu, ale `CharacterBody3D` wykonuje go przez `move_and_slide()`;
- avoidance włączamy ostrożnie: tylko dla crowd movement albo wybranych grup/ticków.

Zasady:

- nie pytać co frame `is_target_reachable()` dla wielu unitów;
- nie repathować wszystkich agentów naraz;
- dać tick groups/randomized timers dla dużych fal.

### `NavigationLink3D`

Użycie:

- schody/portale, których navmesh nie połączy naturalnie;
- wejście/zejście na wieżę;
- wejście do bramy/gate gallery;
- wejście do stołpu;
- aktywne drabiny oblężnicze.

Zasady:

- link istnieje tylko wtedy, gdy ma fizyczny odpowiednik;
- link drabiny aktywuje się dopiero po deployu;
- link ma warstwę nawigacji, żeby np. wróg mógł użyć drabiny, a obrońca nie musiał;
- wejście na link uruchamia `TraversalController`, nie magiczne przeniesienie.

### Collision layers/masks

Użycie:

- jeden centralny plik stałych;
- brak surowych `1 << 0` rozsianych po kodzie;
- test/probe waliduje, że najważniejsze ciała mają expected layer/mask.

Proponowane warstwy:

- `WORLD = 1 << 0`;
- `ENEMY = 1 << 1`;
- `PLAYER_ARROW = 1 << 2`;
- `ALLY = 1 << 3`;
- `PLAYER = 1 << 4`;
- `LADDER_HITBOX = 1 << 5`;
- `ENEMY_PROJECTILE = 1 << 6`;
- `TACTICAL_SENSOR = 1 << 7`, jeśli później dodamy area sensors.

### Groups

Użycie:

- tagi: `enemy`, `ally`, `ram`, `ladder`, `siege_ladder_active`;
- debug i bootstrap: ok.

Nie używać jako:

- jedynego runtime registry dla HUD/minimapy/AI;
- ciężkiego skanowania co frame;
- ukrytego API między systemami.

Docelowo grupy zasilają `CombatRegistry`, a reszta czyta registry.

## Docelowe systemy

## 1. `CastleModel`

### Cel

Jedno źródło prawdy o twierdzy. `FortressGenerator` buduje moduły i jednocześnie rejestruje ich model gry.

### Dane

- `walk_surfaces`: uproszczone powierzchnie, po których można chodzić;
- `nav_regions`: referencje do `NavigationRegion3D`;
- `links`: schody, wejścia do wież, gatehouse, keep;
- `archer_slots`: sloty strzeleckie;
- `gate_slots`: sloty obrony bramy;
- `keep_slots`: sloty odwrotu;
- `ladder_slots`: tylko mury, nie wieże;
- `wall_lanes`: szersze segmenty szturmu;
- `minimap_footprints`: outline zamku dla minimapy;
- `spawn_bounds`: bezpieczne zakresy spawnu;
- `ground_resolver`: API walidacji fizycznego podłoża.

### Pliki

- nowy: `scripts/castle/castle_model.gd`;
- zmiana: `scripts/castle/fortress_generator.gd`;
- zmiana: `scripts/castle/modules/*`.

### Kryteria akceptacji

- `FortressGenerator` po buildzie ma node/model dostępny z grupy `castle_model`;
- `CastleModel` zwraca minimum: gate slots, keep slots, ladder slots, minimap footprints;
- `AllyPlacer` nie potrzebuje kopiować `CX/WALL_R/RUNS`;
- minimapa może narysować zamek z `CastleModel`, nie ze skanowania skryptów modułów.

## 2. `GroundResolver`

### Cel

Nie wolno ufać samej wysokości terenu. Każdy spawn i każda lane musi mieć fizyczne podłoże z raycastu.

### API

- `raycast_ground(point: Vector3) -> Dictionary`;
- `find_nearest_valid_ground(point: Vector3, radius: float) -> Vector3`;
- `is_walkable_sample(point: Vector3) -> bool`;
- `validate_lane(samples: Array[Vector3]) -> bool`;

### Pliki

- nowy: `scripts/core/ground_resolver.gd` albo część `CastleModel`;
- zmiana: `scripts/enemy/wave_spawner.gd`;
- zmiana: przyszły `SiegeDirector`.

### Kryteria akceptacji

- wróg nie może zostać zespawnowany nad miejscem bez world collision;
- lane drabiny jest odrzucony, jeśli approach samples nie mają podłoża;
- debug potrafi wypisać jednostki bez podłoża pod sobą.

## 3. `CombatRegistry`

### Cel

Jedno źródło aktywnych jednostek dla HUD, minimapy, targetingu i debug panelu.

### API

- `register_enemy(enemy)`;
- `unregister_enemy(enemy)`;
- `active_enemies()`;
- `active_allies()`;
- `active_rams()`;
- `active_ladders()`;
- `player()`;
- `prune_invalid()`.

### Pliki

- nowy: `scripts/core/combat_registry.gd`;
- zmiana: `scenes/play.tscn`, żeby dodać node registry;
- zmiana: `WaveSpawner`, `AllyPlacer`, `Enemy`, `AllyArcher`, `HUD`, `Minimap`.

### Kryteria akceptacji

- licznik HUD i minimapa pokazują te same aktywne wrogi;
- martwy/hidden/falling enemy nie jest liczony;
- minimapa nie pokazuje „ducha”, którego nie widać.

## 4. `SiegeDirector`

### Cel

Oddzielić strategię oblężenia od `WaveSpawner`.

### Odpowiedzialności

- pobrać `wall_lanes` i `ladder_slots` z `CastleModel`;
- wybrać lane dla ekipy drabin;
- rezerwować lane, żeby fala nie szła cała w jedno miejsce;
- przygotować `spawn`, `muster`, `approach`, `foot`, `top`, `normal`;
- sprawdzić ground i top przez `GroundResolver`;
- zarządzać aktywnymi drabinami i ich dostępnością;
- podać zwykłej piechocie najbliższą sensowną aktywną drabinę.

### Pliki

- nowy: `scripts/enemy/siege_director.gd`;
- zmiana: `scripts/enemy/wave_spawner.gd`;
- zmiana: `scripts/enemy/ladder_orc_enemy.gd`;
- zmiana: `scripts/enemy/enemy.gd`.

### Kryteria akceptacji

- drabiniarze nie idą pod bramę, jeśli mają wolne lane na murze;
- druga fala nie zbija się na bramie;
- zwykłe orki nie stawiają drabin;
- każda drabina ma owner crew/lane;
- debug pokazuje lane reservations.

## 5. `UnitLocomotion`

### Cel

Jeden komponent ruchu dla postaci, zamiast osobnych lokalnych walkerów w `Enemy` i `AllyArcher`.

### Odpowiedzialności

- `CharacterBody3D` velocity;
- gravity;
- floor snap;
- step handling;
- local avoidance/separation;
- stuck tracking;
- recovery jako alarm;
- nav driver: native/fallback/none;
- debug state.

### API

- `set_target(point: Vector3, mode: StringName)`;
- `clear_target()`;
- `physics_tick(delta)`;
- `is_arrived()`;
- `is_stuck()`;
- `recovery_count()`;
- `driver()`;

### Pliki

- nowy: `scripts/characters/components/unit_locomotion.gd`;
- zmiana: `scripts/enemy/enemy.gd`;
- zmiana: `scripts/ally/ally_archer.gd`;
- później: rozbicie testów.

### Kryteria akceptacji

- zwykły ruch nie używa `global_position +=`;
- `Enemy` i `AllyArcher` mają ten sam model stuck/recovery;
- debug panel pokazuje ruch: idle, moving, blocked, stuck, traversing, recovered;
- wyłączenie fallbacków nie psuje collision movement.

## 6. `TraversalController`

### Cel

Jawny kontroler przejść specjalnych: drabina, schody specjalne, wieża, gatehouse.

### Odpowiedzialności

- wejście w traversal;
- zatrzymanie normalnego nav steeringu;
- ruch po krzywej/segmencie traversal;
- zachowanie kolizji lub przełączenie mask tylko na czas kontrolowany;
- wyjście na zwalidowany punkt;
- release capacity;
- porażka/retry.

### Pliki

- nowy: `scripts/characters/components/traversal_controller.gd`;
- zmiana: `scripts/enemy/siege_ladder.gd`;
- zmiana: `scripts/enemy/enemy.gd`;
- zmiana: `scripts/enemy/ladder_orc_enemy.gd`.

### Kryteria akceptacji

- climb code nie jest zdublowany w `Enemy` i `LadderOrcEnemy`;
- jednostka nie wychodzi z drabiny w powietrzu;
- capacity drabiny czyści się po śmierci, anulowaniu i dojściu na top;
- zwykły wróg bez drabiny nie może wejść na mur.

## 7. `DefenderAI`

### Cel

Rozbić monolit `AllyArcher` i zrobić łuczników inteligentnych przez slot scoring, nie przez lokalne zgadywanie kroku.

### Podsystemy

- `DefenderBrain`: aktualna intencja;
- `DefenderTargeting`: wybór celu;
- `DefenderPositioning`: wybór slotu;
- `ArcherShooting`: balistyka i line of sight;
- `UnitLocomotion`: ruch;
- `DefenderOrderAdapter`: interpretacja rozkazów.

### Scoring pozycji

Slot łucznika dostaje punkty za:

- widoczność celu;
- brak muru/podłogi na linii strzału;
- zasięg;
- wysokość/bezpieczeństwo;
- dystans do rozkazu;
- niezajętość;
- realne dojście z aktualnej pozycji;
- priorytet bramy/stołpu.

### Kryteria akceptacji

- jeśli łucznik strzela w mur, po krótkiej diagnozie zmienia slot;
- przy rozkazie `4` tylko 30/60/90/100% łuczników dostaje gate slots;
- przy rozkazie `5` łucznicy idą przez realne przejścia do keep slots;
- łucznik nie drży, bo tylko jeden system ustawia ruch.

## Fazy implementacji

## Faza A — porządek i bezpieczne fundamenty

Zakres:

1. Dodać `scripts/core/collision_layers.gd`.
2. Zamienić najważniejsze `1 << n` na nazwy w enemy/ally/arrows/ladder.
3. Dodać `.gdignore` do archive folder albo przenieść archiwum poza skan Godot.
4. Oznaczyć stare docs jako historyczne.
5. Dodać proste debug counters: recovery/stuck per unit.

Dlaczego najpierw:

- mały zakres;
- małe ryzyko;
- od razu zmniejsza chaos;
- ułatwia dalszy refaktor.

Walidacja:

- parse/load check;
- headless scene smoke;
- probe: wypisać collision layers/masks głównych aktorów.

## Faza B — `CastleModel` minimum

Zakres:

1. Dodać `CastleModel` jako node/model generowany przez `FortressGenerator`.
2. Przenieść do niego rejestrację tactical slots i ladder slots.
3. Dodać minimap footprints.
4. Przerobić `AllyPlacer`, żeby czytał `archer_slots`, nie stałe geometrii.
5. Przerobić minimapę, żeby używała `minimap_footprints`.

Cel:

- po tej fazie układ zamku można zmieniać bez poprawiania placera/minimapy.

Walidacja:

- probe: liczba gate/keep/ladder/archer slots;
- probe: każdy slot ma podłoże raycastem;
- screenshot przez użytkownika po `P`.

## Faza C — `GroundResolver` + poprawne lane’y

Zakres:

1. Dodać `GroundResolver`.
2. Wszystkie enemy spawns i ladder approach points walidować fizycznie.
3. Odrzucać lane bez world collision.
4. Debug panel: enemies without floor.

Cel:

- koniec wrogów na górach, pod ziemią albo niewidocznych duchów.

Walidacja:

- probe 30–60 spawnów bez gry: każdy ma `ray_hit=true`;
- headless 10 s bez enemy below `y < -8`;
- HUD/minimapa count zgodny z aktywnymi node’ami.

## Faza D — `SiegeDirector`

Zakres:

1. Dodać node `SiegeDirector` w `play.tscn`.
2. Przenieść lane selection z `WaveSpawner`.
3. Drabiniarze dostają lane assignment od directora.
4. Infantry/archers pytają directora o aktywne drabiny i wall objectives.
5. Debug: lane id, reserved, active ladder, queue.

Cel:

- fale rozproszone po murze;
- drabiniarze nie idą automatem pod bramę;
- `WaveSpawner` staje się prostszy.

Walidacja:

- probe: fala 2 ma minimum kilka unikalnych lane ids;
- probe: każda aktywna drabina ma `surface=wall`;
- screenshot: drabiny na szerokości muru.

## Faza E — `TraversalController` dla drabin

Zakres:

1. Dodać controller traversal.
2. Przenieść climb z `Enemy` i `LadderOrcEnemy`.
3. `SiegeLadder` tworzy link i queue, ale traversal wykonuje controller jednostki.
4. Dodać exit validation na topie muru.
5. Dodać fail state, jeśli top przestaje być valid.

Cel:

- nikt nie wchodzi po powietrzu;
- nikt nie wchodzi po wieży;
- jedna implementacja climb.

Walidacja:

- probe: climber positions leżą blisko segmentu ladder foot-top;
- probe: po climb end unit jest na valid wall surface;
- capacity czyści martwe/usunięte jednostki.

## Faza F — `UnitLocomotion`

Zakres:

1. Dodać komponent locomotion.
2. Najpierw podłączyć do wrogów poza ladder climb.
3. Potem podłączyć do łuczników.
4. Ograniczyć custom fallback walker do debug/temporary.
5. Nie włączać pełnego native nav dla wszystkich naraz; robić etapami.

Cel:

- jeden model ruchu i stuck/recovery;
- mniej drżenia;
- mniej kolizji między kilkoma systemami ruchu.

Walidacja:

- probe: przy rozkazie `5` każdy łucznik ma stan moving/arrived/unreachable, bez drżenia między driverami;
- debug: recovery count nie rośnie podczas normalnej gry;
- screenshot/manual test użytkownika.

## Faza G — `DefenderAI` slot scoring

Zakres:

1. Wyciągnąć targeting i shooting z `AllyArcher`.
2. Dodać scoring slotów.
3. Przy bad shot rezerwować nowy slot, nie robić lokalnego losowego kroku.
4. Rozkazy `1–5` mapować na slot categories i target priorities.

Cel:

- łucznicy aktywnie szukają pozycji;
- nie strzelają w mur/podłogę;
- nie stoją bezczynnie przy bramie.

Walidacja:

- probe LOS: jeśli target blocked, archer changes slot;
- manual: wróg przy bramie jest ostrzeliwany;
- debug: archer shows target, chosen slot, LOS result.

## Faza H — `CombatRegistry`

Zakres:

1. Dodać registry node.
2. Podłączyć spawn/despawn/death.
3. HUD, minimapa i targeting czytają registry.
4. Skan grup zostaje fallbackiem/debugiem.

Cel:

- koniec ghost enemy na minimapie/HUD;
- mniej skanów grup;
- jeden aktywny stan gry.

Walidacja:

- HUD count = registry count;
- minimapa count = registry count;
- dead/falling/hidden units są pruned.

## Co robimy jako pierwsze

Najlepszy pierwszy pakiet implementacyjny to Faza A + początek Fazy B:

1. `collision_layers.gd`;
2. `.gdignore` dla archiwum;
3. stale banners dla starych docs;
4. szkielet `CastleModel`;
5. rejestracja istniejących slotów do `CastleModel`;
6. `AllyPlacer` czyta `CastleModel` zamiast kopiować geometrię.

To jest bezpieczne, bo nie zmienia jeszcze całego AI. Jednocześnie zaczyna usuwać główną przyczynę: wiele systemów rozumie zamek inaczej.

## Czego nie robić

- Nie przepisywać wszystkiego naraz.
- Nie usuwać fallbacków, dopóki probe nie potwierdzą nowej ścieżki.
- Nie włączać `NavigationAgent3D` dla wszystkich jednostek naraz.
- Nie bake’ować runtime z pełnej wizualnej geometrii.
- Nie robić kolejnych ręcznych pozycji łuczników przy bramie.
- Nie naprawiać drabin przez teleport climb end.
- Nie uruchamiać `make test`, dopóki użytkownik nie poprosi.

## Minimalne probe/checki na każdą fazę

Bez `make test`:

1. Parse/load check kluczowych skryptów.
2. Headless smoke `scenes/play.tscn` przez 5–8 s.
3. Probe slotów zamku:
   - gate slots > 0;
   - keep slots > 0;
   - ladder slots > 0;
   - każdy slot ma raycast world hit.
4. Probe spawnów:
   - każdy spawn ma physics ground;
   - brak unitów `y < -8`;
   - brak active hidden ghosts.
5. Probe drabin:
   - każda deployed ladder ma foot/top;
   - top jest na wall, nie tower;
   - active climber count czyści stale refs.
6. Probe łuczników:
   - każdy ma current order;
   - każdy moving archer ma nav/debug state;
   - przy blocked LOS pojawia się reposition request.

## Decyzje do potwierdzenia później

1. Czy `CastleModel` ma być node w scenie, czy `Resource` podpięty do generatora?
2. Czy `CombatRegistry` ma być node w `play.tscn`, czy autoload?
3. Czy navmesh ma mieć osobne `NavigationRegion3D` per warstwa, czy jedną region z layers?
4. Czy drabiny mają mieć enemy-only navigation layer od razu, czy najpierw custom traversal bez path query?
5. Czy taran zostaje `CharacterBody3D`, czy dostaje osobny `SiegeEngine` base?

Moja rekomendacja na teraz:

- `CastleModel` jako node dziecko `FortressGenerator`/GeneratedGeometry, bo jest zależny od konkretnego zamku.
- `CombatRegistry` jako node w `play.tscn`, nie autoload, bo dotyczy jednej rozgrywki.
- osobne nav layers, ale jedna prosta implementacja startowa.
- drabiny: najpierw `TraversalController` + `NavigationLink3D` metadata, potem pełny agent link flow.
- taran zostaje subclassą `Enemy` do czasu, aż ruch zwykłych wrogów zostanie ustabilizowany.

