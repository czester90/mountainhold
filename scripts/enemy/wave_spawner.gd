class_name WaveSpawner
extends Node3D

## Runs sequential waves of besiegers. Each wave spawns N enemies (staggered) in the western
## field; they march on the gate. The next wave starts once the current one is cleared (killed
## or breached). Exposes wave()/alive_count()/breaches()/finished() so a HUD can poll it.

const CollisionLayers := preload("res://scripts/core/collision_layers.gd")
const GROUND_RESOLVER_SCRIPT := preload("res://scripts/core/ground_resolver.gd")
const SIEGE_DIRECTOR_SCRIPT := preload("res://scripts/enemy/siege_director.gd")
const SCENES := {
	"infantry": preload("res://scenes/enemy/enemy_infantry.tscn"),
	"archer": preload("res://scenes/enemy/enemy_archer.tscn"),
	"ram": preload("res://scenes/enemy/enemy_ram.tscn"),
	"bossram": preload("res://scenes/enemy/enemy_bossram.tscn"),
}
const LADDER_ORC_SCENE := preload("res://scenes/enemy/enemy_ladder_orc.tscn")
const LADDER_CARRIERS_PER_CREW := 2
const LADDER_ESCORTS_PER_CREW := 2
const WORLD_MASK := CollisionLayers.WORLD
const GROUND_RAY_TOP := 90.0
const GROUND_RAY_DEPTH := 190.0

# siege route (XZ; y settles by gravity). A MUSTER point first pulls off-centre spawns back to the
# z=500 centreline so they approach the narrow gate head-on; then hammer the gate; once breached,
# flood through the passage to the keep. GATE_WP marks which index is the gate.
const GATE_WP := 1
const ROUTE := [
	Vector3(276.0, 0.0, 500.0),   # 0 muster — funnel to the centreline in the open field
	Vector3(285.0, 0.0, 500.0),   # 1 GATE, field side (blocked while the gate stands)
	Vector3(301.0, 0.0, 500.0),   # 2 through the gate into the bailey
	Vector3(322.0, 0.0, 500.0),   # 3 causeway foot
	Vector3(341.0, 0.0, 500.0),   # 4 up the causeway
	Vector3(351.0, 0.0, 500.0),   # 5 through the inner gate
	Vector3(357.0, 0.0, 500.0),   # 6 keep front — hammer the stołp
]

@export var spawn_centre: Vector3 = Vector3(248.0, 0.0, 500.0)  # western field, ~36 m out from the gate
@export var spawn_spread: Vector3 = Vector3(6.0, 0.0, 30.0)
@export var waves: Array[int] = [14, 20, 30, 42]                # active-unit budget; ladder crews add pressure
@export var wave_gap: float = 6.0
@export var spawn_interval: float = 1.05
@export var auto_start: bool = true
@export var staged_waves: bool = true
@export var staged_auto_start_delay: float = 7.0
@export var staged_start_on_player_shot: bool = true
@export var staging_horizon_distance: float = 22.0
@export var staging_width: float = 96.0
@export var staging_row_gap: float = 3.2
@export var gate_max_hp: float = 750.0         # first line: the gate. Should break mid-wave 3-4 (rams do the work)
@export var keep_max_hp: float = 500.0         # last line: the keep (stołp). At 0 the castle falls

var _terrain: TerrainModule
var _ground_resolver: Node
var _siege_director: Node
var _combat_registry: Node
var _alive: Array = []
var _gate_hp: float = 0.0
var _keep_hp: float = 0.0
var _wave: int = 0
var _finished: bool = false
var _next_in: float = 0.0
var _ladder_crew_seq: int = 1
var _assault_started: bool = false
var _staged_spawn_index: int = 0
var _staged_spawn_total: int = 0
var _staged_orders: Array[Dictionary] = []

func _ready() -> void:
	add_to_group("wave_spawner")
	_gate_hp = gate_max_hp
	_keep_hp = keep_max_hp
	_terrain = _find_terrain(get_tree().current_scene if get_tree().current_scene else get_parent())
	_ground_resolver = GROUND_RESOLVER_SCRIPT.new()
	_ground_resolver.name = "GroundResolver"
	add_child(_ground_resolver)
	_ground_resolver.setup(_terrain)
	_combat_registry = get_tree().get_first_node_in_group("combat_registry")
	_siege_director = SIEGE_DIRECTOR_SCRIPT.new()
	_siege_director.name = "SiegeDirector"
	add_child(_siege_director)
	_siege_director.setup(spawn_centre, spawn_spread, _terrain, _ground_resolver)
	_connect_player_start_signal()
	if auto_start:
		_run()

