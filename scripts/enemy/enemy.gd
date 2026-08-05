class_name Enemy
extends CharacterBody3D

## Base besieger. Marches a waypoint route (field -> gate -> bailey -> causeway -> inner gate -> keep),
## marches to the gate while it stands, then storms through to the keep. HP + attack cadence live in
## components. Subclasses (InfantryEnemy / ArcherEnemy / RamEnemy) supply their own body, stats and
## attack behaviour by overriding the hooks: _tune(), _build_visual(), _collision_shape()/_offset(),
## _can_attack_gate(), _at_gate(), _on_attacked(). Enemies are layer 2 (arrows hunt them) and keep personal space.

signal died(enemy: Node)
signal hit_gate(amount: float)
signal hit_keep(amount: float)

const CollisionLayers := preload("res://scripts/core/collision_layers.gd")
const TraversalControllerScript := preload("res://scripts/core/traversal_controller.gd")
const UnitLocomotionScript := preload("res://scripts/core/unit_locomotion.gd")
const WallAssaultBrainScript := preload("res://scripts/enemy/wall_assault_brain.gd")
const LadderAssaultBrainScript := preload("res://scripts/enemy/ladder_assault_brain.gd")

@export var speed: float = 2.3
@export var max_hp: float = 100.0
@export var gravity: float = 20.0
@export var attack_range: float = 6.0
@export var step_height: float = 0.6
@export var attack_damage: float = 6.0
@export var attack_interval: float = 1.3
@export var stats: UnitStats = preload("res://data/enemy_infantry.tres")   # designer-tunable preset

var type_id: StringName = &"enemy"
var display_name: String = "Enemy"
var faction: int = UnitStats.Faction.ENEMY
var role: int = UnitStats.Role.INFANTRY
var level: int = 1
var xp_value: int = 0
var kill_value: int = 1
var kills: int = 0
var defense: float = 0.0
var armor: float = 0.0
var armor_type: StringName = &"none"
var target: Vector3 = Vector3.ZERO
var path: Array = []                               # waypoints: [muster, gate, through, causeway, inner gate, keep]
var siege: Node = null                             # WaveSpawner — asked whether the gate is breached
var gate_wp: int = 0                               # which waypoint IS the gate (closed-gate behaviour there)
var _gate_offset: Vector3 = Vector3.ZERO           # per-enemy lateral fan so they spread across the gate face
var _wp: int = 0
var _atk_what: String = ""                         # "gate" or "keep" — what the current hammering damages
var hp: float:                                     # facade over the health component
	get:
		return _health.hp if _health else 0.0
var _health: HealthComponent
var _attack_comp: AttackComponent
var _done: bool = false
var _attacking: bool = false
var _wall_assault: bool = false
var _on_wall: bool = false
var _climbing_ladder: bool = false
var _climb_t: float = 0.0
var _climb_from: Vector3 = Vector3.ZERO
var _climb_to: Vector3 = Vector3.ZERO
var _ladder_target: Node = null
var _traversal: Node = null
var _locomotion: Node = null
var _wall_brain: Node = null
var _ladder_brain: Node = null
var _unit_attack_target: Node3D = null
var _cached_wall_defender: Node3D = null
var _wall_defender_refresh_t: float = 0.0
var _cached_wall_pressure_point: Vector3 = Vector3.INF
var _wall_pressure_refresh_t: float = 0.0
var _cached_active_ladder: Node = null
var _ladder_search_t: float = 0.0
var _mats: Array = []
var _bases: Array = []
var _flash: float = 0.0
var _stuck_time: float = 0.0
var _stuck_side: float = 1.0
var _unstick_dir: Vector3 = Vector3.ZERO
var _unstick_time: float = 0.0
var _avoidance_cache: Vector3 = Vector3.ZERO
var _avoidance_cache_t: float = 0.0
var _recovery_count: int = 0
var _stuck_recovery_count: int = 0

const UNIT_PERSONAL_SPACE := 0.95
const UNIT_AVOIDANCE_WEIGHT := 0.85
const STUCK_RECOVERY_SECONDS := 1.6
const AVOIDANCE_REFRESH := 0.32
const SEPARATION_MAX_NEIGHBORS := 5
const SEPARATION_SCAN_LIMIT := 24
const WALL_TARGET_RANGE := 90.0
const WALL_REPATH_INTERVAL := 0.75
const WALL_TARGET_REFRESH := 0.42
const WALL_PRESSURE_REFRESH := 0.7
const LADDER_SEARCH_REFRESH := 0.55
const WALL_WAYPOINT_REACHED := 1.15
const WALL_MAX_DIRECT_HEIGHT_DELTA := 3.2
const WALL_ROUTED_HEIGHT_DELTA := 18.0
const LADDER_ENTRY_REACHED := 0.95
const WALL_SETTLE_REACHED := 0.75
const WALL_SETTLE_TIMEOUT := 2.6
const WALL_SAFE_STEP_DROP := 2.6
const SKY_RECOVERY_Y := 80.0

