class_name LadderOrcEnemy
extends Enemy

## Fast raider assigned to a four-orc ladder crew. It ignores the closed gate, carries the ladder
## to an assigned wall lane, deploys it with the crew, climbs onto the rampart, then attacks nearby
## defenders.

const DEFAULT_STATS := preload("res://data/enemy_ladder_orc.tres")
const SIEGE_LADDER := preload("res://scenes/enemy/siege_ladder.tscn")
const MIN_CARRIERS_TO_DEPLOY := 2
const DEPLOY_WORK_RADIUS := 5.2
const DEPLOY_DURATION := 3.2

static var _shared_carried_beam_mesh: BoxMesh = null
static var _shared_carried_wood_material: StandardMaterial3D = null

var _ladder_foot := Vector3(288.0, 0.0, 492.0)
var _ladder_top := Vector3(294.0, 22.0, 492.0)
var _wall_goal := Vector3(294.0, 22.0, 492.0)
var _ladder_normal := Vector3(-1.0, 0.0, 0.0)
var _climbing := false
var _attack_target: Node3D = null
var _ladder_prop: Node3D = null
var _carried_ladder_visual: Node3D = null
var _crew_id: int = 0
var _crew_index: int = -1
var _carrying_ladder := false
var _ladder_deployed := false
var _helping_crew_id: int = 0
var _deploying_ladder := false
var _deploy_t := 0.0

func _ready() -> void:
	stats = DEFAULT_STATS
	super()
	add_to_group("ladder")

func setup_ladder_carry(crew_id: int, crew_index: int, foot: Vector3, top: Vector3, normal: Vector3, siege_ref: Node = null, approach_anchor: Vector3 = Vector3.INF) -> void:
	siege = siege_ref
	_crew_id = crew_id
	_crew_index = crew_index
	_carrying_ladder = true
	_ladder_foot = foot
	_ladder_top = top
	_wall_goal = top
	_ladder_normal = normal.normalized() if normal.length() > 0.01 else Vector3(-1.0, 0.0, 0.0)
	var side := _ladder_normal.cross(Vector3.UP).normalized()
	if side.length() < 0.01:
		side = Vector3.FORWARD
	var row_depth := 3.0 if crew_index < 2 else 4.4
	var left_right := -0.9 if crew_index % 2 == 0 else 0.9
	var carry_goal := _ladder_foot + _ladder_normal * row_depth + side * left_right
	var approach_base := approach_anchor if approach_anchor != Vector3.INF else _ladder_foot + _ladder_normal * 24.0
	var approach := approach_base + side * (left_right * 2.0)
	approach.y = _ladder_foot.y
	carry_goal.y = _ladder_foot.y
	path = [approach, carry_goal]
	_wp = 0
	gate_wp = -1
	target = path[0]
	add_to_group("ladder_carrier")
	set_meta("crew_id", crew_id)
	_apply_carrying_bonus()
	if _crew_index == 0:
		_build_carried_ladder_visual()

func _can_attack_gate() -> bool:
	return false

func _apply_carrying_bonus() -> void:
	max_hp = maxf(max_hp, 275.0)
	defense = maxf(defense, 4.0)
	armor = maxf(armor, 0.34)
	attack_damage = maxf(attack_damage, 16.0)
	speed = minf(speed, 2.35)
	if _health:
		_health.setup(max_hp, defense, armor)

func _build_visual() -> Dictionary:
	var r := Soldier.build(self, Color(0.18, 0.42, 0.16), false)
	return r

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
	if _deploying_ladder:
		_continue_deploying_ladder(delta)
		_idle(delta)
		return
	if _climbing:
		_continue_ladder_climb(delta)
		return
	if _on_wall:
		_fight_on_wall(delta)
		return
	if _ladder_deployed and not _on_wall:
		if _try_enter_deployed_ladder(delta):
			return
	if path.is_empty():
		return
	var tgt: Vector3 = path[mini(_wp, path.size() - 1)]
	var to := tgt - global_position
	to.y = 0.0
	var dist := to.length()
	var at_final_waypoint := _wp >= path.size() - 1
	if _carrying_ladder and path.size() > 1 and at_final_waypoint and dist <= DEPLOY_WORK_RADIUS:
		_try_deploy_crew_ladder()
		_idle(delta)
		return
	if _helping_crew_id != 0 and path.size() > 1 and at_final_waypoint and dist <= 2.8:
		_try_join_helped_ladder()
		_idle(delta)
		return
	if path.size() == 1:
		var defender := _nearest_wall_defender()
		if defender:
			var d := global_position.distance_to(defender.global_position)
			if d <= attack_range:
				_attack_unit(delta, defender)
				return
			if not _move_to_wall_defender(delta, defender):
				_wall_target = null
				_wall_nav_path.clear()
				_idle(delta)
			return
		elif dist <= 2.0:
			_move_towards_wall_point(_wall_pressure_point(), delta)
			return
	elif not at_final_waypoint and dist <= 2.5:
		_wp = mini(_wp + 1, path.size() - 1)
		return
	if dist < 0.001:
		return
	var dir := _avoidance_direction(to / dist)
	_move_direction(dir, delta)