func wave() -> int: return _wave
func alive_count() -> int:
	if waiting_for_assault():
		_prune_alive()
		return _alive.size()
	if _combat_registry != null and _combat_registry.has_method("active_enemies"):
		return (_combat_registry.call("active_enemies") as Array).size()
	_prune_alive()
	return _alive.size()
func gate_hp() -> float: return _gate_hp
func gate_fraction() -> float: return clampf(_gate_hp / gate_max_hp, 0.0, 1.0)
func gate_open() -> bool: return _gate_hp <= 0.0          # breached — enemies advance to the keep
func keep_hp() -> float: return _keep_hp
func keep_fraction() -> float: return clampf(_keep_hp / keep_max_hp, 0.0, 1.0)
func total_waves() -> int: return waves.size()
func finished() -> bool: return _finished
func lost() -> bool: return _keep_hp <= 0.0              # the castle falls only when the KEEP falls
func won() -> bool: return _finished and alive_count() == 0 and not lost()
func siege_debug_summary() -> String:
	return _siege_director.debug_summary() if _siege_director and _siege_director.has_method("debug_summary") else ""

func _find_terrain(n: Node) -> TerrainModule:
	if n == null:
		return null
	if n is TerrainModule:
		return n
	for c in n.get_children():
		var found := _find_terrain(c)
		if found:
			return found
	return null

func _ground(x: float, z: float) -> float:
	return _ground_resolver.ground_y(x, z) if _ground_resolver else 0.0

func terrain_height(x: float, z: float) -> float:
	return _ground_resolver.terrain_height(x, z) if _ground_resolver else _ground(x, z)

func _ground_hit(x: float, z: float, from_y: float = GROUND_RAY_TOP, depth: float = GROUND_RAY_DEPTH) -> Dictionary:
	return _ground_resolver.raycast_ground(Vector3(x, 0.0, z), from_y, depth) if _ground_resolver else {}

func _has_physics_ground(x: float, z: float) -> bool:
	return _ground_resolver.has_physics_ground(x, z) if _ground_resolver else false

func _nearest_physics_ground(point: Vector3) -> Vector3:
	return _ground_resolver.nearest_physics_ground(point) if _ground_resolver else Vector3.INF

func _ground_search_offsets() -> Array[Vector2]:
	return _ground_resolver.ground_search_offsets() if _ground_resolver else [Vector2.ZERO]

func _valid_spawn_point(point: Vector3) -> Vector3:
	return _ground_resolver.valid_spawn_point(point) if _ground_resolver else point

func _run() -> void:
	await get_tree().process_frame                     # let the scene finish setting up before the first spawn
	for i in waves.size():
		_wave = i + 1
		var kinds := _wave_kinds(i, waves[i])
		if staged_waves:
			await _stage_wave(kinds)
			await _wait_for_assault_start()
			await _activate_staged_wave()
		else:
			for k in kinds:
				_spawn_one(k)
				await get_tree().create_timer(spawn_interval).timeout
		while alive_count() > 0:
			await get_tree().create_timer(0.5).timeout
		if _wave < waves.size():
			_next_in = wave_gap
			await get_tree().create_timer(wave_gap).timeout
			_next_in = 0.0
	_finished = true

func _connect_player_start_signal() -> void:
	if not staged_start_on_player_shot:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_signal("shot_fired"):
		var cb := Callable(self, "start_assault")
		if not player.is_connected("shot_fired", cb):
			player.connect("shot_fired", cb)

func _stage_wave(kinds: Array) -> void:
	_assault_started = false
	_staged_orders.clear()
	_staged_spawn_index = 0
	_staged_spawn_total = _staged_unit_count(kinds)
	for kind in kinds:
		if kind == "ladder_crew":
			_stage_ladder_crew()
		else:
			_stage_one(kind)
		if _staged_spawn_index % 10 == 0:
			await get_tree().process_frame

func _wait_for_assault_start() -> void:
	if not staged_waves:
		return
	var wait_left := staged_auto_start_delay
	_next_in = wait_left
	while not _assault_started and wait_left > 0.0:
		await get_tree().create_timer(0.1).timeout
		if not is_inside_tree():
			return
		wait_left = maxf(0.0, wait_left - 0.1)
		_next_in = wait_left
	_assault_started = true
	_next_in = 0.0

