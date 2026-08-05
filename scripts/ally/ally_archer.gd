class_name AllyArcher
extends CharacterBody3D

## A friendly archer standing on the rampart. Auto-acquires the nearest besieger in range and
## looses ballistic arrows at it (lead + gravity drop compensation), on a cooldown. Uses
## CharacterBody3D movement so defenders collide with the castle instead of being teleported.
## Draws a simple blue proxy figure — no authored art yet.

const CollisionLayers := preload("res://scripts/core/collision_layers.gd")
const UnitLocomotionScript := preload("res://scripts/core/unit_locomotion.gd")
const DefenderPositioningScript := preload("res://scripts/ally/defender_positioning.gd")
const ArcherShootingScript := preload("res://scripts/ally/archer_shooting.gd")
const DefenderTargetingScript := preload("res://scripts/ally/defender_targeting.gd")
const CastlePathfinderScript := preload("res://scripts/castle/castle_pathfinder.gd")
const GATE_KILL_POINT := Vector3(285.0, 0.0, 500.0)
const GATE_KILL_RADIUS := 20.0
const MURDER_HOLE_DAMAGE_MULT := 2.0
const GATE_EDGE_X := 284.0
const GATE_MOVE_SPEED := 2.8
const REPOSITION_SPEED := 3.2
const LOS_SEARCH_RADIUS := 5.0
const FOOT_RAY_UP := 2.2
const FOOT_RAY_DOWN := 3.2
const MAX_STEP_UP := 1.05
const MAX_STEP_DOWN := 3.0
const SURFACE_STEP := 0.42
const BAD_SHOT_REPOSITION_TIME := 2.5
const PERSONAL_SPACE := 0.92
const SEPARATION_SPEED := 2.2
const FALL_FLOOR := -8.0
const NATIVE_NAV_MIN_STEP := 0.08
const NATIVE_NAV_MAX_NEXT_DISTANCE := 18.0
const TARGET_REFRESH_INTERVAL := 0.45
const ORDER_AUTO := 0
const ORDER_ATTACK_RAM := 1
const ORDER_ATTACK_ARCHERS := 2
const ORDER_ATTACK_CLOSEST := 3
const ORDER_DEFEND_GATE := 4
const ORDER_RETREAT_KEEP := 5

@export var range: float = 70.0
@export var fire_interval: float = 2.2
@export var arrow_speed: float = 58.0
@export var arrow_damage: float = 25.0     # support fire — the player (55/arrow) is the real damage dealer
@export var melee_damage: float = 4.0
@export var spread_deg: float = 1.5       # support fire: hits often but misses enough to leave work
@export var muzzle_height: float = 1.6
@export var max_hp: float = 45.0
@export var speed: float = 3.2
@export var gravity: float = 20.0
@export var step_height: float = 0.6
@export var use_native_navigation: bool = false
@export var stats: UnitStats = preload("res://data/ally_archer.tres")   # designer-tunable preset

var type_id: StringName = &"ally_archer"
var display_name: String = "Ally Archer"
var faction: int = UnitStats.Faction.ALLY
var role: int = UnitStats.Role.ARCHER
var level: int = 1
var xp: int = 0
var kills: int = 0
var defense: float = 0.0
var armor: float = 0.0
var armor_type: StringName = &"cloth"
var _cd: float = 0.0
var _targeting: TargetingComponent
var _last_aim_point: Vector3 = Vector3.INF
var _last_forced_gate_threat: bool = false
var _last_has_los: bool = false
var _current_target: Node3D = null
var _target_refresh_t: float = 0.0
var _last_debug_reason: StringName = &"spawn"
var _order_mode: int = ORDER_AUTO
var _order_rally: Vector3 = Vector3.INF
var _order_seq: int = -1
var _nav_path: Array[Vector3] = []
var _nav_index: int = 0
var _reposition_path: Array[Vector3] = []
var _reposition_index: int = 0
var _reposition_goal: Vector3 = Vector3.INF
var _bad_shot_reposition_t: float = 0.0
var _last_shot_target: Node3D = null
var _nav_agent: NavigationAgent3D = null
var _nav_debug_state: StringName = &"idle"
var _nav_driver: StringName = &"fallback"
var _last_progress_pos: Vector3 = Vector3.INF
var _stuck_t: float = 0.0
var _locomotion: Node = null
var _positioning: Node = null
var _shooting: Node = null
var _defender_targeting: Node = null
var _castle_pathfinder: Node = null
var _decision_scheduler: Node = null
var _perf_monitor: Node = null
var _firing_slot: Node3D = null
var hp: float = 45.0
var _dead: bool = false
var _base_level: int = 1
var _base_range: float = 70.0
var _base_arrow_damage: float = 25.0
var _base_melee_damage: float = 4.0
var _base_defense: float = 0.0
var _base_armor: float = 0.0
var _recovery_count: int = 0
var _stuck_event_count: int = 0

func _ready() -> void:
	add_to_group("ally")
	_apply_stats()
	hp = max_hp
	_targeting = TargetingComponent.new()
	_targeting.sight_range = range
	_targeting.priority_weight = 0.12
	add_child(_targeting)
	_setup_character_physics()
	_setup_locomotion()
	_setup_positioning()
	_setup_shooting()
	_setup_defender_targeting()
	_setup_castle_pathfinder()
	_setup_navigation_agent()
	_cd = randf_range(0.0, fire_interval)          # desync the volley so they don't all fire in unison
	_build_body()

func _apply_stats() -> void:
	if stats == null:
		return
	type_id = stats.type_id
	display_name = stats.display_name
	faction = stats.faction
	role = stats.role
	level = stats.level
	_base_level = stats.level
	xp = stats.xp
	kills = stats.kills
	max_hp = stats.max_hp
	armor_type = stats.armor_type
	fire_interval = stats.fire_interval
	arrow_speed = stats.arrow_speed
	_base_range = stats.sight_range
	_base_arrow_damage = stats.ranged_attack_damage
	_base_melee_damage = stats.melee_attack_damage
	_base_defense = stats.defense
	_base_armor = stats.armor
	spread_deg = stats.spread_deg
	muzzle_height = stats.muzzle_height
	speed = stats.speed if stats.speed > 0.0 else speed
	_apply_progression()