var _wall_target: Node3D = null
var _wall_objective_target := Vector3.INF
var _wall_nav_path: Array[Vector3] = []
var _wall_nav_index: int = 0
var _wall_repath_t: float = 0.0
var _wall_settle_goal := Vector3.INF
var _wall_settle_t := 0.0

func _ready() -> void:
	_apply_stats()
	_tune()                                # per-type overrides (after the preset, before components read the values)
	_health = HealthComponent.new()
	_health.setup(max_hp, defense, armor)
	add_child(_health)
	_health.died.connect(_die)
	_attack_comp = AttackComponent.new()
	_attack_comp.damage = attack_damage
	_attack_comp.interval = attack_interval
	add_child(_attack_comp)
	_attack_comp.attacked.connect(_on_attacked)
	collision_layer = CollisionLayers.ENEMY
	collision_mask = CollisionLayers.ACTOR_MASK
	floor_max_angle = deg_to_rad(75.0)     # the causeway pitches to ~58 deg near the top — allow steep climbs
	floor_snap_length = 0.6                # stick to the causeway ramp like the player, so it climbs smoothly
	floor_constant_speed = true
	add_to_group("enemy")
	_setup_locomotion()
	_setup_traversal_controller()
	_setup_wall_assault_brain()
	_setup_ladder_assault_brain()
	_build_body()

func _setup_locomotion() -> void:
	_locomotion = UnitLocomotionScript.new()
	_locomotion.name = "UnitLocomotion"
	add_child(_locomotion)
	_locomotion.setup(self)

func _setup_traversal_controller() -> void:
	_traversal = TraversalControllerScript.new()
	_traversal.name = "TraversalController"
	add_child(_traversal)
	_traversal.setup(self)
	_traversal.completed.connect(_on_traversal_completed)
	_traversal.failed.connect(_on_traversal_failed)

func _setup_wall_assault_brain() -> void:
	_wall_brain = WallAssaultBrainScript.new()
	_wall_brain.name = "WallAssaultBrain"
	add_child(_wall_brain)

func _setup_ladder_assault_brain() -> void:
	_ladder_brain = LadderAssaultBrainScript.new()
	_ladder_brain.name = "LadderAssaultBrain"
	add_child(_ladder_brain)

func _apply_stats() -> void:
	if stats == null:
		return
	type_id = stats.type_id
	display_name = stats.display_name
	faction = stats.faction
	role = stats.role
	level = stats.level
	xp_value = stats.xp_value
	kill_value = stats.kill_value
	kills = stats.kills
	max_hp = stats.max_hp
	defense = stats.defense
	armor = stats.armor
	armor_type = stats.armor_type
	speed = stats.speed
	gravity = stats.gravity
	step_height = stats.step_height
	attack_range = stats.attack_range
	attack_damage = stats.melee_attack_damage
	attack_interval = stats.attack_interval

# ---- hooks a subclass overrides ---------------------------------------------------------------
func _tune() -> void:
	pass

func _collision_shape() -> Shape3D:
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.7
	return cap

func _collision_offset() -> Vector3:
	return Vector3(0, 0.9, 0)

func _build_visual() -> Dictionary:
	return Soldier.build(self, Color(0.55, 0.13, 0.12), false)   # default: dark-red spearman

# at the gate waypoint: returns true if the enemy handled it (attacked/idled/advanced) this frame
func _at_gate(delta: float, dist: float) -> bool:
	var open := _gate_open()
	if not open:
		if dist <= attack_range:
			if _can_attack_gate():
				_attack(delta, "gate")
			elif _try_use_active_ladder(delta):
				pass
			else:
				_idle(delta)
			return true
	elif dist <= attack_range:
		_wp += 1                                   # gate breached -> storm through
		return true
	return false

func _can_attack_gate() -> bool:
	return false

func _at_wall_assault(delta: float, dist: float) -> bool:
	if _try_use_active_ladder(delta):
		return true
	if dist <= attack_range:
		_idle(delta)
		return true
	return false

