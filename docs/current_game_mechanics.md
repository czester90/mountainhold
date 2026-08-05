# Mountainhold — dogłębna analiza gry i mechanik

Stan dokumentu: 2026-07-28. Dokument opisuje aktualny model gry, strukturę projektu, gameplay, systemy AI i długi techniczne tak, żeby kolejna sesja Codexa mogła wejść w projekt bez zgadywania.

## 1. Wizja gry

`Mountainhold` jest prototypem gry oblężniczej w Godot 4.7. Gracz jest obrońcą górskiej twierdzy i walczy z falami orków jako łucznik FPS. Twierdza jest generowana modułowo i ma przypominać obronę typu Helmowy Jar: główny mur, brama, wieże, przejścia, dziedziniec, góra i wewnętrzny stołp.

Najważniejsze założenie projektowe: gra ma być fizycznie wiarygodna. AI nie może rozwiązywać problemów ruchem „po skrócie”. Łucznicy i wrogowie muszą poruszać się po realnym świecie gry, korzystać z kolizji Godot, schodów, ramp, przejść, okien, drabin i jawnych połączeń nawigacyjnych. Jeśli agent nie może dotrzeć do celu, to jest problem mapy/nawigacji, a nie powód do teleportu.

## 2. Główna pętla gry

1. Projekt startuje z `scenes/ui/main_menu.tscn`, a właściwa rozgrywka znajduje się w `scenes/play.tscn`.
2. `scenes/play.tscn` instancjuje twierdzę, gracza, spawner fal, system rozkazów, HUD, pause menu, game over, placer łuczników i panel developerski.
3. `FortressGenerator` buduje zamek i rejestruje metadane dla AI: sloty taktyczne, sloty drabin i krawędzie nawigacyjne.
4. `AllyPlacer` ustawia naszych łuczników na realnych powierzchniach zamku.
5. `WaveSpawner` tworzy kolejne fale wrogów.
6. Tarany atakują bramę.
7. Orkowie z drabinami niosą, ustawiają i aktywują drabiny przy murach.
8. Zwykła piechota i wrodzy łucznicy powinni używać drabin, żeby dostać się na mury.
9. Gracz i łucznicy zabijają wrogów; bohater i łucznicy awansują po progach zabójstw.
10. Jeśli brama padnie, wróg może przejść dalej. Jeśli padnie stołp, gracz przegrywa.

## 3. Sceny i skład runtime

### `scenes/play.tscn`

Najważniejsza scena rozgrywki:

- `Fortress` — instancja `scenes/castle/fortress.tscn`.
- `Player` — instancja `scenes/player/fps_bow_player.tscn`, startowo w okolicy `Vector3(294, 22, 480)`.
- `WaveSpawner` — Node z `scripts/enemy/wave_spawner.gd`.
- `DefenderOrders` — Node z `scripts/ally/defender_orders.gd`.
- `HUD` — Canvas/UI z `scripts/ui/hud.gd`, spięty ze spawnerem.
- `Allies` — Node z `scripts/ally/ally_placer.gd`.
- `DeveloperPanel` — debug overlay.

### `scenes/castle/fortress.tscn`

Środowisko twierdzy:

- `WorldEnvironment` — światło, sky, fog, tonemapping.
- `Sun` — DirectionalLight3D.
- `TerrainModule` — `scripts/castle/modules/terrain_module.gd`.
- `Terrain3D` — dane terenu z `res://assets/processed/terrain/fortress_kit_data`.
- `FortressGenerator` — `scripts/castle/fortress_generator.gd`.

## 4. Konfiguracja projektu

`project.godot`:

- nazwa: `Mountainhold`;
- opis: first-person archery castle-siege;
- main scene: `res://scenes/ui/main_menu.tscn`;
- autoloady: `GameSettings`, `Audio`;
- renderer: Forward+;
- viewport: 1600x900;
- pluginy: Terrain3D i GdUnit4.

`Makefile`:

- `make run` — odpala menu.
- `make play` — odpala scenę gry.
- `make editor` — edytor Godot.
- `make import` — import headless.
- `make startup` — krótki smoke menu.
- `make test` i `make test-target` — GdUnit.