func _setup_character_physics() -> void:
	collision_layer = CollisionLayers.ALLY
	collision_mask = CollisionLayers.ACTOR_MASK
	floor_max_angle = deg_to_rad(75.0)
	floor_snap_length = 0.8
	floor_constant_speed = true

func _setup_locomotion() -> void:
	_locomotion = UnitLocomotionScript.new()
	_locomotion.name = "UnitLocomotion"
	add_child(_locomotion)
	_locomotion.setup(self)

func _setup_positioning() -> void:
	_positioning = DefenderPositioningScript.new()
	_positioning.name = "DefenderPositioning"
	add_child(_positioning)

func _setup_shooting() -> void:
	_shooting = ArcherShootingScript.new()
	_shooting.name = "ArcherShooting"
	add_child(_shooting)

func _setup_defender_targeting() -> void:
	_defender_targeting = DefenderTargetingScript.new()
	_defender_targeting.name = "DefenderTargeting"
	add_child(_defender_targeting)

func _setup_castle_pathfinder() -> void:
	_castle_pathfinder = CastlePathfinderScript.new()
	_castle_pathfinder.name = "CastlePathfinder"
	add_child(_castle_pathfinder)

func _can_run_decision(key: StringName, interval: float, max_per_frame: int) -> bool:
	if _decision_scheduler == null or not is_instance_valid(_decision_scheduler):
		_decision_scheduler = get_tree().get_first_node_in_group("decision_scheduler")
	if _decision_scheduler != null and _decision_scheduler.has_method("can_run"):
		return bool(_decision_scheduler.call("can_run", self, key, interval, max_per_frame))
	return true

func _record_perf_us(key: StringName, start_us: int) -> void:
	if _perf_monitor == null or not is_instance_valid(_perf_monitor):
		_perf_monitor = get_tree().get_first_node_in_group("perf_monitor")
	if _perf_monitor != null and _perf_monitor.has_method("record_us"):
		_perf_monitor.call("record_us", key, Time.get_ticks_usec() - start_us)

func _setup_navigation_agent() -> void:
	_nav_agent = NavigationAgent3D.new()
	_nav_agent.name = "NavigationAgent3D"
	_nav_agent.radius = 0.45
	_nav_agent.height = 1.7
	_nav_agent.max_speed = maxf(speed, GATE_MOVE_SPEED)
	_nav_agent.path_desired_distance = 0.8
	_nav_agent.target_desired_distance = 1.2
	_nav_agent.avoidance_enabled = false
	add_child(_nav_agent)
	add_to_group("navigation_debug_actor")

func _apply_progression() -> void:
	level = UnitStats.level_for_kills(_base_level, kills)
	var mult := UnitStats.stat_multiplier(_base_level, level)
	range = _base_range * mult
	arrow_damage = _base_arrow_damage * mult
	melee_damage = _base_melee_damage * mult
	defense = _base_defense * mult
	armor = clampf(_base_armor * mult, 0.0, 0.85)
	if _targeting:
		_targeting.sight_range = range

func _build_body() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	col.shape = cap
	col.position = Vector3(0, 0.9, 0)
	add_child(col)
	Soldier.build(self, Color(0.18, 0.32, 0.62), true)   # friendly-blue archer with a bow

func is_active_ally() -> bool:
	return not _dead and is_inside_tree() and visible and global_position.y > FALL_FLOOR

# enemy archers call this; a felled ally topples off the rampart and is removed
func take_damage(amount: float, _from_pos: Vector3 = Vector3.INF) -> void:
	if _dead:
		return
	var dealt := maxf(0.0, amount - defense) * (1.0 - clampf(armor, 0.0, 0.85))
	hp = maxf(0.0, hp - dealt)
	if hp <= 0.0:
		_die()

func _die() -> void:
	_dead = true
	_release_firing_slot()
	remove_from_group("ally")               # enemy targeting + player stop aiming at the corpse
	set_physics_process(false)
	var au := get_node_or_null("/root/Audio")
	if au:
		au.play_3d("enemy_death", global_position)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "rotation:z", rotation.z + PI * 0.5, 0.5).set_ease(Tween.EASE_IN)
	t.tween_property(self, "position:y", position.y - 0.4, 0.7)
	t.set_parallel(false)
	t.tween_interval(0.5)
	t.tween_callback(queue_free)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if global_position.y < FALL_FLOOR:
		_recover_to_walkable_surface()
		return
	_bad_shot_reposition_t = maxf(0.0, _bad_shot_reposition_t - delta)
	_target_refresh_t = maxf(0.0, _target_refresh_t - delta)
	_move_to_order_rally(delta)
	_separate_from_units(delta)
	if _is_retreating_to_keep():
		_release_firing_slot()
		_current_target = null
		_last_has_los = false
		_last_debug_reason = &"retreat"
		return
	if _should_refresh_target():
		if _can_run_decision(&"ally_target_refresh", TARGET_REFRESH_INTERVAL, 12):
			var start_us := Time.get_ticks_usec()
			_current_target = _acquire()
			_record_perf_us(&"ally_target_acquire", start_us)
			_target_refresh_t = TARGET_REFRESH_INTERVAL + randf_range(0.0, 0.08)
	if _current_target == null:
		_release_firing_slot()
		_last_debug_reason = &"no_target"
	if _current_target:
		_reposition_for_target(delta, _current_target)
	_cd -= delta
	if _cd > 0.0:
		if _current_target:
			_last_debug_reason = &"cooldown"
		return
	var target := _current_target
	if target == null:
		_last_debug_reason = &"no_target"
		return
	if not _ally_fire_enabled():
		_cd = fire_interval
		_last_debug_reason = &"fire_disabled"
		return
	if not _last_has_los and not (_last_forced_gate_threat and _is_gate_defender() and _is_gate_threat(target)):
		_last_debug_reason = &"no_los"
		return
	_cd = fire_interval
	_last_debug_reason = &"shoot"
	_shoot_at(target)