func _nearest_defender() -> Node3D:
	var best: Node3D = null
	var bestd := 18.0 * 18.0
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

func _try_deploy_crew_ladder() -> void:
	if _ladder_deployed or _deploying_ladder or not _is_deployment_leader():
		return
	var ready := _ready_carriers_near_deploy_zone()
	if ready < MIN_CARRIERS_TO_DEPLOY:
		_request_ladder_help()
		return
	_start_deploying_ladder()

func _start_deploying_ladder() -> void:
	_deploying_ladder = true
	_deploy_t = 0.0
	for node in get_tree().get_nodes_in_group("ladder_carrier"):
		if node is LadderOrcEnemy and int(node.get_meta("crew_id", -1)) == _crew_id:
			var carrier := node as LadderOrcEnemy
			carrier._deploying_ladder = true
			carrier._deploy_t = 0.0
			carrier.velocity = Vector3.ZERO

func _continue_deploying_ladder(delta: float) -> void:
	if _ladder_deployed:
		_deploying_ladder = false
		return
	if not _is_deployment_leader():
		return
	if _ready_carriers_near_deploy_zone() < MIN_CARRIERS_TO_DEPLOY:
		_cancel_deploying_ladder()
		_request_ladder_help()
		return
	_deploy_t += delta
	for node in get_tree().get_nodes_in_group("ladder_carrier"):
		if node is LadderOrcEnemy and int(node.get_meta("crew_id", -1)) == _crew_id:
			(node as LadderOrcEnemy)._deploy_t = _deploy_t
	if _deploy_t < DEPLOY_DURATION:
		return
	_finish_deploying_ladder()

func _cancel_deploying_ladder() -> void:
	for node in get_tree().get_nodes_in_group("ladder_carrier"):
		if node is LadderOrcEnemy and int(node.get_meta("crew_id", -1)) == _crew_id:
			var carrier := node as LadderOrcEnemy
			carrier._deploying_ladder = false
			carrier._deploy_t = 0.0

func _finish_deploying_ladder() -> void:
	_ladder_deployed = true
	_spawn_siege_ladder()
	for node in get_tree().get_nodes_in_group("ladder_carrier"):
		if node is LadderOrcEnemy and int(node.get_meta("crew_id", -1)) == _crew_id:
			var carrier := node as LadderOrcEnemy
			carrier._ladder_deployed = true
			carrier._deploying_ladder = false
			carrier._deploy_t = 0.0
			carrier._carrying_ladder = false
			carrier.remove_from_group("ladder_carrier")
			carrier._ladder_prop = _ladder_prop
			carrier._wait_for_ladder_queue(_ladder_prop)
	for node in get_tree().get_nodes_in_group("ladder_helper"):
		if node is LadderOrcEnemy and int(node.get_meta("helping_crew_id", -1)) == _crew_id:
			var helper := node as LadderOrcEnemy
			helper._ladder_deployed = true
			helper._deploying_ladder = false
			helper._deploy_t = 0.0
			helper._helping_crew_id = 0
			helper.remove_from_group("ladder_helper")
			helper._ladder_prop = _ladder_prop
			helper._wait_for_ladder_queue(_ladder_prop)

func _ready_carriers_near_deploy_zone() -> int:
	var count := 0
	var deploy_target := _ladder_foot
	if path.size() > 0:
		deploy_target = path[mini(_wp, path.size() - 1)]
	for node in get_tree().get_nodes_in_group("ladder_carrier"):
		if not node is Node3D or not is_instance_valid(node):
			continue
		if int(node.get_meta("crew_id", -1)) != _crew_id:
			continue
		var carrier := node as Node3D
		if carrier.global_position.distance_to(_ladder_foot) <= DEPLOY_WORK_RADIUS:
			count += 1
		elif carrier.global_position.distance_to(deploy_target) <= DEPLOY_WORK_RADIUS:
			count += 1
		elif carrier.global_position.distance_to(global_position) <= DEPLOY_WORK_RADIUS:
			count += 1
	for node in get_tree().get_nodes_in_group("ladder_helper"):
		if not node is Node3D or not is_instance_valid(node):
			continue
		if int(node.get_meta("helping_crew_id", -1)) != _crew_id:
			continue
		if (node as Node3D).global_position.distance_to(_ladder_foot) <= DEPLOY_WORK_RADIUS:
			count += 1
	return count