Użytkownik prosił, żeby na razie nie odpalać `make test`; używać krótkich probe/headless checków.

## 5. Układ świata i orientacja

Wspólne punkty orientacyjne powtarzają się w systemach:

- środek osi Z fortecy: około `z = 500`;
- front/brama: okolice `x = 284–301`;
- wnętrze/stołp: około `x = 345–357`;
- gracz startuje na obronnej stronie twierdzy, patrząc w stronę ataku.

`WaveSpawner` używa trasy bramnej:

- muster: `Vector3(276, 0, 500)`;
- gate: `Vector3(285, 0, 500)`;
- through gate: `Vector3(301, 0, 500)`;
- causeway foot: `Vector3(322, 0, 500)`;
- causeway: `Vector3(341, 0, 500)`;
- inner gate: `Vector3(351, 0, 500)`;
- keep: `Vector3(357, 0, 500)`.

Minimapa mapuje świat tak, aby wróg atakował „z góry” ekranu. W `scripts/ui/minimap.gd` oś świata jest przeliczana tak, że `world.z` jest odbijane poziomo, a `world.x` idzie w pion minimapy.

## 6. Generowanie twierdzy

Główna implementacja to `scripts/castle/fortress_generator.gd`. Starszy `scripts/castle/castle_generator.gd` wygląda na kod prototypowy/legacy i nie powinien być traktowany jako aktualny generator rozgrywki bez sprawdzenia użyć.

Generator buduje:

- mury;
- bramę i gatehouse;
- wieże;
- schody i przejścia;
- causeway;
- wewnętrzny stołp;
- teren i osadzenie elementów;
- sloty taktyczne dla łuczników;
- sloty drabin dla drabiniarzy;
- edge/linki nawigacyjne dla AI.

Kluczowe grupy/metadane:

- `castle_tactical_slot` — ogólne sloty dla obrońców.
- `castle_tactical_slot_gate` — sloty używane przy rozkazie obrony bramy.
- `castle_tactical_slot_keep` — sloty do odwrotu do stołpu.
- `castle_ladder_slot` — miejsca, gdzie można stawiać drabiny.
- `castle_navigation_edge` — jawne połączenia nawigacyjne między punktami.
- `ladder_surface = "wall"` — slot drabiny jest ścianą/murem, nie wieżą.
- `nav_a`, `nav_b` — końce połączenia nawigacyjnego.

Istotne: pionowe albo półsztuczne krawędzie nawigacyjne są niebezpieczne. Poprzednio powodowały, że wróg „wspinał się” po wieżach lub ścianach. Obecne AI wroga celowo odrzuca podejrzane fake vertical edges. Docelowo każdy edge powinien odpowiadać realnej geometrii: schodom, rampie, przejściu albo fizycznej drabinie.

## 7. Moduły zamku

Moduły są w `scripts/castle/modules/`. Bazą jest `castle_module.gd`; konkretne typy reprezentują mury, narożniki, wieże, gatehouse, schody, causeway, cave/terrain i stołp.

Przy dodawaniu nowego modułu trzeba zadbać o cztery rzeczy:

1. geometria wizualna;
2. collision shapes na właściwych warstwach;
3. sloty taktyczne/sloty drabin, jeśli moduł ma być używany przez AI;
4. jawne, fizycznie poprawne połączenia nawigacyjne.

Nie dodawać sztucznych podestów ani niewidzialnych mostków jako fixów. Jeśli AI ma przejść z dziedzińca na mur, musi istnieć czytelna droga w architekturze.

## 8. Model statystyk

Wspólne statystyki są w `scripts/characters/unit_stats.gd`, a konkretne dane w `data/*.tres`.

`UnitStats` zawiera:

- `type_id`, `display_name`;
- `faction`: `PLAYER`, `ALLY`, `ENEMY`;
- `role`: `HERO`, `INFANTRY`, `ARCHER`, `RAM`, `BOSS_RAM`, `LADDER_ORC`;
- `level`, `xp`, `xp_value`, `kill_value`, `kills`;
- `max_hp`, `defense`, `armor`, `armor_type`;
- `speed`, `gravity`, `step_height`;
- `attack_range`, `attack_damage`, `melee_attack_damage`, `attack_interval`;
- `ranged_attack_damage`, `fire_interval`, `arrow_speed`, `sight_range`, `spread_deg`, `muzzle_height`.