func _acquire() -> Node3D:
	# nearest enemy in range WITH a clear line of sight, via the reusable TargetingComponent
	var origin := _muzzle_position()
	_last_forced_gate_threat = false
	_last_has_los = false
	if _defender_targeting != null and _defender_targeting.has_method("acquire"):
		var result: Dictionary = _defender_targeting.call("acquire", self, _targeting, _order_mode, range, origin)
		var component_target: Node3D = result.get("target", null)
		if component_target != null and is_instance_valid(component_target):
			_last_aim_point = result.get("aim", component_target.global_position + Vector3.UP * 1.1)
			_last_has_los = bool(result.get("has_los", false))
			_last_forced_gate_threat = bool(result.get("forced_gate", false))
			return component_target
		return null
	var ordered := _acquire_order_target(origin)
	if ordered:
		return ordered
	if _is_gate_defender():
		var gate_target := _acquire_gate_threat(origin)
		if gate_target:
			_last_aim_point = gate_target.global_position + Vector3.UP * 1.1
			_last_forced_gate_threat = true
			return gate_target
	var target := _targeting.acquire(origin, get_tree(), get_world_3d().direct_space_state)
	_last_aim_point = _targeting.visible_aim_point(origin, target, get_world_3d().direct_space_state) if target else Vector3.INF
	_last_has_los = target != null
	if target == null:
		target = _acquire_gate_threat(origin)
		if target:
			_last_aim_point = target.global_position + Vector3.UP * 1.1
			_last_forced_gate_threat = true
		else:
			target = _acquire_blocked_threat(origin)
			if target:
				_last_aim_point = target.global_position + Vector3.UP * 1.1
	return target

func _should_refresh_target() -> bool:
	if _target_refresh_t <= 0.0:
		return true
	if _current_target == null or not is_instance_valid(_current_target):
		return true
	if not _same_scene_scope(_current_target):
		return true
	if _current_target.is_queued_for_deletion():
		return true
	return _muzzle_position().distance_squared_to(_current_target.global_position) > range * range * 1.15

func _muzzle_position() -> Vector3:
	return global_transform * Vector3(-0.46, muzzle_height, 0.28)

func _ally_fire_enabled() -> bool:
	var settings := get_node_or_null("/root/GameSettings")
	if settings == null:
		return true
	return bool(settings.get("ally_archers_fire_enabled"))

func set_defender_order(mode: int, rally: Vector3 = Vector3.INF, seq: int = 0) -> void:
	if mode == _order_mode and rally.is_equal_approx(_order_rally) and seq == _order_seq:
		return
	_order_mode = mode
	_order_rally = rally
	_order_seq = seq
	_target_refresh_t = 0.0
	if _nav_agent and rally.x < 1.0e19:
		_nav_agent.target_position = rally
		_nav_path = _build_nav_path_to(rally)
		_nav_index = 0
		_reposition_path.clear()
		_reposition_goal = Vector3.INF
		_last_progress_pos = global_position
	_stuck_t = 0.0
	_nav_debug_state = &"moving" if rally.x < 1.0e19 else &"idle"

func _move_to_order_rally(delta: float) -> void:
	if _order_rally.x >= 1.0e19:
		return
	if _move_with_native_navigation(delta, REPOSITION_SPEED):
		return
	if _nav_path.is_empty():
		_nav_debug_state = &"unreachable"
		return
	var desired := _nav_path[mini(_nav_index, _nav_path.size() - 1)]
	if global_position.distance_squared_to(desired) <= 0.49:
		if _nav_index < _nav_path.size() - 1:
			_nav_index += 1
		return
	_walk_towards_on_surfaces(desired, delta, REPOSITION_SPEED)

func _move_with_native_navigation(delta: float, speed_value: float) -> bool:
	if not use_native_navigation or _nav_agent == null or not _has_castle_navigation_region():
		_nav_driver = &"fallback"
		return false
	if _nav_agent.is_navigation_finished():
		_nav_debug_state = &"arrived"
		_nav_driver = &"native"
		_apply_character_velocity(Vector3.ZERO, delta)
		return true
	var next := _nav_agent.get_next_path_position()
	var to := next - global_position
	to.y = 0.0
	var distance := to.length()
	if distance < NATIVE_NAV_MIN_STEP:
		_nav_driver = &"native"
		_apply_character_velocity(Vector3.ZERO, delta)
		return true
	if distance > NATIVE_NAV_MAX_NEXT_DISTANCE:
		_nav_driver = &"fallback"
		return false
	_nav_driver = &"native"
	var moved := _move_character(to / distance, delta, speed_value)
	_track_navigation_progress(delta)
	return moved

func _has_castle_navigation_region() -> bool:
	return is_inside_tree() and not get_tree().get_nodes_in_group("castle_navigation_region").is_empty()

func _is_retreating_to_keep() -> bool:
	if _order_mode != ORDER_RETREAT_KEEP or _order_rally.x >= 1.0e19:
		return false
	var flat := Vector2(global_position.x - _order_rally.x, global_position.z - _order_rally.z)
	return flat.length() > 2.2

func _move_to_gate_edge(delta: float) -> void:
	var desired := global_position
	desired.x = GATE_EDGE_X
	if _current_target:
		desired.z = clampf(_current_target.global_position.z, 495.0, 505.0)
	_walk_towards_on_surfaces(desired, delta, GATE_MOVE_SPEED)

func _reposition_for_target(delta: float, target: Node3D) -> void:
	if _last_forced_gate_threat and _is_gate_threat(target) and not _is_gate_defender():
		_release_firing_slot()
		_move_to_gate_edge(delta)
		_last_has_los = false
		_last_debug_reason = &"gate_edge"
		return
	_last_has_los = false
	_release_firing_slot()
	_last_aim_point = target.global_position + Vector3.UP * _targeting.aim_height
	_last_has_los = true
	_last_debug_reason = &"has_target"

func _build_nav_path_to(rally: Vector3) -> Array[Vector3]:
	if rally.x >= 1.0e19:
		return []
	var path: Array[Vector3] = []
	if _order_mode == ORDER_DEFEND_GATE:
		if _is_on_gate_roof():
			path.append(rally)
		else:
			var dynamic_gate_route := _dynamic_route_to(rally)
			if not dynamic_gate_route.is_empty():
				path.append_array(dynamic_gate_route)
			else:
				path.append_array(_route_from_tower_to_wallwalk())
				path.append_array(_route_to_gate_walk())
	elif _order_mode == ORDER_RETREAT_KEEP:
		path.append_array(_route_to_keep())
	path.append(rally)
	return _compact_path(path)