func _request_ladder_help() -> void:
	for node in get_tree().get_nodes_in_group("ladder_helper"):
		if node is LadderOrcEnemy and int(node.get_meta("helping_crew_id", -1)) == _crew_id:
			return
	var best: LadderOrcEnemy = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("ladder"):
		if not node is LadderOrcEnemy or not is_instance_valid(node):
			continue
		var candidate := node as LadderOrcEnemy
		if candidate == self or candidate._done or candidate._climbing or candidate._carrying_ladder or candidate._ladder_deployed:
			continue
		if candidate._helping_crew_id != 0:
			continue
		var d := candidate.global_position.distance_squared_to(_ladder_foot)
		if d < best_dist:
			best_dist = d
			best = candidate
	if best:
		best._assist_ladder_crew(_crew_id, _ladder_foot, _ladder_top, _ladder_normal)

func _assist_ladder_crew(crew_id: int, foot: Vector3, top: Vector3, normal: Vector3) -> void:
	_helping_crew_id = crew_id
	_crew_id = crew_id
	_ladder_foot = foot
	_ladder_top = top
	_wall_goal = top
	_ladder_normal = normal.normalized() if normal.length() > 0.01 else Vector3(-1.0, 0.0, 0.0)
	_carrying_ladder = false
	_ladder_deployed = false
	var side := _ladder_normal.cross(Vector3.UP).normalized()
	if side.length() < 0.01:
		side = Vector3.FORWARD
	var queue := _ladder_foot + _ladder_normal * 3.2 + side * 1.6
	queue.y = _ladder_foot.y
	path = [queue, _ladder_foot + _ladder_normal * 1.8]
	path[1].y = _ladder_foot.y
	_wp = 0
	gate_wp = -1
	add_to_group("ladder_helper")
	set_meta("helping_crew_id", crew_id)

func _try_join_helped_ladder() -> void:
	for node in get_tree().get_nodes_in_group("siege_ladder_active"):
		if node is SiegeLadder and (node as SiegeLadder).foot.distance_to(_ladder_foot) <= 7.5:
			_ladder_deployed = true
			_helping_crew_id = 0
			remove_from_group("ladder_helper")
			_ladder_prop = node as Node3D
			_begin_crew_ladder_climb(get_physics_process_delta_time())
			return

func _begin_crew_ladder_climb(delta: float) -> void:
	var ladder := _ladder_prop
	if ladder == null or not is_instance_valid(ladder):
		for node in get_tree().get_nodes_in_group("siege_ladder_active"):
			if node is SiegeLadder and (node as SiegeLadder).foot.distance_to(_ladder_foot) <= 7.5:
				ladder = node
				_ladder_prop = node as Node3D
				break
	if ladder == null or not is_instance_valid(ladder):
		_climbing = false
		_climbing_ladder = false
		return
	var climb_speed := float(ladder.get("climb_speed")) if ladder.get("climb_speed") != null else 4.2
	var foot: Vector3 = ladder.get("foot") if ladder.get("foot") != null else _ladder_foot
	var top: Vector3 = ladder.get("top") if ladder.get("top") != null else _ladder_top
	if _approach_ladder_entry_or_climb(ladder, foot, top, climb_speed, delta):
		_climbing = _climbing_ladder
		_wall_goal = top
	else:
		_wait_for_ladder_queue(ladder)
		_climbing = false
		_climbing_ladder = false

func _try_enter_deployed_ladder(delta: float) -> bool:
	var ladder := _ladder_prop
	if ladder == null or not is_instance_valid(ladder):
		for node in get_tree().get_nodes_in_group("siege_ladder_active"):
			if node is SiegeLadder and (node as SiegeLadder).foot.distance_to(_ladder_foot) <= 7.5:
				ladder = node
				_ladder_prop = node as Node3D
				break
	if ladder == null or not is_instance_valid(ladder):
		return false
	_begin_crew_ladder_climb(delta)
	_idle(delta)
	return true

func _wait_for_ladder_queue(ladder: Node) -> void:
	if ladder != null and is_instance_valid(ladder) and _ladder_brain != null and _ladder_brain.has_method("entry_point"):
		path = [_ladder_brain.call("entry_point", ladder, self)]
	elif ladder != null and is_instance_valid(ladder) and ladder.has_method("entry_point_for_unit"):
		path = [ladder.call("entry_point_for_unit", self)]
	else:
		path = [_ladder_foot + _ladder_normal * 0.65]
	_wp = 0