Progresja używa progów zabójstw: 5, 10, 20, 40 itd. Każdy bonusowy poziom daje mnożnik `1 + 0.10 * bonus_levels`. Dotyczy to bohatera i naszych łuczników. W praktyce oznacza to +10% na poziom do statystyk takich jak atak, obrona i zasięg.

Aktualne dane:

- bohater: 100 HP, 55 ranged damage, 6 melee, 90 sight range;
- nasz łucznik: 45 HP, 25 ranged damage, 70 sight range;
- piechota wroga: 100 HP, speed 2.3, melee 3/attack 6;
- wróg łucznik: 85 HP, ranged 8, sight 55;
- taran: 300 HP, defense 3, armor 0.2, damage 26;
- boss taran: 700 HP, defense 5, armor 0.28, damage 34;
- ork z drabiną: bazowo 125 HP, speed 3.9, damage 11, ale podczas niesienia jest wzmacniany.

## 9. Gracz

`scripts/player/fps_bow_player.gd` jest `CharacterBody3D` i realizuje:

- ruch FPS;
- obrót myszą;
- skok;
- step-up po niskich przeszkodach;
- łuk ze stanami `IDLE`, `DRAW`, `HELD`, `FIRE`;
- strzelanie fizycznymi strzałami z `scenes/player/arrow.tscn`;
- HP i obrażenia;
- sygnały trafień, zabić, oddanych strzałów i śmierci.

Gracz używa `data/player_hero.tres`. Po zabiciu przeciwnika wzrasta `kills`, XP i potencjalnie poziom. Strzały gracza są fizyczne (`RigidBody3D` w `scripts/player/arrow.gd`) i powinny trafiać przez rzeczywistą kolizję.

## 10. Strzały

`scripts/player/arrow.gd` odpowiada za strzałę gracza:

- jest `RigidBody3D`;
- ma collision layer/mask pod świat, wrogów i drabiny;
- może zadawać obrażenia wrogom i `SiegeLadder`;
- emituje sygnał trafienia;
- po trafieniu powinna logicznie przestać być aktywnym pociskiem.

Wrogowie łucznicy mają osobne `scripts/enemy/enemy_arrow.gd`.

## 11. Wrogowie — wspólna baza

`scripts/enemy/enemy.gd` jest bazą dla piechoty, łuczników, taranów i drabiniarzy. To `CharacterBody3D` z komponentami zdrowia i ataku.

Wspólne założenia:

- wrogowie są w grupie `enemy`;
- aktywność powinna być sprawdzana przez `is_active_enemy()`;
- AI ma odrzucać martwe, ukryte, spadające i usunięte jednostki;
- collision layer/mask muszą obejmować świat, wrogów, sojuszników i gracza;
- ruch ma iść przez `move_and_slide()` i kolizje, nie przez teleport.

AI bazowe obsługuje:

- trasę do bramy/stołpu;
- zachowanie przy bramie;
- szturm muru;
- znajdowanie aktywnych drabin;
- kolejkę przy drabinie;
- rezerwację wspinania;
- przejście ze stanu pod murem do stanu na murze;
- walkę z obrońcami na murze;
- unstuck/recovery przy spadnięciu albo złej pozycji.

Kluczowa reguła: zwykła piechota i wrodzy łucznicy nie powinni atakować bramy. Brama jest zadaniem taranów. Piechota ma korzystać z drabin.

## 12. Tarany

`scripts/enemy/ram_enemy.gd` dziedziczy po `Enemy`.

Rola:

- powolny, bardzo wytrzymały cel;
- jedzie do bramy;
- tylko taran może legalnie atakować bramę;
- po przebiciu bramy powinien trzymać pozycję przy wyłomie, nie szturmować stołpu;
- ma słaby punkt nisko pod dachem.