func _is_on_gate_roof() -> bool:
	return global_position.y >= 24.0 and global_position.x >= 283.0 and global_position.x <= 292.0 and absf(global_position.z - GATE_KILL_POINT.z) <= 8.5

func _route_from_gate_roof_to_walk() -> Array[Vector3]:
	if global_position.y < 24.0 or absf(global_position.z - GATE_KILL_POINT.z) > 14.0:
		return []
	if global_position.z >= GATE_KILL_POINT.z:
		return [
			Vector3(291.9, 27.5, 506.0),
			Vector3(291.5, 26.5, 504.5),
			Vector3(291.0, 25.5, 502.0),
			Vector3(291.9, 24.5, 500.4),
			Vector3(292.0, 24.0, 501.0),
			Vector3(292.5, 22.5, 504.0),
			Vector3(293.0, 21.5, 505.5),
		]
	return [
		Vector3(291.9, 27.5, 494.0),
		Vector3(291.5, 26.5, 495.5),
		Vector3(291.0, 25.5, 498.0),
		Vector3(291.9, 24.5, 499.6),
		Vector3(292.0, 24.0, 499.0),
		Vector3(292.5, 22.5, 496.0),
		Vector3(293.0, 21.5, 494.5),
	]

func _route_from_tower_to_wallwalk() -> Array[Vector3]:
	if global_position.y < 24.0 or absf(global_position.z - GATE_KILL_POINT.z) < 14.0:
		return []
	if global_position.z < GATE_KILL_POINT.z:
		return [
			Vector3(298.0, 27.5, 467.0),
			Vector3(299.15, 27.0, 465.5),
			Vector3(299.15, 25.0, 469.0),
			Vector3(296.85, 24.0, 469.0),
			Vector3(296.85, 22.0, 466.0),
		]
	return [
		Vector3(298.0, 27.5, 533.0),
		Vector3(299.15, 27.0, 534.5),
		Vector3(299.15, 25.0, 531.0),
		Vector3(296.85, 24.0, 531.0),
		Vector3(296.85, 22.0, 534.0),
	]

func _route_to_gate_walk() -> Array[Vector3]:
	if global_position.z < GATE_KILL_POINT.z:
		return [
			Vector3(294.0, 21.0, 480.0),
			Vector3(290.0, 22.5, 488.0),
			Vector3(288.5, 22.5, 494.0),
			Vector3(288.5, 22.5, 500.0),
		]
	return [
		Vector3(294.0, 21.0, 520.0),
		Vector3(290.0, 22.5, 512.0),
		Vector3(288.5, 22.5, 506.0),
		Vector3(288.5, 22.5, 500.0),
	]

func _route_to_keep() -> Array[Vector3]:
	var dynamic_route := _dynamic_route_to(_order_rally)
	if not dynamic_route.is_empty():
		return dynamic_route
	if global_position.y >= 24.0 and absf(global_position.z - GATE_KILL_POINT.z) <= 12.0:
		var gate_route := _route_from_gate_roof_to_walk()
		gate_route.append_array(_route_through_courtyard_to_keep(GATE_KILL_POINT.z))
		return gate_route
	if global_position.y >= 24.0 and global_position.z < GATE_KILL_POINT.z:
		var south_start_z := clampf(global_position.z, GATE_KILL_POINT.z - 31.0, GATE_KILL_POINT.z - 16.0)
		var south_route: Array[Vector3] = [
			Vector3(clampf(global_position.x, 296.0, 300.0), 27.2, south_start_z),
		]
		south_route.append_array(_route_through_courtyard_to_keep(GATE_KILL_POINT.z - 16.0))
		return south_route
	if global_position.y >= 24.0 and global_position.z > GATE_KILL_POINT.z:
		var north_start_z := clampf(global_position.z, GATE_KILL_POINT.z + 16.0, GATE_KILL_POINT.z + 31.0)
		var north_route: Array[Vector3] = [
			Vector3(clampf(global_position.x, 296.0, 300.0), 27.2, north_start_z),
		]
		north_route.append_array(_route_through_courtyard_to_keep(GATE_KILL_POINT.z + 16.0))
		return north_route
	return _route_through_courtyard_to_keep(global_position.z)

func _route_through_courtyard_to_keep(start_z: float) -> Array[Vector3]:
	var side_z := GATE_KILL_POINT.z - 16.0 if start_z < GATE_KILL_POINT.z else GATE_KILL_POINT.z + 16.0
	if absf(start_z - GATE_KILL_POINT.z) <= 3.0:
		side_z = GATE_KILL_POINT.z
	if start_z <= GATE_KILL_POINT.z:
		return [
			Vector3(294.0, 21.0, side_z),
			Vector3(312.0, 19.0, GATE_KILL_POINT.z - 10.0),
			Vector3(330.0, 21.0, GATE_KILL_POINT.z - 5.0),
			Vector3(345.0, 32.0, GATE_KILL_POINT.z - 5.0),
		]
	return [
		Vector3(294.0, 21.0, side_z),
		Vector3(312.0, 19.0, GATE_KILL_POINT.z + 10.0),
		Vector3(330.0, 21.0, GATE_KILL_POINT.z + 5.0),
		Vector3(345.0, 32.0, GATE_KILL_POINT.z + 5.0),
	]

func _dynamic_route_to(target: Vector3) -> Array[Vector3]:
	if _castle_pathfinder != null and _castle_pathfinder.has_method("route"):
		return _castle_pathfinder.call("route", self, global_position, target)
	if target.x >= 1.0e19:
		return []
	var points: Array[Vector3] = [global_position, target]
	var edge_pairs: Array[Vector2i] = []
	for node in get_tree().get_nodes_in_group("castle_navigation_edge"):
		if not node is Node or not is_instance_valid(node):
			continue
		var edge := node as Node
		if not edge.has_meta("nav_a") or not edge.has_meta("nav_b"):
			continue
		var a: Vector3 = edge.get_meta("nav_a")
		var b: Vector3 = edge.get_meta("nav_b")
		var ia := points.size()
		points.append(a)
		var ib := points.size()
		points.append(b)
		edge_pairs.append(Vector2i(ia, ib))
	if edge_pairs.is_empty():
		return []
	var start_links := _terminal_links(points, 0)
	var goal_links := _terminal_links(points, 1)
	if start_links.is_empty() or goal_links.is_empty():
		return []
	var path_indices := _shortest_retreat_path(points, edge_pairs, start_links, goal_links)
	if path_indices.size() < 2:
		return []
	var route: Array[Vector3] = []
	for i in range(1, path_indices.size()):
		route.append(points[path_indices[i]])
	return route