func _try_use_active_ladder(delta: float) -> bool:
	var ladder := _best_active_ladder()
	if ladder == null:
		return false
	_ladder_target = ladder
	var foot: Vector3 = ladder.get("foot")
	var top: Vector3 = ladder.get("top")
	var climb_speed: float = float(ladder.get("climb_speed"))
	if _approach_ladder_entry_or_climb(ladder, foot, top, climb_speed, delta):
		return true
	_idle(delta)
	return true

func _approach_ladder_entry_or_climb(ladder: Node, foot: Vector3, top: Vector3, climb_speed: float, delta: float) -> bool:
	if ladder == null or not is_instance_valid(ladder):
		return false
	var entry: Vector3 = _ladder_brain.call("entry_point", ladder, self) if _ladder_brain != null and _ladder_brain.has_method("entry_point") else (ladder.call("entry_point_for_unit", self) if ladder.has_method("entry_point_for_unit") else foot)
	var to_entry := entry - global_position
	to_entry.y = 0.0
	var entry_dist := to_entry.length()
	if entry_dist > LADDER_ENTRY_REACHED:
		var dir := _avoidance_direction(to_entry / maxf(entry_dist, 0.001))
		_move_direction(dir, delta)
		return true
	if _ladder_brain != null and _ladder_brain.has_method("reserve_entry"):
		if not bool(_ladder_brain.call("reserve_entry", ladder, self)):
			_cached_active_ladder = null
			_ladder_search_t = 0.0
			return false
	elif ladder.has_method("reserve_entry") and not bool(ladder.call("reserve_entry", self)):
		_cached_active_ladder = null
		_ladder_search_t = 0.0
		return false
	if bool(_ladder_brain.call("reserve_or_queue", ladder, self) if _ladder_brain != null else ladder.call("reserve_climb", self)):
		if _start_ladder_traversal(ladder, foot, top, climb_speed):
			return true
		if ladder.has_method("release_climb"):
			ladder.call("release_climb", self)
	if ladder.has_method("release_entry"):
		ladder.call("release_entry", self)
	return false

func _best_active_ladder() -> Node:
	_ladder_search_t = maxf(0.0, _ladder_search_t - get_physics_process_delta_time())
	if _cached_active_ladder != null and is_instance_valid(_cached_active_ladder) and _ladder_search_t > 0.0:
		if not (_cached_active_ladder.has_method("is_deployed") and not bool(_cached_active_ladder.call("is_deployed"))):
			return _cached_active_ladder
	_cached_active_ladder = null
	_ladder_search_t = LADDER_SEARCH_REFRESH + randf_range(0.0, 0.16)
	if _ladder_brain != null and _ladder_brain.has_method("choose_active_ladder"):
		var selected: Node = _ladder_brain.call("choose_active_ladder", self, self)
		if selected != null:
			_cached_active_ladder = selected
			return selected
	var best: Node = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group("siege_ladder_active"):
		if not is_instance_valid(node) or not node is SiegeLadder:
			continue
		var active_ladder: SiegeLadder = node as SiegeLadder
		var foot_point: Vector3 = active_ladder.get("foot") if active_ladder.get("foot") != null else active_ladder.global_position
		var score := global_position.distance_squared_to(foot_point)
		score += float(active_ladder.active_climber_count()) * 160.0
		if score < best_score:
			best_score = score
			best = active_ladder
	_cached_active_ladder = best
	return best

func _continue_ladder_climb(delta: float) -> void:
	if _traversal != null and _traversal.is_active():
		_traversal.physics_tick(delta)
	else:
		_climbing_ladder = false

func _start_ladder_traversal(ladder: Node, foot: Vector3, top: Vector3, climb_speed: float) -> bool:
	if _traversal == null:
		return false
	var climb_foot := foot
	var climb_top := top
	if ladder != null and is_instance_valid(ladder) and ladder.has_method("climb_points_for_unit"):
		var points: Dictionary = ladder.call("climb_points_for_unit", self)
		climb_foot = points.get("foot", climb_foot)
		climb_top = points.get("top", climb_top)
	if not _traversal.start_ladder(ladder, climb_foot, climb_top, climb_speed):
		return false
	_ladder_target = ladder
	if ladder != null and is_instance_valid(ladder) and ladder.has_method("landing_settle_point_for_unit"):
		_wall_settle_goal = ladder.call("landing_settle_point_for_unit", self)
		_wall_settle_goal = _safe_wall_point(_wall_settle_goal, top)
		_wall_settle_t = WALL_SETTLE_TIMEOUT
	_climbing_ladder = true
	_climb_t = 0.0
	_climb_from = foot
	_climb_to = top
	velocity = Vector3.ZERO
	return true