`scripts/enemy/boss_ram_enemy.gd` jest mocniejszą wersją finałową: większy HP, większa obrona, ciemniejszy wygląd, ta sama rola.

## 13. Wrodzy łucznicy

`scripts/enemy/archer_enemy.gd` rozszerza bazowego wroga.

Założenie:

- wrogi łucznik powinien stać w dystansie i ostrzeliwać obrońców;
- nie powinien niszczyć bramy;
- jeśli trwa wall assault, powinien próbować użyć aktywnej drabiny, jeśli jest dostępna i ma sens;
- jeśli ma widoczny cel w zasięgu, może strzelać;
- jeśli nie ma celu, nie powinien sztucznie wspinać się po murze.

## 14. Orkowie z drabinami

`scripts/enemy/ladder_orc_enemy.gd` realizuje najważniejszą mechanikę oblężenia murów.

Zasady:

- tylko ork z drabiną może uczestniczyć w stawianiu drabiny;
- drabina jest niesiona przez ekipę, standardowo 4 orków;
- do rozpoczęcia/utrzymania stawiania potrzebne są minimum 2 jednostki;
- jeśli zostaje jeden, wolny ork powinien dołączyć jako helper;
- rozstawianie nie jest natychmiastowe — trwa `DEPLOY_DURATION`, obecnie około 3.2 s;
- podczas niesienia drabiniarze są silniejsi i trudniejsi do zabicia;
- drabiny mogą być stawiane tylko na slotach muru, nie wieży ani bramy;
- po rozstawieniu noszący/assistujący powinni przejść w rolę wspinaczy.

Aktualny model carry:

- leader zarządza deploymentem;
- członkowie ekipy mają offsety przy drabinie;
- setup bierze `crew_id`, index, foot, top, normal, siege/spawner i approach anchor;
- wzmocnienie carry wymusza co najmniej około 275 HP, defense 4, armor 0.34 i attack 16.

Najczęstsze błędy, których trzeba pilnować:

- drabiniarze idą pod bramę zamiast pod rozproszone sloty muru;
- drabiny są za krótkie albo nie dosiadają topu muru;
- wróg wspina się obok drabiny zamiast po niej;
- zwykły wróg „stawia” drabinę bez ekipy;
- drabina pojawia się natychmiast bez animacji/czasu;
- drabina trafia na wieżę;
- wróg kończy wspinanie w powietrzu.

## 15. Drabina oblężnicza

`scripts/enemy/siege_ladder.gd` reprezentuje aktywną drabinę.

Rola:

- ma HP i może być niszczona;
- ma collision hitbox;
- rejestruje grupę `siege_ladder`;
- po aktywacji trafia do `siege_ladder_active`;
- posiada `NavigationLink3D`;
- ma `foot`, `top`, `queue_point()`;
- ogranicza liczbę aktywnych wspinaczy przez `climb_capacity`.

Ważna poprawka historyczna: licznik aktywnych wspinaczy musi usuwać martwe, nieaktywne, usunięte i takie, które już nie są w stanie wspinania. W przeciwnym razie kolejka przy drabinie blokuje się na zawsze.

## 16. Spawner fal

`scripts/enemy/wave_spawner.gd` zarządza oblężeniem.

Aktualne parametry:

- fale: 14, 20, 30, 42 jednostki;
- odstęp spawnów: około 1.05 s;
- przerwa między falami: około 6 s;
- brama: 750 HP;
- stołp/keep: 500 HP.

Spawner:

- trzyma listę `_alive`;
- czyści duchy przez `alive_count()`;
- generuje piechotę, wrogich łuczników, tarany, boss taran i ekipy drabin;
- dla taranów ustawia trasę na bramę;
- dla reszty uruchamia wall assault;
- znajduje sloty drabin z grupy `castle_ladder_slot`;
- filtruje sloty tak, aby `ladder_surface == "wall"`;
- sortuje i rozprasza sloty wokół muru, zamiast zawsze wybierać bramę;
- osadza spawn na terenie przez raycast/fallback.

Oczekiwany design fal:

