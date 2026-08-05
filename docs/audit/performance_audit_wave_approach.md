# Mountainhold — performance audit: fala przed murem

## Objaw

Gra najbardziej przycina, gdy wróg zbliża się do muru, zanim jeszcze walka przeniesie się na blanki. Po zabiciu wrogów płynność wraca. To oznacza koszt zależny od liczby aktywnych jednostek, targetowania, strzał i deploy drabin, a nie sam zamek.

## Wyniki probe

Probe headless nie oddaje idealnie renderingu Metal/Forward+, ale dobrze pokazuje trend CPU/logiki:

- Przed limitem raycastów, ogień łuczników włączony:
  - `approach_perf fire=true avg=76.0 low=579 enemies=28 ladders=1`
- Przed limitem raycastów, ogień łuczników wyłączony:
  - `approach_perf fire=false avg=130.4 low=169 enemies=34 ladders=3`
- Po ograniczeniu targetowania i współdzieleniu zasobów strzał:
  - `approach_perf fire=true avg=111.2 low=237 enemies=28 ladders=1`
- Po rozłożeniu spawnu ekip i większej liczbie aktywnych drabin:
  - `approach_perf fire=true avg=92.9 low=480 enemies=28 ladders=2 climbing=2`
- Precyzyjny frame-time probe po starcie sceny:
  - `frame_time avg_ms=10.65 max_ms=199 over16=485 over33=83 over50=53 enemies=28 ladders=2`

Interpretacja: średnia klatka jest akceptowalna, ale są spike’i do około `199ms`. Gracz czuje je jako szarpnięcia/freezy.

## Główni winowajcy

### 1. Targetowanie łuczników i LOS raycasty

Największa różnica była między ogniem ON i OFF. Przy 20 łucznikach oraz kilkudziesięciu wrogach każdy refresh celu robił:

- skan kandydatów,
- scoring celu,
- wiele raycastów LOS do kilku punktów ciała,
- czasem dodatkowy ballistic arc check przed strzałem.

To odpala się właśnie wtedy, gdy fala wchodzi w zasięg łuczników, czyli przed murem.

Zrobione:

- `AllyArcher` odświeża target rzadziej.
- `DefenderTargeting` raycastuje tylko kilku najlepszych kandydatów, nie całą falę.
- `TargetingComponent` ma limit kandydatów LOS.

### 2. Alokacje strzał

Każda strzała gracza/łucznika budowała własne:

- `CylinderMesh`,
- `CapsuleShape3D`,
- `StandardMaterial3D`.

Przy salwie 20 łuczników dawało to alokacyjne spike’i.

Zrobione:

- `scripts/player/arrow.gd` używa współdzielonych mesh/material/shape.
- `scripts/enemy/enemy_arrow.gd` używa współdzielonych mesh/material.

### 3. Spawn ekip drabinowych w jednej klatce

`ladder_crew` logicznie jest jednym wpisem fali, ale fizycznie tworzy:

- 4 nosicieli drabiny,
- 2 eskorty,
- wizual niesionej drabiny.

Wcześniej wszystko powstawało w jednej klatce. To jest klasyczny spike spawnu.

Zrobione:

- spawn członków ekipy drabinowej rozłożony na kolejne frame’y,
- wizual niesionej/postawionej drabiny ma mniej belek.

### 4. Deploy drabiny nadal tworzy obiekty runtime

Postawienie drabiny nadal tworzy:

- `SiegeLadder`,
- `NavigationLink3D`,
- `StaticBody3D`,
- `CollisionShape3D`,
- wiele `MeshInstance3D` belek.

To prawdopodobnie odpowiada za część pozostałych spike’ów `>50ms`.

Nie naprawione jeszcze:

- pooling drabin,
- cache/prefab gotowego mesha drabiny,
- rozłożenie budowy postawionej drabiny na kilka ramek.

### 5. Separacja tłumu

Każdy wróg co jakiś czas sprawdza sąsiadów, aby się nie nakładać. Przy korku pod drabiną robi się to kosztowne.

Zrobione:

- wolniejsze odświeżanie separacji,
- limit sąsiadów na jednostkę.

Docelowo:

- spatial hash/grid zamiast skanowania list aktywnych jednostek.

### 6. UI

HUD/minimapa/developer panel potrafią dodawać koszt przy dużych listach jednostek. Największy jawny problem był w rosterze obrońców sortowanym co klatkę.

Zrobione:

- roster obrońców odświeża się co `0.35s`.

Docelowo:

- developer panel powinien mieć tryb „light” i liczyć ciężkie sekcje rzadziej, np. co `1s`.

## Rekomendowana kolejność następnych napraw

1. **Object pooling dla strzał**
   - Nie tworzyć/usuwać `RigidBody3D` dla każdej strzały.
   - Trzymać pulę aktywnych/nieaktywnych strzał.

2. **Prefab/cache dla drabin**
   - Prebuild mesh/material/shape drabiny.
   - Przy deploy tylko ustawić transform i aktywować, bez tworzenia wielu meshów.

3. **Spatial grid dla jednostek**
   - Separacja i targetowanie nie powinny skanować całych list.
   - Grid po XZ pozwoli pytać tylko sąsiednie komórki.

4. **Budżet AI per frame**
   - Nie każdy łucznik i wróg musi robić pełną decyzję w tej samej klatce.
   - Dodać scheduler: część jednostek myśli w frame N, część w N+1/N+2.

5. **Render LOD / proxy dla dużych bitew**
   - Dalsi wrogowie mogą mieć tańsze modele lub mniej elementów.
   - Docelowo większa bitwa wymaga mniej node’ów na jednostkę.

## Wniosek

Obecny problem to nie pojedyncza kolizja ani jeden błędny ork. To kilka nakładających się spike’ów:

- targetowanie łuczników,
- salwy strzał,
- spawn ekip drabinowych,
- runtime budowa drabin,
- tłum pod murem.

Żeby bitwa była większa, nie powinniśmy teraz po prostu zwiększać liczby wrogów. Najpierw trzeba usunąć spike’i alokacji i pełne skany list. Wtedy można bezpiecznie podnosić liczebność fal.