func _on_traversal_completed(kind: StringName, landing: Vector3) -> void:
	if kind != &"ladder":
		return
	_climbing_ladder = false
	_ladder_target = null
	_on_wall = true
	path = [landing]
	_wp = 0

func _on_traversal_failed(kind: StringName, _reason: String) -> void:
	if kind != &"ladder":
		return
	_climbing_ladder = false
	_ladder_target = null

func _fight_on_wall(delta: float) -> void:
	if _try_settle_after_ladder(delta):
		return
	_wall_defender_refresh_t = maxf(0.0, _wall_defender_refresh_t - delta)
	var defender := _nearest_wall_defender()
	if defender:
		if global_position.distance_to(defender.global_position) <= attack_range:
			_attack_unit(delta, defender)
			return
		_move_towards_wall_point(defender.global_position, delta)
		return
	if _move_to_wall_pressure(delta):
		return
	_idle(delta)

func _try_settle_after_ladder(delta: float) -> bool:
	if _wall_settle_goal == Vector3.INF:
		return false
	_wall_settle_t = maxf(0.0, _wall_settle_t - delta)
	var flat := _wall_settle_goal - global_position
	flat.y = 0.0
	if flat.length() <= WALL_SETTLE_REACHED or _wall_settle_t <= 0.0:
		_wall_settle_goal = Vector3.INF
		_wall_settle_t = 0.0
		return false
	_move_towards_wall_point(_wall_settle_goal, delta)
	return true

func _nearest_wall_defender() -> Node3D:
	if _cached_wall_defender != null and is_instance_valid(_cached_wall_defender) and _wall_defender_refresh_t > 0.0:
		var cached_delta := _cached_wall_defender.global_position - global_position
		if Vector2(cached_delta.x, cached_delta.z).length_squared() <= WALL_TARGET_RANGE * WALL_TARGET_RANGE and absf(cached_delta.y) <= WALL_ROUTED_HEIGHT_DELTA:
			return _cached_wall_defender
	_cached_wall_defender = null
	_wall_defender_refresh_t = WALL_TARGET_REFRESH + randf_range(0.0, 0.18)
	var best: Node3D = null
	var best_score := INF
	var candidates := _nearby_wall_defenders()
	for c in candidates:
		if c is Node3D and is_instance_valid(c):
			var defender := c as Node3D
			var height_delta := absf(defender.global_position.y - global_position.y)
			if height_delta > WALL_MAX_DIRECT_HEIGHT_DELTA:
				continue
			var d := global_position.distance_squared_to(defender.global_position)
			if d > WALL_TARGET_RANGE * WALL_TARGET_RANGE:
				continue
			var score := d
			if defender.global_position.y > global_position.y + 2.0:
				score *= 0.55
			if score < best_score:
				best_score = score
				best = defender
	if best != null:
		_cached_wall_defender = best
		return best
	var player := _active_player()
	if player is Node3D and is_instance_valid(player):
		var player_3d := player as Node3D
		var same_level := absf(player_3d.global_position.y - global_position.y) <= 4.0
		if same_level or global_position.distance_to(player_3d.global_position) <= attack_range * 1.4:
			_cached_wall_defender = player_3d
			return player_3d
	return best

func _nearby_wall_defenders() -> Array:
	var registry := _combat_registry()
	if registry != null and registry.has_method("active_allies_near"):
		return registry.call("active_allies_near", global_position, WALL_TARGET_RANGE)
	return _active_allies()

func _nearest_defender() -> Node3D:
	var best: Node3D = null
	var bestd := 20.0 * 20.0
	var candidates := _active_allies()
	var player := _active_player()
	if player:
		candidates.append(player)
	for c in candidates:
		if c is Node3D and is_instance_valid(c):
			var d := global_position.distance_squared_to((c as Node3D).global_position)
			if d < bestd:
				bestd = d
				best = c
	return best

func _move_to_wall_defender(delta: float, defender: Node3D) -> bool:
	if defender == null or not is_instance_valid(defender):
		return false
	if _wall_target != defender or _wall_nav_path.is_empty():
		_wall_target = defender
		_wall_nav_path = []
		if _wall_brain != null and _wall_brain.has_method("route_to"):
			_wall_nav_path = _wall_brain.call("route_to", self, global_position, defender.global_position)
		if _wall_nav_path.is_empty():
			if absf(defender.global_position.y - global_position.y) > WALL_MAX_DIRECT_HEIGHT_DELTA:
				return false
			_wall_nav_path = [defender.global_position]
		_wall_nav_index = 0
		_wall_repath_t = WALL_REPATH_INTERVAL
	var desired := _wall_nav_path[mini(_wall_nav_index, _wall_nav_path.size() - 1)]
	if global_position.distance_to(desired) <= WALL_WAYPOINT_REACHED and _wall_nav_index < _wall_nav_path.size() - 1:
		_wall_nav_index += 1
		desired = _wall_nav_path[_wall_nav_index]
	return _move_towards_wall_point(desired, delta)