- wrogowie powinni pojawiać się przed walką na całej szerokości muru;
- drabiniarzy ma być wystarczająco dużo, żeby faktycznie tworzyli wiele punktów szturmu;
- zwykła piechota powinna osłaniać drabiniarzy i potem korzystać z aktywnych drabin;
- wróg nie powinien spawnować się na szczytach gór ani poza widocznym/grywalnym polem.

## 17. Nasi łucznicy

`scripts/ally/ally_archer.gd` to AI naszych obrońców.

Założenia:

- łucznik jest `CharacterBody3D`;
- używa `data/ally_archer.tres`;
- ma statystyki, HP, zasięg, atak wręcz i dystansowy;
- dobiera cele i wykonuje rozkazy;
- powinien zmieniać pozycję, jeśli strzał blokuje mur/podłoga;
- nie powinien stać bezczynnie, gdy wróg bije bramę albo stoi pod murem;
- nie powinien strzelać w ścianę;
- nie powinien wisieć w powietrzu;
- powinien korzystać z realnych schodów/przejść.

`scripts/ally/ally_placer.gd` rozstawia łuczników automatycznie:

- na realnych powierzchniach zamku przez raycasty;
- na murach, bramie/galleries, wieżach i rezerwie wewnętrznej;
- z unikaniem spawnu gracza;
- bez ręcznego sztywnego ustawiania każdego łucznika.

Aktualny problem projektowy: AI łuczników i nawigacja obrońców są najbardziej wrażliwym elementem. Użytkownik wielokrotnie wskazywał, że łucznicy blokowali się, drżeli, stali zbyt daleko od muru, strzelali w mur albo nie potrafili zejść/wejść na wieże. Każda zmiana tutaj wymaga sprawdzenia realnej trasy i linii strzału.

## 18. Rozkazy obrońców

`scripts/ally/defender_orders.gd` obsługuje klawisze:

- `1` — atakuj taran;
- `2` — atakuj wrogich łuczników;
- `3` — atakuj najbliższych;
- `4` — więcej łuczników do bramy;
- `5` — wycofaj do stołpu;
- `0` — auto.

Ważna mechanika `4`: nie wszyscy łucznicy idą po pierwszym naciśnięciu. Każde wezwanie zwiększa pulę o około 30%, a kolejne naciśnięcia mogą dojść do 100%.

System ma rezerwacje slotów:

- `castle_tactical_slot_gate` dla bramy;
- `castle_tactical_slot_keep` dla stołpu;
- każdy slot ma `reserved_by`, żeby łucznicy nie nachodzili na siebie;
- rezerwacje muszą być czyszczone, jeśli łucznik zniknie.

## 19. HUD

`scripts/ui/hud.gd` pokazuje:

- HP bramy;
- HP stołpu;
- HP gracza;
- numer i stan fali;
- liczbę wrogów;
- liczbę sojuszników;
- aktualny rozkaz;
- czytelny panel klawiszy;
- prawy roster naszych obrońców;
- minimapę w prawym dolnym rogu;
- ostrzeżenia i chevrony dla taranów;
- flash obrażeń;
- hit/kill feedback.

Roster po prawej powinien być sortowany:

1. bohater;
2. jednostki z najwyższym poziomem;
3. dalej według zabić/statystyk.

## 20. Minimap

`scripts/ui/minimap.gd`:

- rysuje tło, siatkę i legendę;
- zbiera moduły zamku dynamicznie przez skrypty z `scripts/castle/modules/`;
- rysuje footprinty murów, bram, wież, stołpu i schodów;
- pokazuje wrogów, sojuszników i gracza;
- wyróżnia taran jako pomarańczowy prostokąt;
- wyróżnia drabiniarza jako trójkąt;
- filtruje niewidocznych/nieaktywnych/spadających wrogów.

Znany historyczny problem: licznik albo minimapa pokazywały jednego wroga, którego nie było widać. To zwykle oznacza, że `_alive` albo minimapa widzą node, który jest formalnie w drzewie, ale faktycznie jest martwy, ukryty, daleko, pod ziemią albo poza aktywnym stanem. Każdy taki system powinien korzystać z `is_active_enemy()`.

## 21. Panel developerski i screenshoty