func _on_traversal_completed(kind: StringName, landing: Vector3) -> void:
	super(kind, landing)
	if kind != &"ladder":
		return
	_climbing = false
	_wall_goal = landing
	path = [landing]
	_wp = 0

func _on_traversal_failed(kind: StringName, reason: String) -> void:
	super(kind, reason)
	if kind != &"ladder":
		return
	_climbing = false

func _is_deployment_leader() -> bool:
	var leader_index := 9999
	for node in get_tree().get_nodes_in_group("ladder_carrier"):
		if not node is LadderOrcEnemy or not is_instance_valid(node):
			continue
		var carrier := node as LadderOrcEnemy
		if int(carrier.get_meta("crew_id", -1)) != _crew_id:
			continue
		if carrier._done or carrier._ladder_deployed:
			continue
		leader_index = mini(leader_index, carrier._crew_index)
	return _crew_index == leader_index

func _spawn_siege_ladder() -> void:
	if _ladder_prop and is_instance_valid(_ladder_prop):
		return
	if _carried_ladder_visual and is_instance_valid(_carried_ladder_visual):
		_carried_ladder_visual.queue_free()
		_carried_ladder_visual = null
	_ladder_prop = SIEGE_LADDER.instantiate()
	_ladder_prop.name = "SiegeLadder_%s" % _crew_id
	var root := get_tree().current_scene if get_tree().current_scene else get_parent()
	root.add_child(_ladder_prop)
	_ladder_prop.call("deploy", _ladder_foot, _ladder_top, _ladder_normal)

func _build_carried_ladder_visual() -> void:
	if _carried_ladder_visual and is_instance_valid(_carried_ladder_visual):
		_carried_ladder_visual.queue_free()
	_carried_ladder_visual = Node3D.new()
	_carried_ladder_visual.name = "CarriedSiegeLadder"
	add_child(_carried_ladder_visual)
	var length := clampf(_ladder_foot.distance_to(_ladder_top), 12.0, 24.0)
	var wood := _carried_wood_material()
	_carried_ladder_visual.position = Vector3(0.0, 1.75, -2.0)
	_carried_ladder_visual.rotation.x = deg_to_rad(10.0)
	var rail_x := 0.42
	_add_local_ladder_beam(_carried_ladder_visual, Vector3(-rail_x, 0.0, -length * 0.5), Vector3(-rail_x, 0.0, length * 0.5), 0.12, wood)
	_add_local_ladder_beam(_carried_ladder_visual, Vector3(rail_x, 0.0, -length * 0.5), Vector3(rail_x, 0.0, length * 0.5), 0.12, wood)
	for i in 10:
		var z := lerpf(-length * 0.45, length * 0.45, float(i) / 9.0)
		_add_local_ladder_beam(_carried_ladder_visual, Vector3(-rail_x, 0.0, z), Vector3(rail_x, 0.0, z), 0.08, wood)

func _add_local_ladder_beam(root: Node3D, from: Vector3, to: Vector3, thickness: float, mat: Material) -> void:
	var beam := MeshInstance3D.new()
	var delta := to - from
	beam.mesh = _carried_beam_mesh()
	beam.scale = Vector3(thickness, thickness, maxf(0.01, delta.length()))
	beam.material_override = mat
	root.add_child(beam)
	beam.position = from.lerp(to, 0.5)
	delta.y = 0.0
	if absf(delta.x) > absf(delta.z):
		beam.rotation.y = PI * 0.5

static func _carried_beam_mesh() -> BoxMesh:
	if _shared_carried_beam_mesh == null:
		_shared_carried_beam_mesh = BoxMesh.new()
		_shared_carried_beam_mesh.size = Vector3.ONE
	return _shared_carried_beam_mesh

static func _carried_wood_material() -> StandardMaterial3D:
	if _shared_carried_wood_material == null:
		_shared_carried_wood_material = StandardMaterial3D.new()
		_shared_carried_wood_material.albedo_color = Color(0.42, 0.25, 0.11)
		_shared_carried_wood_material.roughness = 0.95
	return _shared_carried_wood_material

func _attack_unit(delta: float, defender: Node3D) -> void:
	_attack_target = defender
	_idle(delta)
	if _attack_comp == null:
		return
	_attack_comp.tick(delta)

func _on_attacked(damage: float) -> void:
	if _attack_target and is_instance_valid(_attack_target) and _attack_target.has_method("take_damage"):
		_attack_target.take_damage(damage, global_position)