func _move_to_wall_pressure(delta: float) -> bool:
	var pressure := _wall_pressure_point()
	if pressure == Vector3.INF:
		return false
	if global_position.distance_squared_to(pressure) <= 0.36 and absf(pressure.y - global_position.y) <= 0.8:
		return false
	if absf(pressure.y - global_position.y) <= WALL_MAX_DIRECT_HEIGHT_DELTA:
		_wall_target = null
		_wall_objective_target = pressure
		_wall_nav_path.clear()
		return _move_towards_wall_point(pressure, delta)
	_wall_repath_t = maxf(0.0, _wall_repath_t - delta)
	if _wall_objective_target.distance_squared_to(pressure) > 1.0 or _wall_nav_path.is_empty() or _wall_repath_t <= 0.0:
		_wall_target = null
		_wall_objective_target = pressure
		_wall_nav_path = []
		if _wall_brain != null and _wall_brain.has_method("route_to"):
			_wall_nav_path = _wall_brain.call("route_to", self, global_position, pressure)
		if _wall_nav_path.is_empty():
			return false
		_wall_nav_index = 0
		_wall_repath_t = WALL_REPATH_INTERVAL * 2.0 + randf_range(0.0, 0.35)
	var desired := _wall_nav_path[mini(_wall_nav_index, _wall_nav_path.size() - 1)]
	if global_position.distance_to(desired) <= WALL_WAYPOINT_REACHED and _wall_nav_index < _wall_nav_path.size() - 1:
		_wall_nav_index += 1
		desired = _wall_nav_path[_wall_nav_index]
	return _move_towards_wall_point(desired, delta)

func _wall_pressure_point() -> Vector3:
	if _cached_wall_pressure_point != Vector3.INF and _wall_pressure_refresh_t > 0.0:
		return _cached_wall_pressure_point
	_wall_pressure_refresh_t = WALL_PRESSURE_REFRESH + randf_range(0.0, 0.25)
	if _wall_brain != null and _wall_brain.has_method("pressure_point"):
		_cached_wall_pressure_point = _wall_brain.pressure_point(self, self)
		return _cached_wall_pressure_point
	_cached_wall_pressure_point = global_position
	return _cached_wall_pressure_point

func _move_towards_wall_point(desired: Vector3, delta: float) -> bool:
	var flat := desired - global_position
	flat.y = 0.0
	var dist := flat.length()
	if dist <= 0.25 and absf(desired.y - global_position.y) > WALL_MAX_DIRECT_HEIGHT_DELTA:
		var vertical_delta := desired.y - global_position.y
		if absf(vertical_delta) <= WALL_ROUTED_HEIGHT_DELTA:
			velocity = Vector3.ZERO
			global_position.y = move_toward(global_position.y, desired.y, maxf(1.8, speed) * delta)
			return true
		velocity = Vector3.ZERO
		return false
	if dist < 0.05:
		velocity = Vector3.ZERO
		return true
	var dir := _avoidance_direction(flat / maxf(dist, 0.001))
	if not _has_wall_floor_ahead(dir):
		velocity = Vector3.ZERO
		return false
	var pre := global_position
	_move_direction(dir, delta)
	_update_stuck_recovery(delta, pre, dir)
	return global_position.distance_squared_to(pre) > 0.0001

func _has_wall_floor_ahead(dir: Vector3) -> bool:
	if dir.length() < 0.01:
		return true
	var step := global_position + dir.normalized() * maxf(0.55, speed * get_physics_process_delta_time() * 1.5)
	var from := step + Vector3.UP * 1.4
	var to := step - Vector3.UP * WALL_SAFE_STEP_DROP
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = CollisionLayers.WORLD
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return false
	var hit_pos: Vector3 = hit.position
	return absf(hit_pos.y - global_position.y) <= WALL_SAFE_STEP_DROP