`scripts/ui/developer_panel.gd`:

- `P` zapisuje screenshoty do `res://screenshots/player/shot_NNN.png`;
- `F3` albo `Tab` przełącza panel;
- panel pokazuje FPS, wave, HP bramy, liczniki wrogów/ally, stany nawigacji, sloty i pozycję gracza.

Na Macu `F3` może nie działać przez systemowe skróty, więc `Tab` jest bezpiecznym fallbackiem.

## 22. Kolizje i fizyka

Projekt powinien polegać na mechanikach Godot:

- `CharacterBody3D` dla postaci;
- `RigidBody3D` dla strzał;
- collision layers/masks dla świata, wrogów, sojuszników, gracza, drabin i pocisków;
- raycasty do osadzania jednostek na ziemi/murach;
- `NavigationRegion3D` i `NavigationLink3D` tylko tam, gdzie odpowiadają realnej geometrii.

Najważniejsze zasady:

- każda postać musi mieć collider;
- tarany muszą mieć collider;
- drabiny muszą mieć hitbox/collider;
- jednostki nie mogą nachodzić na siebie bez ograniczeń;
- jeśli coś spada przez świat, to trzeba sprawdzić collision shape, layer/mask, osadzenie spawn pointu i raycast do podłoża;
- jeśli coś skacze/drży, to często winne są konflikt ruchu do punktu, separacja, zła wysokość celu albo walka `move_and_slide()` z ręcznym ustawianiem pozycji.

## 23. Historia ważnych problemów i poprawek

### Łucznicy

Problemy zgłaszane przez użytkownika:

- stali za daleko od muru;
- strzelali w podłogę lub mur;
- nie widzieli wroga bijącego bramę;
- drżeli przy rozkazie;
- gromadzili się w środku bramy;
- nie umieli wejść/zejść z wieży;
- potrafili wisieć w powietrzu;
- po rozkazie `4` za wielu ruszało naraz.

Wniosek: łucznik musi mieć prawdziwe AI pozycyjne, a nie tylko statyczny spawn. Musi oceniać linię strzału i zmieniać slot, jeśli strzał jest blokowany.

### Drabiny

Problemy historyczne:

- drabiny były za małe;
- zamiast ekipy czterech była jedna jednostka;
- drabiniarze szli pod bramę, nie pod mury;
- drabiny pojawiały się od razu;
- zwykły wróg potrafił aktywować ladder flow;
- część wrogów wchodziła w powietrzu;
- część drabin trafiała na wieże;
- wspinacze blokowali capacity drabiny mimo śmierci/usunięcia.

Aktualne reguły naprawcze:

- tylko `LadderOrcEnemy` może nieść/stawiać drabinę;
- minimum 2 jednostki do deploymentu;
- deployment trwa;
- slot musi być oznaczony jako mur;
- climb start ma być przy stopie drabiny;
- top ma być dosiadany przez raycast do realnej powierzchni muru;
- capacity musi usuwać stale climber refs.

### Wrogowie na murach/wieżach

Problem: próba umożliwienia wrogom wejścia do łuczników na wysokich roof/tower slotach ujawniła, że dynamiczny graph zawiera fake vertical edges. Wrogowie zaczęli wspinać się po ścianach i wieżach.

Obecny kompromis:

- AI wroga odrzuca wysokie cele bez realnego dojścia;
- fake vertical edges są pomijane;
- wróg nie powinien wspinać się po wieży;
- pełne wejście do wież/gatehouse wymaga prawdziwej architektury przejść i graphu.

## 24. Długi techniczne

Najważniejsze długi:

1. Jeden spójny system nawigacji po zamku.
2. Rozdzielenie realnych edge’y od fallback/debug edge’y.
3. Pełna walidacja slotów: czy slot ma podłoże, wysokość, dojście i linię strzału.
4. Unikanie magicznych Y/teleportów w AI.
5. Lepsza separacja jednostek, żeby nie nachodziły na siebie.
6. Dynamiczne generowanie minimapy i graphu z tych samych danych co twierdza.
7. Wyczyszczenie legacy generatorów i historycznych docs.
8. Headless probes dla fal, drabin i nawigacji bez uruchamiania pełnych testów.