func _activate_staged_wave() -> void:
	if not is_inside_tree():
		return
	var activated := 0
	for order in _staged_orders:
		var unit_value: Variant = order.get("unit", null)
		if unit_value == null or not is_instance_valid(unit_value):
			continue
		var unit := unit_value as Node
		if unit == null:
			continue
		var kind := str(order.get("kind", ""))
		unit.set_meta("staged_waiting", false)
		if kind == "ladder_carrier":
			unit.call("setup_ladder_carry", int(order["crew_id"]), int(order["crew_index"]), order["foot"], order["top"], order["normal"], self, order["crew_spawn"])
		elif kind == "ladder_escort":
			if unit.has_method("setup_wall_assault"):
				unit.call("setup_wall_assault", [order["approach"], order["cover_foot"]], self)
			else:
				unit.call("setup_path", ROUTE, self, GATE_WP)
		elif kind == "ram" or kind == "bossram":
			unit.call("setup_path", ROUTE, self, GATE_WP)
		elif unit.has_method("setup_wall_assault"):
			var assault := _pick_ladder_assault_point()
			unit.call("setup_wall_assault", [assault["approach"], assault["foot"]], self)
		else:
			unit.call("setup_path", ROUTE, self, GATE_WP)
		activated += 1
		if activated % 12 == 0:
			await get_tree().process_frame
	_staged_orders.clear()

func _process(delta: float) -> void:
	_prune_alive()
	# drive the physical gate: shut (solid barrier) while it has HP, swings open once breached
	var gate := get_tree().get_first_node_in_group("gate")
	if gate != null and gate.has_method("set_gate_open"):
		gate.set_gate_open(gate_open())
	if _next_in > 0.0:
		_next_in = maxf(0.0, _next_in - delta)
		# masons patch the gate during the lull between waves (a breached gate at 0 stays breached);
		# capped, so the siege still trends toward the breach climax — holding a wave well pays off next wave
		if _gate_hp > 0.0:
			_gate_hp = minf(gate_max_hp * 0.85, _gate_hp + gate_max_hp * 0.15 / wave_gap * delta)

func time_to_next_wave() -> float:
	return _next_in

func start_assault() -> void:
	_assault_started = true

func waiting_for_assault() -> bool:
	return staged_waves and not _assault_started and not _staged_orders.is_empty()

# wave composition: mostly infantry, ~30% archers, ladder pressure from wave 1,
# plus rams from wave 2 onward. Only rams can break the gate; ladder orcs must climb.
func _wave_kinds(idx: int, n: int) -> Array:
	var out: Array = []
	var rams: int = idx                                    # 0,1,2,3 — escalating (the ram is the real gate threat)
	var ladder_crews: int = 4 + idx                        # each crew brings two fast carriers and one long ladder
	var archers: int = int(round(float(n) * 0.22))
	var inf: int = n - rams - archers - ladder_crews
	if inf < 0:
		var overflow := -inf
		archers = maxi(0, archers - overflow)
		inf = 0
	for _r in rams: out.append("ram")
	if idx == waves.size() - 1 and rams > 0:
		out[rams - 1] = "bossram"                          # final wave: one ram is the great siege engine
	for _l in ladder_crews: out.append("ladder_crew")
	for _a in archers: out.append("archer")
	for _i in inf: out.append("infantry")
	_shuffle_non_ladders(out)
	return out

func _shuffle_non_ladders(out: Array) -> void:
	var fixed: Array = []
	var loose: Array = []
	for kind in out:
		if kind == "ladder_crew":
			fixed.append(kind)
		else:
			loose.append(kind)
	loose.shuffle()
	out.clear()
	var loose_i := 0
	for j in 2:
		if loose_i < loose.size():
			out.append(loose[loose_i])
			loose_i += 1
	for i in fixed.size():
		out.append("ladder_crew")
		for j in 2:
			if loose_i < loose.size():
				out.append(loose[loose_i])
				loose_i += 1
	while loose_i < loose.size():
		out.append(loose[loose_i])
		loose_i += 1