func _safe_wall_point(desired: Vector3, fallback: Vector3) -> Vector3:
	var candidates := [
		desired,
		fallback,
		desired.lerp(fallback, 0.5),
		global_position,
	]
	for candidate: Vector3 in candidates:
		var from: Vector3 = candidate + Vector3.UP * 2.0
		var to: Vector3 = candidate - Vector3.UP * WALL_SAFE_STEP_DROP
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.collision_mask = CollisionLayers.WORLD
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			var hit_pos: Vector3 = hit.position
			return hit_pos + Vector3.UP * 0.08
	return fallback

func _attack_unit(delta: float, defender: Node3D) -> void:
	_atk_what = "unit"
	_unit_attack_target = defender
	_idle(delta)
	if _attack_comp == null:
		return
	_attack_comp.tick(delta)

func _on_attacked(damage: float) -> void:
	if _atk_what == "unit" and _unit_attack_target and is_instance_valid(_unit_attack_target) and _unit_attack_target.has_method("take_damage"):
		_unit_attack_target.take_damage(damage, global_position)
	elif _atk_what == "keep":
		hit_keep.emit(damage)
	elif _atk_what == "gate":
		hit_gate.emit(damage)
	var au := get_node_or_null("/root/Audio")
	if au:
		au.play_3d("gate_impact", global_position)
# -----------------------------------------------------------------------------------------------

func _gate_open() -> bool:
	return siege != null and siege.has_method("gate_open") and siege.gate_open()

func is_active_enemy() -> bool:
	return not _done and is_inside_tree() and visible and global_position.y > FALL_FLOOR

func setup(goal: Vector3) -> void:
	target = goal
	path = [goal]

# full siege route: hammer the gate, then (once breached) push through to the keep and hammer it
func setup_path(points: Array, siege_ref: Node, gate_index: int = 0) -> void:
	path = points.duplicate()
	siege = siege_ref
	gate_wp = gate_index
	_wall_assault = false
	_wp = 0
	target = path[0]
	_gate_offset = Vector3(0, 0, randf_range(-1.3, 1.3))   # fan across the gate face (< passage half-width)

func setup_wall_assault(points: Array, siege_ref: Node) -> void:
	path = points.duplicate()
	siege = siege_ref
	gate_wp = -1
	_wall_assault = true
	_wp = 0
	target = path[0] if not path.is_empty() else global_position
	_gate_offset = Vector3.ZERO

func _build_body() -> void:
	var col := CollisionShape3D.new()
	col.shape = _collision_shape()
	col.position = _collision_offset()
	add_child(col)
	var r := _build_visual()
	_mats = r["mats"]
	_bases = r["bases"]

func take_damage(amount: float) -> void:
	if _done or _health == null:
		return
	if bool(get_meta("staged_waiting", false)):
		for spawner in get_tree().get_nodes_in_group("wave_spawner"):
			if spawner.has_method("start_assault"):
				spawner.call("start_assault")
	_health.take_damage(amount)
	_flash = 0.12
	for m in _mats:
		m.albedo_color = Color(1, 1, 1)

# damage with the hit height, so a well-aimed shot at the weak spot does double (rewards aiming).
# humanoids: headshot; ram: the exposed crew/beam UNDER the armoured roof (overridden in ram_enemy).
func take_damage_at(amount: float, hit_y: float) -> void:
	if _is_weak_hit(hit_y):
		amount *= 2.0
	take_damage(amount)

func _is_weak_hit(hit_y: float) -> bool:
	return hit_y > global_position.y + 1.35        # head region of the ~1.7 m body

# HealthComponent.died -> die: topple over + sink, then free (instead of vanishing instantly)
func _die() -> void:
	var au := get_node_or_null("/root/Audio")
	if au:
		au.play_3d("enemy_death", global_position)
	if _ladder_target and is_instance_valid(_ladder_target) and _ladder_target.has_method("release_climb"):
		_ladder_target.call("release_climb", self)
	if _traversal != null and _traversal.has_method("is_active") and bool(_traversal.call("is_active")):
		_traversal.call("cancel", "unit_died")
	_ladder_target = null
	_climbing_ladder = false
	_done = true
	remove_from_group("enemy")          # allies/targeting stop aiming at the corpse
	collision_layer = 0                 # arrows pass through the falling body
	set_physics_process(false)
	died.emit(self)                     # spawner decrements alive immediately
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "rotation:z", rotation.z + PI * 0.55, 0.5).set_ease(Tween.EASE_IN)
	t.tween_property(self, "position:y", position.y - 0.5, 0.7)
	t.set_parallel(false)
	t.tween_interval(0.5)
	t.tween_callback(queue_free)

const FALL_FLOOR := -8.0       # all legit ground is y15+; only a true through-the-world faller reaches this