func _terminal_links(points: Array[Vector3], terminal_idx: int) -> Array[int]:
	var best_score := INF
	var links: Array[int] = []
	for i in range(2, points.size()):
		var distance := points[terminal_idx].distance_to(points[i])
		var height_delta := absf(points[terminal_idx].y - points[i].y)
		if distance > 18.0 or height_delta > 8.0:
			continue
		if distance < best_score - 0.1:
			best_score = distance
			links = [i]
		elif absf(distance - best_score) <= 0.1:
			links.append(i)
	return links

func _shortest_retreat_path(points: Array[Vector3], edge_pairs: Array[Vector2i], start_links: Array[int], goal_links: Array[int]) -> Array[int]:
	var count := points.size()
	var dist: Array[float] = []
	var prev: Array[int] = []
	var used: Array[bool] = []
	for _i in count:
		dist.append(INF)
		prev.append(-1)
		used.append(false)
	dist[0] = 0.0
	for _step in count:
		var best := -1
		var best_dist := INF
		for i in count:
			if not used[i] and dist[i] < best_dist:
				best = i
				best_dist = dist[i]
		if best == -1 or best == 1:
			break
		used[best] = true
		for other in count:
			if used[other] or other == best:
				continue
			var cost := _retreat_edge_cost(best, other, points, edge_pairs, start_links, goal_links)
			if cost >= INF:
				continue
			var next_dist := dist[best] + cost
			if next_dist < dist[other]:
				dist[other] = next_dist
				prev[other] = best
	if prev[1] == -1:
		return []
	var path: Array[int] = []
	var cursor := 1
	while cursor != -1:
		path.push_front(cursor)
		cursor = prev[cursor]
	return path

func _retreat_edge_cost(a_idx: int, b_idx: int, points: Array[Vector3], edge_pairs: Array[Vector2i], start_links: Array[int], goal_links: Array[int]) -> float:
	if a_idx == b_idx:
		return INF
	if (a_idx == 0 and b_idx == 1) or (a_idx == 1 and b_idx == 0):
		return INF
	if _is_navigation_edge_pair(a_idx, b_idx, edge_pairs):
		return points[a_idx].distance_to(points[b_idx])
	var a := points[a_idx]
	var b := points[b_idx]
	var distance := a.distance_to(b)
	var height_delta := absf(a.y - b.y)
	if a_idx == 0 or b_idx == 0:
		var other_start := b_idx if a_idx == 0 else a_idx
		return distance if start_links.has(other_start) and distance <= 18.0 and height_delta <= 8.0 else INF
	if a_idx == 1 or b_idx == 1:
		var other_goal := b_idx if a_idx == 1 else a_idx
		return distance if goal_links.has(other_goal) and distance <= 18.0 and height_delta <= 8.0 else INF
	return distance if distance <= 7.5 and height_delta <= 3.5 else INF

func _is_navigation_edge_pair(a_idx: int, b_idx: int, edge_pairs: Array[Vector2i]) -> bool:
	for pair in edge_pairs:
		if (pair.x == a_idx and pair.y == b_idx) or (pair.x == b_idx and pair.y == a_idx):
			return true
	return false