## 25. Docelowy model nawigacji

Docelowo twierdza powinna emitować jeden „castle navigation model”:

- listę walkable surfaces;
- listę stairs/ramp transitions;
- listę doors/passages;
- listę windows/archer positions;
- listę wall edges dostępnych dla drabin;
- listę tower entries;
- listę gate/keep rally slots;
- listę collision-validated waypoints.

AI nie powinno znać ręcznie układu zamku poza zapytaniem do tego modelu. Jeśli schemat muru się zmieni, łucznicy, wrogowie, minimapa i sloty powinny nadal działać, bo opierają się na wygenerowanych metadanych.

## 26. Zasady dla przyszłego Codexa

Przed implementacją:

- przeczytaj `CODEX.md`;
- sprawdź konkretny skrypt, którego dotyczy bug;
- jeśli bug dotyczy drabin, przeczytaj `docs/task-log/ladder-deploy-stall-analysis.md`;
- jeśli bug dotyczy ruchu łuczników, przeczytaj `docs/research/archer_navigation_research.md`;
- jeśli bug dotyczy kolizji/spadania, przeczytaj `docs/research/world_collision_physics_research.md`.

Podczas implementacji:

- naprawiaj przyczynę, nie objaw;
- nie dodawaj sztucznych podestów;
- nie teleportuj postaci;
- nie zostawiaj dwóch równoległych mechanik robiących to samo;
- jeśli coś jest legacy, oznacz to albo usuń dopiero po sprawdzeniu referencji;
- dodawaj debug/probe tylko tam, gdzie pomaga potwierdzić mechanikę.

Po implementacji:

- uruchom parse/load check Godot, jeśli zmieniałeś GDScript;
- uruchom krótki headless smoke/probe, jeśli zmieniałeś sceny lub AI;
- nie odpalaj `make test` bez zgody użytkownika;
- opisz dokładnie, co zostało sprawdzone i czego nie sprawdzono.

## 27. Krótkie przepisy walidacyjne

Parser/load check dla skryptów:

```sh
godot --headless --path . --script /tmp/check_scripts.gd
```

Krótki smoke sceny gry z timeoutem:

```sh
python3 - <<'PY'
import subprocess
cmd = ["godot", "--headless", "--path", ".", "scenes/play.tscn", "--quit-after", "5"]
subprocess.run(cmd, timeout=8)
PY
```

Probe runtime:

```gdscript
extends SceneTree

func _init() -> void:
	var scene := load("res://scenes/play.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(2.0).timeout
	print("enemies=", get_nodes_in_group("enemy").size())
	print("allies=", get_nodes_in_group("ally").size())
	print("ladders=", get_nodes_in_group("siege_ladder").size())
	quit()
```

Uwaga: ostrzeżenia typu `instance_reset_physics_interpolation() is deprecated` oraz część RID/ObjectDB leak warnings na wyjściu headless były obserwowane historycznie i nie zawsze oznaczają nową regresję gameplayu. Nowe `SCRIPT ERROR`, parse errors, `get_node()` absolute path errors albo invalid transform errors trzeba traktować poważnie.

## 28. Słownik nazw

- `bohater` — gracz FPS, `Player`, role `HERO`.
- `nasi łucznicy` — allied defenders, grupa `ally`, `AllyArcher`.
- `wróg` — każdy node w grupie `enemy`.
- `piechota` — podstawowy ork melee.
- `wrogi łucznik` — enemy archer, strzela do obrońców.
- `taran` — enemy ram, jedyny zwykły atakujący bramę.
- `boss taran` — finalny, ciężki taran.
- `drabiniarz` — `LadderOrcEnemy`, niesie/stawia drabinę.
- `siege ladder` — aktywna drabina jako node i nawigacyjny link.
- `brama` — gate HP w `WaveSpawner`.
- `stołp` — keep/ostatni punkt obrony.
- `slot` — punkt taktyczny albo miejsce na drabinę.
- `fake vertical edge` — połączenie nawigacyjne, które zmienia wysokość bez realnej geometrii; unikać w AI.