func _physics_process(delta: float) -> void:
	if _done:
		return
	if global_position.y < FALL_FLOOR:
		_recover_to_ground()
		return
	if global_position.y > SKY_RECOVERY_Y:
		_recover_to_ground()
		return
	if _is_buried_under_terrain():
		_recover_to_ground()
		return
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			for i in _mats.size():
				_mats[i].albedo_color = _bases[i]
	if _climbing_ladder:
		_continue_ladder_climb(delta)
		return
	if _on_wall:
		_fight_on_wall(delta)
		return
	if path.is_empty():
		return
	var last := path.size() - 1
	var tgt: Vector3 = path[mini(_wp, last)]
	if _wp == gate_wp and not _gate_open():
		tgt += _gate_offset                                   # fan across the CLOSED gate face; once breached, dead-centre to funnel through the passage
	var to := tgt - global_position
	to.y = 0.0
	var dist := to.length()
	_attacking = false
	if _wp >= last and _wall_assault:
		if _at_wall_assault(delta, dist):
			return
	elif _wp >= last:                                           # KEEP (terminal): march up then hammer it
		if dist <= attack_range:
			_attack(delta, "keep")
			return
	elif _wp == gate_wp:                                      # GATE waypoint — per-type behaviour
		if _at_gate(delta, dist):
			return
	else:                                                     # intermediate (muster/through/causeway): advance when close
		if dist <= 2.5:
			_wp += 1
			return
	if dist < 0.001:
		return
	var dir := _avoidance_direction(to / dist)
	if _unstick_time > 0.0:
		_unstick_time = maxf(0.0, _unstick_time - delta)
		dir = (dir + _unstick_dir * 0.75).normalized()
	var pre := global_position
	_move_direction(dir, delta)
	_update_stuck_recovery(delta, pre, dir)
	if is_on_floor() and not _wall_assault:
		var moved := global_position - pre
		moved.y = 0.0
		if moved.length() < speed * delta * 0.8:
			# stuck against a step/ledge (gate + inner-gate thresholds): climb by the smallest lift that
			# clears it, like the player controller, so the besieger follows the same route
			for lift in [0.2, 0.35, 0.5, step_height, 1.1]:
				var up_t := global_transform
				up_t.origin += Vector3.UP * lift
				if not test_move(up_t, dir * 0.5):
					global_position += Vector3.UP * lift + dir * 0.5
					break

func _update_stuck_recovery(delta: float, pre: Vector3, dir: Vector3) -> void:
	var moved := global_position - pre
	moved.y = 0.0
	if moved.length() >= 0.08:
		_stuck_time = 0.0
		return
	_stuck_time += delta
	if _stuck_time < STUCK_RECOVERY_SECONDS:
		return
	_stuck_recovery_count += 1
	_unstick_forward(dir)
	_stuck_time = 0.0

func _unstick_forward(dir: Vector3) -> void:
	if dir.length() < 0.01:
		return
	var forward: Vector3 = dir.normalized()
	var side: Vector3 = Vector3(-forward.z, 0.0, forward.x) * _stuck_side
	_stuck_side *= -1.0
	_unstick_dir = (forward + side * 1.35).normalized()
	_unstick_time = 1.0
	if _wall_assault and _wp < path.size() - 1:
		_wp += 1

func _is_buried_under_terrain() -> bool:
	if siege == null or not siege.has_method("terrain_height"):
		return false
	var terrain_y: float = siege.terrain_height(global_position.x, global_position.z)
	return global_position.y < terrain_y - 1.5

func _safe_ground_y(point: Vector3) -> float:
	if siege != null and siege.has_method("terrain_height"):
		return siege.terrain_height(point.x, point.z)
	return 16.5

func _avoidance_direction(desired_dir: Vector3) -> Vector3:
	_avoidance_cache_t -= get_physics_process_delta_time()
	if _avoidance_cache_t <= 0.0:
		_avoidance_cache = _unit_separation_vector(global_position)
		_avoidance_cache_t = AVOIDANCE_REFRESH + randf() * 0.08
	var push := _avoidance_cache
	if push.length() < 0.001:
		return desired_dir
	var adjusted := desired_dir + push.normalized() * UNIT_AVOIDANCE_WEIGHT
	adjusted.y = 0.0
	return adjusted.normalized() if adjusted.length() > 0.001 else desired_dir