func _compact_path(points: Array[Vector3]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p in points:
		if out.is_empty() or out.back().distance_squared_to(p) > 1.0:
			out.append(p)
	return out

func _walk_towards_on_surfaces(desired: Vector3, delta: float, speed_value: float) -> bool:
	if not is_inside_tree() or get_world_3d() == null:
		return false
	var flat_goal := desired - global_position
	flat_goal.y = 0.0
	var distance := flat_goal.length()
	if distance < 0.05:
		velocity = Vector3.ZERO
		return absf(desired.y - global_position.y) <= 0.35
	var step_len: float = minf(SURFACE_STEP, minf(speed_value * delta, distance))
	var forward := flat_goal / distance
	var candidates: Array[Vector3] = [
		forward,
		forward.rotated(Vector3.UP, deg_to_rad(18.0)),
		forward.rotated(Vector3.UP, deg_to_rad(-18.0)),
		forward.rotated(Vector3.UP, deg_to_rad(42.0)),
		forward.rotated(Vector3.UP, deg_to_rad(-42.0)),
		forward.rotated(Vector3.UP, deg_to_rad(78.0)),
		forward.rotated(Vector3.UP, deg_to_rad(-78.0)),
	]
	var best := Vector3.INF
	var best_score := INF
	for dir: Vector3 in candidates:
		var next_xz := global_position + dir * step_len
		var surface := _surface_step_at(next_xz, desired.y)
		if surface.x >= 1.0e19:
			continue
		var progress := surface.distance_squared_to(desired)
		var turn_cost := 1.0 - maxf(-1.0, minf(1.0, dir.dot(forward)))
		var height_cost := absf(surface.y - global_position.y) * 0.7
		var score := progress + turn_cost * 2.5 + height_cost + _unit_overlap_penalty(surface) * 8.0
		if score < best_score:
			best_score = score
			best = surface
	if best.x >= 1.0e19:
		_nav_debug_state = &"no_surface"
		_nav_driver = &"fallback"
		velocity = Vector3.ZERO
		return false
	var move := best - global_position
	move.y = 0.0
	if move.length() < 0.001:
		_apply_character_velocity(Vector3.ZERO, delta)
		return false
	var moved := _move_character(move.normalized(), delta, speed_value)
	_track_navigation_progress(delta)
	return moved

func _move_to_reposition_goal(desired: Vector3, delta: float, speed_value: float) -> bool:
	if desired.x >= 1.0e19:
		return false
	var needs_route := global_position.distance_to(desired) > 8.0 or absf(global_position.y - desired.y) > 2.0
	if not needs_route:
		_reposition_path.clear()
		_reposition_goal = Vector3.INF
		return _walk_towards_on_surfaces(desired, delta, speed_value)
	if _reposition_goal.x >= 1.0e19 or _reposition_goal.distance_squared_to(desired) > 1.0:
		_reposition_goal = desired
		_reposition_path = _dynamic_route_to(desired)
		_reposition_index = 0
		if _reposition_path.is_empty():
			_reposition_path = [desired]
	if _reposition_path.is_empty():
		return _walk_towards_on_surfaces(desired, delta, speed_value)
	var waypoint := _reposition_path[mini(_reposition_index, _reposition_path.size() - 1)]
	if global_position.distance_squared_to(waypoint) <= 0.64:
		if _reposition_index < _reposition_path.size() - 1:
			_reposition_index += 1
			waypoint = _reposition_path[_reposition_index]
		else:
			_reposition_path.clear()
			_reposition_goal = Vector3.INF
			return _walk_towards_on_surfaces(desired, delta, speed_value)
	var moved := _walk_towards_on_surfaces(waypoint, delta, speed_value)
	_nav_debug_state = &"slot_route" if moved else _nav_debug_state
	return moved

func _move_character(dir: Vector3, delta: float, speed_value: float) -> bool:
	var pre := global_position
	_apply_character_velocity(dir * speed_value, delta)
	var moved := global_position - pre
	moved.y = 0.0
	if is_on_floor() and moved.length() < speed_value * delta * 0.45:
		for lift in [0.18, 0.32, 0.48, step_height]:
			var lifted := global_transform
			lifted.origin += Vector3.UP * lift
			if not test_move(lifted, dir * 0.38):
				global_position += Vector3.UP * lift + dir * 0.38
				_apply_character_velocity(dir * speed_value, delta)
				break
	moved = global_position - pre
	moved.y = 0.0
	if moved.length() > 0.01:
		rotation.y = atan2(dir.x, dir.z)
		_nav_debug_state = &"moving"
		return true
	_nav_debug_state = &"blocked"
	return false

func _apply_character_velocity(horizontal_velocity: Vector3, delta: float) -> void:
	if _locomotion != null and _locomotion.has_method("move_direction"):
		var speed_value := horizontal_velocity.length()
		if speed_value < 0.001:
			_locomotion.call("idle", gravity, delta)
		else:
			_locomotion.call("move_direction", horizontal_velocity / speed_value, speed_value, gravity, delta, false)
		return
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = -1.0
	else:
		velocity.y -= gravity * delta
	move_and_slide()

func _track_navigation_progress(delta: float) -> void:
	if _last_progress_pos.x >= 1.0e19:
		_last_progress_pos = global_position
		return
	var moved := global_position.distance_to(_last_progress_pos)
	if moved > 0.35:
		_last_progress_pos = global_position
		_stuck_t = 0.0
		return
	_stuck_t += delta
	if _stuck_t >= 2.0 and _order_rally.x < 1.0e19:
		if _nav_debug_state != &"stuck":
			_stuck_event_count += 1
		_nav_debug_state = &"stuck"

func _recover_to_walkable_surface() -> void:
	_recovery_count += 1
	var space := get_world_3d().direct_space_state
	var from := Vector3(global_position.x, 80.0, global_position.z)
	var to := Vector3(global_position.x, -20.0, global_position.z)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = CollisionLayers.WORLD
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return
	global_position = hit.position + Vector3.UP * 0.05
	velocity = Vector3.ZERO
	_nav_debug_state = &"recovered"

func navigation_debug_state() -> StringName:
	return _nav_debug_state

func navigation_debug_driver() -> StringName:
	return _nav_driver

func current_navigation_target() -> Vector3:
	return _order_rally

func recovery_count() -> int:
	return _recovery_count

func stuck_recovery_count() -> int:
	return _stuck_event_count

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

func _separate_from_units(delta: float) -> void:
	var push := _separation_vector(global_position)
	if push.length() < 0.001:
		return
	_walk_towards_on_surfaces(global_position + push.normalized(), delta, SEPARATION_SPEED)

func _separation_vector(from: Vector3) -> Vector3:
	var push := Vector3.ZERO
	for node in _nearby_units():
		if node == self or not node is Node3D or not is_instance_valid(node):
			continue
		var other := node as Node3D
		if not _same_scene_scope(other):
			continue
		if absf(other.global_position.y - from.y) > 2.5:
			continue
		var away := from - other.global_position
		away.y = 0.0
		var dist := away.length()
		if dist < 0.001 or dist >= PERSONAL_SPACE:
			continue
		push += away.normalized() * ((PERSONAL_SPACE - dist) / PERSONAL_SPACE)
	return push

func _unit_overlap_penalty(point: Vector3) -> float:
	var penalty := 0.0
	for node in _nearby_units():
		if node == self or not node is Node3D or not is_instance_valid(node):
			continue
		var other := node as Node3D
		if not _same_scene_scope(other):
			continue
		if absf(other.global_position.y - point.y) > 2.5:
			continue
		var dist := Vector2(point.x - other.global_position.x, point.z - other.global_position.z).length()
		if dist < PERSONAL_SPACE:
			penalty += (PERSONAL_SPACE - dist) / PERSONAL_SPACE
	return penalty

func _nearby_units() -> Array:
	var registry := get_tree().get_first_node_in_group("combat_registry")
	if registry != null and registry.has_method("active_units_near"):
		var units: Array = registry.call("active_units_near", global_position, PERSONAL_SPACE * 2.4, true, true, false)
		return units
	var units := get_tree().get_nodes_in_group("ally")
	units.append_array(get_tree().get_nodes_in_group("enemy"))
	return units

func _surface_step_at(point: Vector3, target_y: float = INF) -> Vector3:
	var space := get_world_3d().direct_space_state
	var ray_top_y := global_position.y
	if target_y < 1.0e19:
		ray_top_y = maxf(ray_top_y, target_y)
	var ray_bottom_y := global_position.y
	if target_y < 1.0e19:
		ray_bottom_y = minf(ray_bottom_y, target_y)
	var from := Vector3(point.x, ray_top_y + FOOT_RAY_UP, point.z)
	var to := Vector3(point.x, ray_bottom_y - FOOT_RAY_DOWN, point.z)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = CollisionLayers.WORLD
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return Vector3.INF
	var hit_pos: Vector3 = hit.position
	var dy := hit_pos.y - global_position.y
	if dy > MAX_STEP_UP or dy < -MAX_STEP_DOWN:
		return Vector3.INF
	return hit_pos

func _same_scene_scope(other: Node) -> bool:
	return _scene_scope(other) == _scene_scope(self)

func _scene_scope(node: Node) -> Node:
	var scope := node
	while scope.get_parent() != null and scope.get_parent() != get_tree().root:
		scope = scope.get_parent()
	return scope

func _find_firing_position(space: PhysicsDirectSpaceState3D, target: Node3D) -> Vector3:
	if _positioning != null and _positioning.has_method("best_firing_slot"):
		var slot: Node3D = _positioning.call("best_firing_slot", self, target, _muzzle_position() - global_position, space)
		if slot != null and is_instance_valid(slot):
			_reserve_firing_slot(slot)
			return slot.global_position
	_release_firing_slot()
	var best := Vector3.INF
	var best_score := INF
	var offsets := [
		Vector2.ZERO,
		Vector2(-1.5, 0.0), Vector2(-3.0, 0.0), Vector2(-4.5, 0.0),
		Vector2(1.5, 0.0), Vector2(3.0, 0.0), Vector2(4.5, 0.0),
		Vector2(0.0, -1.5), Vector2(0.0, -3.0), Vector2(0.0, -4.5),
		Vector2(0.0, 1.5), Vector2(0.0, 3.0), Vector2(0.0, 4.5),
		Vector2(-2.5, -2.5), Vector2(-2.5, 2.5), Vector2(2.5, -2.5), Vector2(2.5, 2.5),
	]
	if _is_gate_defender() and _is_gate_threat(target):
		var gate_z := clampf(target.global_position.z, 495.0, 505.0)
		offsets.append(Vector2(GATE_EDGE_X - global_position.x, gate_z - global_position.z))
		offsets.append(Vector2(GATE_EDGE_X - global_position.x, clampf(gate_z - 2.0, 495.0, 505.0) - global_position.z))
		offsets.append(Vector2(GATE_EDGE_X - global_position.x, clampf(gate_z + 2.0, 495.0, 505.0) - global_position.z))
	for off in offsets:
		if off.length() > LOS_SEARCH_RADIUS + 0.1 and not (_is_gate_defender() and _is_gate_threat(target)):
			continue
		var candidate := global_position + Vector3(off.x, 0.0, off.y)
		var muzzle := candidate + (_muzzle_position() - global_position)
		var aim := _targeting.visible_aim_point(muzzle, target, space)
		if aim.x >= 1.0e19:
			continue
		var score := candidate.distance_squared_to(global_position) + candidate.distance_to(target.global_position) * 0.08
		if _is_gate_defender() and _is_gate_threat(target):
			score += absf(candidate.x - GATE_EDGE_X) * 5.0
		if score < best_score:
			best_score = score
			best = candidate
	return best

func current_firing_slot_position() -> Vector3:
	return _firing_slot.global_position if _firing_slot != null and is_instance_valid(_firing_slot) else Vector3.INF

func defender_debug_snapshot() -> Dictionary:
	var target_name := "none"
	var target_distance := -1.0
	if _current_target != null and is_instance_valid(_current_target):
		var label_value: Variant = _current_target.get("display_name")
		target_name = str(label_value) if label_value != null and not str(label_value).is_empty() else _current_target.name
		target_distance = global_position.distance_to(_current_target.global_position)
	var slot_pos := current_firing_slot_position()
	return {
		"name": display_name,
		"level": level,
		"kills": kills,
		"order": _order_mode,
		"nav": str(_nav_debug_state),
		"driver": str(_nav_driver),
		"target": target_name,
		"target_distance": target_distance,
		"has_los": _last_has_los,
		"forced_gate": _last_forced_gate_threat,
		"slot": slot_pos,
		"has_slot": slot_pos.x < 1.0e19,
		"cooldown": maxf(_cd, 0.0),
		"reason": str(_last_debug_reason),
	}

func _reserve_firing_slot(slot: Node3D) -> void:
	if slot == null or not is_instance_valid(slot):
		_release_firing_slot()
		return
	if _firing_slot == slot and int(slot.get_meta("reserved_by", 0)) == get_instance_id():
		return
	if _positioning != null and _positioning.has_method("release_slot") and _firing_slot != null and is_instance_valid(_firing_slot):
		_positioning.call("release_slot", self, _firing_slot)
	if _positioning != null and _positioning.has_method("reserve_slot") and bool(_positioning.call("reserve_slot", self, slot)):
		_firing_slot = slot
	else:
		_firing_slot = null

func _release_firing_slot() -> void:
	if _positioning != null and _positioning.has_method("release_slot") and _firing_slot != null and is_instance_valid(_firing_slot):
		_positioning.call("release_slot", self, _firing_slot)
	_firing_slot = null

func _acquire_gate_threat(origin: Vector3) -> Node3D:
	var best: Node3D = null
	var best_score := INF
	for e in _active_enemies():
		if not is_instance_valid(e) or not e is Node3D:
			continue
		var enemy := e as Node3D
		if not _same_scene_scope(enemy):
			continue
		if origin.distance_squared_to(enemy.global_position) > range * range:
			continue
		var ep := enemy.global_position
		var gate_d := Vector2(ep.x - GATE_KILL_POINT.x, ep.z - GATE_KILL_POINT.z).length()
		if gate_d > GATE_KILL_RADIUS and not enemy.is_in_group("ladder"):
			continue
		var score := gate_d * 20.0 + origin.distance_to(ep)
		if enemy.is_in_group("ladder"):
			score *= 0.5
		if score < best_score:
			best_score = score
			best = enemy
	return best

func _acquire_order_target(origin: Vector3) -> Node3D:
	match _order_mode:
		ORDER_ATTACK_RAM:
			return _acquire_by_filter(origin, func(enemy: Node3D) -> bool:
				return enemy.is_in_group("ram")
			)
		ORDER_ATTACK_ARCHERS:
			return _acquire_by_filter(origin, func(enemy: Node3D) -> bool:
				return _is_enemy_archer(enemy)
			)
		ORDER_ATTACK_CLOSEST:
			return _acquire_by_filter(origin, func(_enemy: Node3D) -> bool:
				return true
			)
		ORDER_DEFEND_GATE:
			var gate_target := _acquire_gate_threat(origin)
			if gate_target:
				_last_aim_point = gate_target.global_position + Vector3.UP * 1.1
				_last_forced_gate_threat = true
				return gate_target
		ORDER_RETREAT_KEEP:
			return _acquire_by_filter(origin, func(enemy: Node3D) -> bool:
				return enemy.global_position.x >= 300.0
			)
	return null

func _acquire_by_filter(origin: Vector3, accepts: Callable) -> Node3D:
	var space := get_world_3d().direct_space_state
	var best_visible: Node3D = null
	var best_visible_score := INF
	var best_blocked: Node3D = null
	var best_blocked_score := INF
	for e in _active_enemies():
		if not is_instance_valid(e) or not e is Node3D:
			continue
		var enemy := e as Node3D
		if not _same_scene_scope(enemy):
			continue
		if not accepts.call(enemy):
			continue
		var dist_sq := origin.distance_squared_to(enemy.global_position)
		if dist_sq > range * range:
			continue
		var aim := _targeting.visible_aim_point(origin, enemy, space)
		var score := dist_sq
		if enemy.is_in_group("ram"):
			score *= 0.4
		elif enemy.is_in_group("ladder"):
			score *= 0.55
		if aim.x < 1.0e19:
			if score < best_visible_score:
				best_visible_score = score
				best_visible = enemy
				_last_aim_point = aim
				_last_has_los = true
		elif score < best_blocked_score:
			best_blocked_score = score
			best_blocked = enemy
	if best_visible:
		return best_visible
	if best_blocked:
		_last_aim_point = best_blocked.global_position + Vector3.UP * 1.1
	return best_blocked

func _is_enemy_archer(enemy: Node3D) -> bool:
	var type_value: Variant = enemy.get("type_id")
	if type_value != null and str(type_value).contains("archer"):
		return true
	var role_value: Variant = enemy.get("role")
	return role_value != null and int(role_value) == UnitStats.Role.ARCHER

func _active_enemies() -> Array:
	var registry := get_tree().get_first_node_in_group("combat_registry")
	if registry != null and registry.has_method("active_enemies_near"):
		return registry.call("active_enemies_near", global_position, range)
	return get_tree().get_nodes_in_group("enemy")

func _acquire_blocked_threat(origin: Vector3) -> Node3D:
	var best: Node3D = null
	var best_score := INF
	for e in _active_enemies():
		if not is_instance_valid(e) or not e is Node3D:
			continue
		var enemy := e as Node3D
		if not _same_scene_scope(enemy):
			continue
		var dist_sq := origin.distance_squared_to(enemy.global_position)
		if dist_sq > range * range:
			continue
		var score := dist_sq
		if enemy.is_in_group("ladder"):
			score *= 0.35
		if _is_gate_threat(enemy):
			score *= 0.45
		if score < best_score:
			best_score = score
			best = enemy
	return best

func _shoot_at(target: Node3D) -> void:
	var tpos := _last_aim_point if _last_aim_point.x < 1.0e19 else target.global_position + Vector3.UP * 1.0
	_face_target(tpos)
	var muzzle := _muzzle_position()
	if _shooting != null and _shooting.has_method("has_clear_ballistic_launch") and not bool(_shooting.call("has_clear_ballistic_launch", self, target, tpos, muzzle, arrow_speed)):
		_bad_shot_reposition_t = BAD_SHOT_REPOSITION_TIME
		_last_debug_reason = &"blocked_arc"
		return
	var result: Dictionary = _shooting.call("shoot", self, target, tpos, muzzle, arrow_speed, arrow_damage, spread_deg) if _shooting != null else {}
	if result.is_empty():
		return
	var a: Node = result.get("arrow", null)
	if a != null and a.has_signal("hit"):
		a.hit.connect(_on_arrow_hit)
	_last_shot_target = target
	if _last_forced_gate_threat and _is_gate_defender() and _is_gate_threat(target):
		_schedule_murder_hole_hit(target, minf(0.35, float(result.get("flight_time", 0.35))))

func _face_target(point: Vector3) -> void:
	var to := point - global_position
	to.y = 0.0
	if to.length() > 0.05:
		rotation.y = atan2(to.x, to.z)

func _is_gate_defender() -> bool:
	return global_position.x >= 283.0 and global_position.x <= 286.8 and absf(global_position.z - GATE_KILL_POINT.z) <= 7.0

func _is_gate_threat(target: Node3D) -> bool:
	if target == null:
		return false
	var p := target.global_position
	return Vector2(p.x - GATE_KILL_POINT.x, p.z - GATE_KILL_POINT.z).length() <= GATE_KILL_RADIUS or target.is_in_group("ladder")

func _schedule_murder_hole_hit(target: Node3D, delay: float) -> void:
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(func() -> void:
		_apply_murder_hole_hit(target)
	)

func _apply_murder_hole_hit(target: Node3D) -> void:
	if not is_instance_valid(target) or not _is_gate_threat(target):
		return
	var damage := arrow_damage * MURDER_HOLE_DAMAGE_MULT
	var hit_y := target.global_position.y + (0.9 if target.is_in_group("ram") else 1.55)
	if target.has_method("take_damage_at"):
		target.take_damage_at(damage, hit_y)
	elif target.has_method("take_damage"):
		target.take_damage(damage)
	_on_arrow_hit(target)

func _on_arrow_hit(body: Node) -> void:
	if body and body.get("xp_value") != null and body.get("hp") != null and float(body.get("hp")) <= 0.0:
		kills += 1
		_apply_progression()
		return
	if body == null or (not body.is_in_group("enemy") and not body.is_in_group("siege_ladder")):
		_bad_shot_reposition_t = BAD_SHOT_REPOSITION_TIME
		if _last_shot_target and is_instance_valid(_last_shot_target):
			_current_target = _last_shot_target
		return