func _spawn_one(kind: String = "infantry") -> void:
	if kind == "ladder_crew":
		_spawn_ladder_crew()
		return
	var scene: PackedScene = SCENES.get(kind, SCENES["infantry"])
	var e := scene.instantiate()
	var spawn := _next_wide_spawn_point()
	(get_tree().current_scene if get_tree().current_scene else get_parent()).add_child(e)
	e.global_position = _valid_spawn_point(spawn)
	e.set_meta("siege_role", "gate_engine" if kind == "ram" or kind == "bossram" else "wall_assault")
	if kind != "ram" and kind != "bossram" and e.has_method("setup_wall_assault"):
		var assault := _pick_ladder_assault_point()
		e.setup_wall_assault([assault["approach"], assault["foot"]], self)
	else:
		e.setup_path(ROUTE, self, GATE_WP)
	_track_enemy(e)

func _stage_one(kind: String = "infantry") -> Node:
	var scene: PackedScene = SCENES.get(kind, SCENES["infantry"])
	var e := scene.instantiate()
	(get_tree().current_scene if get_tree().current_scene else get_parent()).add_child(e)
	e.global_position = _valid_spawn_point(_next_staging_point())
	e.set_meta("siege_role", "gate_engine" if kind == "ram" or kind == "bossram" else "wall_assault")
	e.set_meta("staged_wave", true)
	e.set_meta("staged_waiting", true)
	_track_enemy(e)
	_staged_orders.append({"unit": e, "kind": kind})
	return e

func _spawn_ladder_crew() -> void:
	var slot := _reserve_ladder_slot()
	var crew_id := _ladder_crew_seq
	_ladder_crew_seq += 1
	var normal := Vector3(-1.0, 0.0, 0.0)
	var fallback_z := spawn_centre.z + (24.0 if crew_id % 2 == 0 else -24.0)
	var foot := Vector3(288.0, _ground(288.0, fallback_z) + 0.15, fallback_z)
	var top := Vector3(294.0, 22.0, fallback_z)
	if slot:
		foot = slot.get_meta("foot", foot)
		top = slot.get_meta("top", top)
		normal = slot.get_meta("normal", normal)
		slot.set_meta("reserved_by", crew_id)
	var side := normal.cross(Vector3.UP).normalized()
	if side.length() < 0.01:
		side = Vector3.FORWARD
	top = _resolved_ladder_landing(top, normal)
	var crew_spawn := _spawn_point_for_ladder_foot(foot, normal)
	for i in LADDER_CARRIERS_PER_CREW:
		var e := LADDER_ORC_SCENE.instantiate()
		var start := crew_spawn + side * (-1.6 if i % 2 == 0 else 1.6) + normal * (1.1 if i < 2 else -1.1)
		(get_tree().current_scene if get_tree().current_scene else get_parent()).add_child(e)
		e.global_position = _valid_spawn_point(start)
		e.add_to_group("ladder_carrier")
		e.set_meta("siege_role", "ladder_carrier")
		e.set_meta("ladder_crew_id", crew_id)
		e.setup_ladder_carry(crew_id, i, foot, top, normal, self, crew_spawn)
		_track_enemy(e)
		await get_tree().process_frame
	await _spawn_ladder_escorts(crew_id, foot, normal, side, crew_spawn)

func _stage_ladder_crew() -> void:
	var slot := _reserve_ladder_slot()
	var crew_id := _ladder_crew_seq
	_ladder_crew_seq += 1
	var normal := Vector3(-1.0, 0.0, 0.0)
	var fallback_z := spawn_centre.z + (24.0 if crew_id % 2 == 0 else -24.0)
	var foot := Vector3(288.0, _ground(288.0, fallback_z) + 0.15, fallback_z)
	var top := Vector3(294.0, 22.0, fallback_z)
	if slot:
		foot = slot.get_meta("foot", foot)
		top = slot.get_meta("top", top)
		normal = slot.get_meta("normal", normal)
		slot.set_meta("reserved_by", crew_id)
	var side := normal.cross(Vector3.UP).normalized()
	if side.length() < 0.01:
		side = Vector3.FORWARD
	top = _resolved_ladder_landing(top, normal)
	var crew_spawn := _spawn_point_for_ladder_foot(foot, normal)
	for i in LADDER_CARRIERS_PER_CREW:
		var e := LADDER_ORC_SCENE.instantiate()
		(get_tree().current_scene if get_tree().current_scene else get_parent()).add_child(e)
		e.global_position = _valid_spawn_point(_next_staging_point())
		e.add_to_group("ladder_carrier")
		e.set_meta("siege_role", "ladder_carrier")
		e.set_meta("ladder_crew_id", crew_id)
		e.set_meta("staged_wave", true)
		e.set_meta("staged_waiting", true)
		e.setup_ladder_carry(crew_id, i, foot, top, normal, self, crew_spawn)
		e.set("path", [])
		e.set("target", e.global_position)
		_track_enemy(e)
		_staged_orders.append({"unit": e, "kind": "ladder_carrier", "crew_id": crew_id, "crew_index": i, "foot": foot, "top": top, "normal": normal, "crew_spawn": crew_spawn})
	for i in LADDER_ESCORTS_PER_CREW:
		var e := SCENES["infantry"].instantiate()
		(get_tree().current_scene if get_tree().current_scene else get_parent()).add_child(e)
		e.global_position = _valid_spawn_point(_next_staging_point())
		var cover_foot := foot + normal * randf_range(3.0, 5.0) + side * float(i - 1) * 2.2
		var approach := crew_spawn + side * float(i - 1) * 2.8
		cover_foot.y = foot.y
		approach.y = foot.y
		e.add_to_group("ladder_escort")
		e.set_meta("siege_role", "ladder_escort")
		e.set_meta("escort_crew_id", crew_id)
		e.set_meta("staged_wave", true)
		e.set_meta("staged_waiting", true)
		_track_enemy(e)
		_staged_orders.append({"unit": e, "kind": "ladder_escort", "approach": approach, "cover_foot": cover_foot})