func _unit_separation_vector(from: Vector3) -> Vector3:
	var push := Vector3.ZERO
	var checked := 0
	var personal_space_sq := UNIT_PERSONAL_SPACE * UNIT_PERSONAL_SPACE
	var units := _active_units_for_separation()
	if units.is_empty():
		return push
	var start: int = abs(get_instance_id()) % units.size()
	var scan_count: int = mini(units.size(), SEPARATION_SCAN_LIMIT)
	for i in scan_count:
		var node: Variant = units[(start + i) % units.size()]
		if node == self or not node is Node3D or not is_instance_valid(node):
			continue
		var other := node as Node3D
		if absf(other.global_position.y - from.y) > 2.4:
			continue
		var away := from - other.global_position
		away.y = 0.0
		var dist_sq := away.length_squared()
		if dist_sq < 0.000001 or dist_sq >= personal_space_sq:
			continue
		var dist := sqrt(dist_sq)
		push += away.normalized() * ((UNIT_PERSONAL_SPACE - dist) / UNIT_PERSONAL_SPACE)
		checked += 1
		if checked >= SEPARATION_MAX_NEIGHBORS:
			break
	return push

func _active_units_for_separation() -> Array:
	var registry := _combat_registry()
	if registry != null and registry.has_method("active_units_near"):
		return registry.call("active_units_near", global_position, UNIT_PERSONAL_SPACE * 3.0, true, true, true)
	var units := _active_enemies()
	units.append_array(_active_allies())
	var player := _active_player()
	if player != null:
		units.append(player)
	return units

# stand and let the AttackComponent pace the hammering (keeps taking arrows until killed)
func _attack(delta: float, what: String) -> void:
	_attacking = true
	_atk_what = what
	_idle(delta)
	_attack_comp.tick(delta)

func _idle(delta: float) -> void:
	if _locomotion != null and _locomotion.has_method("idle"):
		_locomotion.call("idle", gravity, delta)
	else:
		velocity = Vector3.ZERO
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()

func _move_direction(direction: Vector3, delta: float) -> Dictionary:
	if _locomotion != null and _locomotion.has_method("move_direction"):
		return _locomotion.call("move_direction", direction, speed, gravity, delta, true)
	var flat_dir := direction
	flat_dir.y = 0.0
	if flat_dir.length() > 0.001:
		flat_dir = flat_dir.normalized()
	velocity.x = flat_dir.x * speed
	velocity.z = flat_dir.z * speed
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = -1.0
	else:
		velocity.y -= gravity * delta
	var pre := global_position
	move_and_slide()
	rotation.y = atan2(flat_dir.x, flat_dir.z)
	return {"pre": pre, "post": global_position, "moved": global_position - pre}

# fell through a collision seam -> raycast the real ground under our XZ and snap back onto it
func _recover_to_ground() -> void:
	_recovery_count += 1
	velocity = Vector3.ZERO
	var from := Vector3(global_position.x, 60.0, global_position.z)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -120.0, 0))
	q.collision_mask = CollisionLayers.WORLD
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		global_position = (hit.position as Vector3) + Vector3.UP * 1.0
	else:
		global_position = Vector3(global_position.x, _safe_ground_y(global_position) + 1.0, global_position.z)

func recovery_count() -> int:
	return _recovery_count

func stuck_recovery_count() -> int:
	return _stuck_recovery_count

func wall_assault_debug_summary() -> String:
	var base: String = _wall_brain.debug_summary() if _wall_brain != null and _wall_brain.has_method("debug_summary") else "no_brain"
	if _wall_settle_goal != Vector3.INF:
		return "settle %s" % base
	return base

func ladder_assault_debug_summary() -> String:
	return _ladder_brain.debug_summary() if _ladder_brain != null and _ladder_brain.has_method("debug_summary") else "no_brain"

func collision_debug_snapshot() -> Dictionary:
	return {
		"layer": collision_layer,
		"mask": collision_mask,
		"shapes": _collision_shape_count(),
		"floor": is_on_floor(),
	}

func _collision_shape_count() -> int:
	var count := 0
	for child in get_children():
		if child is CollisionShape3D and not (child as CollisionShape3D).disabled:
			count += 1
	return count

func _active_allies() -> Array:
	var registry := _combat_registry()
	if registry != null and registry.has_method("active_allies"):
		return registry.call("active_allies")
	return get_tree().get_nodes_in_group("ally")

func _active_enemies() -> Array:
	var registry := _combat_registry()
	if registry != null and registry.has_method("active_enemies"):
		return registry.call("active_enemies")
	return get_tree().get_nodes_in_group("enemy")

func _active_player() -> Node:
	var registry := _combat_registry()
	if registry != null and registry.has_method("player"):
		return registry.call("player")
	return get_tree().get_first_node_in_group("player")

func _combat_registry() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("combat_registry")