func _spawn_ladder_escorts(crew_id: int, foot: Vector3, normal: Vector3, side: Vector3, crew_spawn: Vector3) -> void:
	for i in LADDER_ESCORTS_PER_CREW:
		var e := SCENES["infantry"].instantiate()
		var start := crew_spawn + side * float(i - 1) * 2.4 - normal * 3.0
		(get_tree().current_scene if get_tree().current_scene else get_parent()).add_child(e)
		e.global_position = _valid_spawn_point(start)
		if e.has_method("setup_wall_assault"):
			var cover_foot := foot + normal * randf_range(3.0, 5.0) + side * float(i - 1) * 2.2
			var approach := crew_spawn + side * float(i - 1) * 2.8
			cover_foot.y = foot.y
			approach.y = foot.y
			e.setup_wall_assault([approach, cover_foot], self)
		else:
			e.setup_path(ROUTE, self, GATE_WP)
		e.add_to_group("ladder_escort")
		e.set_meta("siege_role", "ladder_escort")
		e.set_meta("escort_crew_id", crew_id)
		_track_enemy(e)
		await get_tree().process_frame

func _reserve_ladder_slot() -> Node3D:
	return _siege_director.reserve_ladder_slot() if _siege_director else null

func _pick_ladder_assault_point() -> Dictionary:
	return _siege_director.pick_ladder_assault_point() if _siege_director else {}

func _next_wide_spawn_point() -> Vector3:
	return _siege_director.next_wide_spawn_point() if _siege_director else spawn_centre + Vector3(randf_range(-spawn_spread.x, spawn_spread.x), 0.0, randf_range(-spawn_spread.z, spawn_spread.z))

func _next_staging_point() -> Vector3:
	var columns := maxi(1, ceili(sqrt(float(maxi(1, _staged_spawn_total))) * 2.2))
	var row := int(_staged_spawn_index / columns)
	var col := _staged_spawn_index % columns
	var t := 0.5 if columns == 1 else float(col) / float(columns - 1)
	var z := spawn_centre.z - staging_width * 0.5 + staging_width * t
	var x := spawn_centre.x - staging_horizon_distance - float(row) * staging_row_gap
	_staged_spawn_index += 1
	var staged := Vector3(x + randf_range(-1.2, 1.2), _ground(x, z) + 0.15, z + randf_range(-1.0, 1.0))
	return _valid_spawn_point(staged)

func _staged_unit_count(kinds: Array) -> int:
	var count := 0
	for kind in kinds:
		count += LADDER_CARRIERS_PER_CREW + LADDER_ESCORTS_PER_CREW if kind == "ladder_crew" else 1
	return count

func _spawn_point_for_ladder_foot(foot: Vector3, normal: Vector3) -> Vector3:
	return _siege_director.spawn_point_for_ladder_foot(foot, normal) if _siege_director else foot

func _resolved_ladder_landing(top: Vector3, normal: Vector3) -> Vector3:
	return _siege_director.resolved_ladder_landing(top, normal) if _siege_director else top

func _crew_lateral_offset(crew_id: int) -> float:
	var pattern := [0.0, -4.0, 4.0, -8.0, 8.0, -12.0, 12.0]
	return pattern[(crew_id - 1) % pattern.size()]

func _ladder_slots(require_free: bool) -> Array[Node3D]:
	return _siege_director.call("_ladder_slots", require_free) if _siege_director else []

func _candidate_ladder_slot_nodes() -> Array:
	var model := get_tree().get_first_node_in_group("castle_model")
	if model != null and model.has_method("wall_ladder_slots"):
		var model_slots: Array = model.call("wall_ladder_slots")
		if not model_slots.is_empty():
			return model_slots
	return get_tree().get_nodes_in_group("castle_ladder_slot")

func _is_ladder_slot_accessible(slot: Node3D) -> bool:
	var foot: Vector3 = slot.get_meta("foot", slot.global_position)
	var normal: Vector3 = slot.get_meta("normal", Vector3(-1.0, 0.0, 0.0))
	normal.y = 0.0
	if normal.length() < 0.01:
		return false
	normal = normal.normalized()
	var to_spawn := spawn_centre - foot
	to_spawn.y = 0.0
	if to_spawn.length() < 0.01:
		return false
	if foot.x > 312.0:
		return false
	if absf(foot.z - spawn_centre.z) < 10.0:
		return false
	if absf(foot.z - spawn_centre.z) > 46.0:
		return false
	var field_base := _ground(spawn_centre.x, spawn_centre.z)
	if foot.y > field_base + 6.0:
		return false
	if _terrain != null:
		var samples := [
			foot,
			foot + normal * 6.0,
			foot + normal * 14.0,
			foot + normal * 24.0,
			_spawn_point_for_ladder_foot(foot, normal),
		]
		for sample in samples:
			if not _has_physics_ground(sample.x, sample.z):
				return false
		var previous_height: float = _terrain.height(samples[0].x, samples[0].z)
		for i in range(1, samples.size()):
			var sample: Vector3 = samples[i]
			var height: float = _terrain.height(sample.x, sample.z)
			if absf(height - previous_height) > 5.0:
				return false
			if height > field_base + 8.0:
				return false
			previous_height = height
	return true

func _on_died(e: Node) -> void:
	_alive.erase(e)

func _track_enemy(e: Node) -> void:
	if e == null:
		return
	if _combat_registry != null and _combat_registry.has_method("register_enemy"):
		_combat_registry.call("register_enemy", e)
		if e.is_in_group("ram") and _combat_registry.has_method("register_ram"):
			_combat_registry.call("register_ram", e)
	if not _alive.has(e):
		_alive.append(e)
	var died_cb := Callable(self, "_on_died")
	if e.has_signal("died") and not e.is_connected("died", died_cb):
		e.connect("died", died_cb)
	var hit_gate_cb := Callable(self, "_on_hit_gate")
	if e.has_signal("hit_gate") and not e.is_connected("hit_gate", hit_gate_cb):
		e.connect("hit_gate", hit_gate_cb)
	var hit_keep_cb := Callable(self, "_on_hit_keep")
	if e.has_signal("hit_keep") and not e.is_connected("hit_keep", hit_keep_cb):
		e.connect("hit_keep", hit_keep_cb)
	e.tree_exiting.connect(_on_enemy_tree_exiting.bind(e), CONNECT_ONE_SHOT)

func _on_enemy_tree_exiting(e: Node) -> void:
	_alive.erase(e)
	if _combat_registry != null and _combat_registry.has_method("unregister_enemy"):
		_combat_registry.call("unregister_enemy", e)

func _prune_alive() -> void:
	for i in range(_alive.size() - 1, -1, -1):
		var candidate: Variant = _alive[i]
		if _should_prune_alive(candidate):
			_alive.remove_at(i)

func _should_prune_alive(candidate: Variant) -> bool:
	if not is_instance_valid(candidate):
		return true
	if not candidate is Node:
		return true
	var enemy := candidate as Node
	if enemy.is_queued_for_deletion() or not enemy.is_inside_tree():
		return true
	if enemy.has_method("is_active_enemy") and not bool(enemy.call("is_active_enemy")):
		return true
	if enemy is Node3D:
		var pos := (enemy as Node3D).global_position
		if pos.y < -20.0 or pos.y > 120.0:
			return true
	return false

func _on_hit_gate(amount: float) -> void:
	_gate_hp = maxf(0.0, _gate_hp - amount)

func _on_hit_keep(amount: float) -> void:
	_keep_hp = maxf(0.0, _keep_hp - amount)
