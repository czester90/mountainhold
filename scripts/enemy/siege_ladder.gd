class_name SiegeLadder
extends Node3D

signal destroyed(ladder: Node)

enum LadderState {
	CARRIED,
	DEPLOYING,
	DEPLOYED,
	OCCUPIED,
	DESTROYED,
	RELEASED,
}

@export var max_hp: float = 480.0
@export var climb_capacity: int = 3
@export var climb_speed: float = 4.2

const CollisionLayers := preload("res://scripts/core/collision_layers.gd")
const ENTRY_RESERVATION_TIMEOUT := 6.0
const CLIMB_LANE_SPACING := 0.55

static var _shared_beam_mesh: BoxMesh = null
static var _shared_wood_material: StandardMaterial3D = null

var hp: float = 480.0
var foot: Vector3 = Vector3.ZERO
var top: Vector3 = Vector3.ZERO
var normal: Vector3 = Vector3.FORWARD
var reserved_by: int = 0
var active_climbers: Dictionary = {}
var entry_reservations: Dictionary = {}
var queue_slots: Dictionary = {}
var landing_slots: Dictionary = {}
var climb_slots: Dictionary = {}

var _link: NavigationLink3D = null
var _body: StaticBody3D = null
var _visual: Node3D = null
var _deployed := false
var _state: LadderState = LadderState.CARRIED

func _ready() -> void:
	hp = max_hp
	add_to_group("siege_ladder")

func _process(delta: float) -> void:
	_tick_entry_reservations(delta)
	_prune_climbers()
	_prune_entry_reservations()
	_prune_queue_slots()

func deploy(foot_pos: Vector3, top_pos: Vector3, outward: Vector3) -> void:
	foot = foot_pos
	top = top_pos
	normal = outward.normalized() if outward.length() > 0.01 else Vector3.FORWARD
	_deployed = true
	_state = LadderState.DEPLOYED
	add_to_group("siege_ladder_active")
	global_position = Vector3.ZERO
	_build_visual()
	_build_collision()
	_build_link()

func is_deployed() -> bool:
	return _state == LadderState.DEPLOYED or _state == LadderState.OCCUPIED

func ladder_state() -> LadderState:
	_refresh_state_from_occupancy()
	return _state

func ladder_state_name() -> String:
	return _ladder_state_name(ladder_state())

func can_reserve_climb(unit: Node) -> bool:
	_prune_climbers()
	_prune_entry_reservations()
	if not _deployed or not is_instance_valid(unit):
		return false
	if entry_reservations.has(unit.get_instance_id()):
		return active_climbers.size() < climb_capacity
	return active_climbers.size() + entry_reservations.size() < climb_capacity

func can_reserve_entry(unit: Node) -> bool:
	_prune_climbers()
	_prune_entry_reservations()
	if not _deployed or not is_instance_valid(unit):
		return false
	if entry_reservations.has(unit.get_instance_id()):
		return true
	return active_climbers.size() + entry_reservations.size() < climb_capacity

func reserve_entry(unit: Node) -> bool:
	if not can_reserve_entry(unit):
		return false
	entry_reservations[unit.get_instance_id()] = {"unit": unit, "time": 0.0}
	queue_slots.erase(unit.get_instance_id())
	return true

func has_entry_reservation(unit: Node) -> bool:
	return unit != null and is_instance_valid(unit) and entry_reservations.has(unit.get_instance_id())

func release_entry(unit: Node) -> void:
	if unit:
		entry_reservations.erase(unit.get_instance_id())

func reserve_climb(unit: Node) -> bool:
	_prune_climbers()
	if not can_reserve_climb(unit):
		return false
	var id := unit.get_instance_id()
	active_climbers[id] = unit
	climb_slots[id] = _first_free_climb_slot()
	entry_reservations.erase(id)
	queue_slots.erase(id)
	_refresh_state_from_occupancy()
	return true

func release_climb(unit: Node) -> void:
	if unit:
		var id := unit.get_instance_id()
		active_climbers.erase(id)
		entry_reservations.erase(id)
		queue_slots.erase(id)
		climb_slots.erase(id)
	_refresh_state_from_occupancy()

func active_climber_count() -> int:
	_prune_climbers()
	return active_climbers.size()

func queue_count() -> int:
	_prune_queue_slots()
	return queue_slots.size()

func entry_count() -> int:
	_prune_entry_reservations()
	return entry_reservations.size()

func debug_summary() -> Dictionary:
	return {
		"name": name,
		"hp": hp,
		"capacity": climb_capacity,
		"climbing": active_climber_count(),
		"entry": entry_count(),
		"queued": queue_count(),
		"deployed": _deployed,
		"state": ladder_state_name(),
		"state_id": ladder_state(),
	}

func debug_unit_status(unit: Node) -> Dictionary:
	_prune_climbers()
	_prune_entry_reservations()
	_prune_queue_slots()
	var id := unit.get_instance_id() if unit != null and is_instance_valid(unit) else 0
	var queued := id != 0 and queue_slots.has(id)
	var climbing := id != 0 and active_climbers.has(id)
	var entry_reserved := id != 0 and entry_reservations.has(id)
	return {
		"name": name,
		"hp": hp,
		"deployed": _deployed,
		"capacity": climb_capacity,
		"active_climbers": active_climber_count(),
		"entry_reservations": entry_count(),
		"queued_units": queue_count(),
		"unit_climbing": climbing,
		"unit_entry_reserved": entry_reserved,
		"unit_queued": queued,
		"unit_queue_slot": int(queue_slots[id].get("slot", -1)) if queued and queue_slots[id] is Dictionary else -1,
		"unit_climb_slot": int(climb_slots[id]) if id != 0 and climb_slots.has(id) else -1,
		"state": ladder_state_name(),
		"state_id": ladder_state(),
		"foot": foot,
		"top": top,
	}

func _prune_climbers() -> void:
	for id in active_climbers.keys():
		var unit: Variant = active_climbers[id]
		if _should_prune_climber(unit):
			active_climbers.erase(id)
			climb_slots.erase(id)
	_refresh_state_from_occupancy()

func _tick_entry_reservations(delta: float) -> void:
	for id in entry_reservations.keys():
		if entry_reservations[id] is Dictionary:
			entry_reservations[id]["time"] = float(entry_reservations[id].get("time", 0.0)) + delta

func _prune_entry_reservations() -> void:
	for id in entry_reservations.keys():
		var entry: Variant = entry_reservations[id]
		var unit: Variant = entry.get("unit", null) if entry is Dictionary else entry
		var age := float(entry.get("time", 0.0)) if entry is Dictionary else 0.0
		if age > ENTRY_RESERVATION_TIMEOUT or not is_instance_valid(unit) or not unit is Node or (unit as Node).is_queued_for_deletion() or not (unit as Node).is_inside_tree():
			entry_reservations.erase(id)

func _prune_queue_slots() -> void:
	for id in queue_slots.keys():
		var unit: Variant = queue_slots[id].get("unit", null) if queue_slots[id] is Dictionary else null
		if not is_instance_valid(unit) or not unit is Node or (unit as Node).is_queued_for_deletion() or not (unit as Node).is_inside_tree():
			queue_slots.erase(id)

func _should_prune_climber(unit: Variant) -> bool:
	if not is_instance_valid(unit):
		return true
	if not unit is Node:
		return true
	var node := unit as Node
	if node.is_queued_for_deletion() or not node.is_inside_tree():
		return true
	if node.has_method("is_active_enemy") and not bool(node.call("is_active_enemy")):
		return true
	var climbing_state: Variant = node.get("_climbing_ladder")
	if climbing_state != null and not bool(climbing_state):
		var traversal := node.get_node_or_null("TraversalController")
		if traversal == null or not traversal.has_method("is_active") or not bool(traversal.call("is_active")):
			return true
	return false

func queue_point(index: int = 0) -> Vector3:
	var side := normal.cross(Vector3.UP).normalized()
	var row := index / 3
	var col_pattern := [-1.0, 0.0, 1.0]
	var col: float = col_pattern[index % col_pattern.size()]
	return foot + normal * (2.3 + float(row) * 1.65) + side * col * 1.45

func entry_point() -> Vector3:
	return foot + normal * 0.65

func entry_point_for_unit(unit: Node) -> Vector3:
	return foot + normal * 0.65 + side_offset_for_unit(unit)

func climb_points_for_unit(unit: Node) -> Dictionary:
	var offset := side_offset_for_unit(unit)
	return {
		"foot": foot + offset,
		"top": top + offset,
	}

func side_offset_for_unit(unit: Node) -> Vector3:
	var lane := _lane_for_unit(unit)
	var side := normal.cross(Vector3.UP).normalized()
	if side.length() < 0.01:
		side = Vector3.FORWARD
	var pattern := [0.0, -1.0, 1.0]
	return side * pattern[lane % pattern.size()] * CLIMB_LANE_SPACING

func landing_settle_point_for_unit(unit: Node) -> Vector3:
	_prune_landing_slots()
	if unit == null or not is_instance_valid(unit):
		return top
	var id := unit.get_instance_id()
	if not landing_slots.has(id):
		landing_slots[id] = {"unit": unit, "slot": _first_free_landing_slot()}
	return _landing_settle_point(int(landing_slots[id].get("slot", 0)))

func queue_point_for_unit(unit: Node) -> Vector3:
	_prune_queue_slots()
	if unit == null or not is_instance_valid(unit):
		return queue_point(0)
	var id := unit.get_instance_id()
	if not queue_slots.has(id):
		queue_slots[id] = {"unit": unit, "slot": _first_free_queue_slot()}
	return queue_point(int(queue_slots[id].get("slot", 0)))

func _first_free_queue_slot() -> int:
	var used := {}
	for value in queue_slots.values():
		if value is Dictionary:
			used[int(value.get("slot", 0))] = true
	for i in 18:
		if not used.has(i):
			return i
	return queue_slots.size()

func _first_free_climb_slot() -> int:
	var used := {}
	for value in climb_slots.values():
		used[int(value)] = true
	for i in climb_capacity:
		if not used.has(i):
			return i
	return climb_slots.size() % maxi(climb_capacity, 1)

func _lane_for_unit(unit: Node) -> int:
	if unit == null or not is_instance_valid(unit):
		return 0
	var id := unit.get_instance_id()
	if climb_slots.has(id):
		return int(climb_slots[id])
	if entry_reservations.has(id):
		return _lane_from_id(id)
	if queue_slots.has(id):
		return int(queue_slots[id].get("slot", 0)) % maxi(climb_capacity, 1)
	return _lane_from_id(id)

func _lane_from_id(id: int) -> int:
	return abs(id) % maxi(climb_capacity, 1)

func _prune_landing_slots() -> void:
	for id in landing_slots.keys():
		var unit: Variant = landing_slots[id].get("unit", null) if landing_slots[id] is Dictionary else null
		if not is_instance_valid(unit) or not unit is Node or (unit as Node).is_queued_for_deletion() or not (unit as Node).is_inside_tree():
			landing_slots.erase(id)

func _first_free_landing_slot() -> int:
	var used := {}
	for value in landing_slots.values():
		if value is Dictionary:
			used[int(value.get("slot", 0))] = true
	for i in 12:
		if not used.has(i):
			return i
	return landing_slots.size()

func _landing_settle_point(index: int) -> Vector3:
	var side := normal.cross(Vector3.UP).normalized()
	if side.length() < 0.01:
		side = Vector3.FORWARD
	var row := index / 3
	var col_pattern := [-1.0, 0.0, 1.0]
	var col: float = col_pattern[index % col_pattern.size()]
	return top - normal * (2.4 + float(row) * 0.75) + side * col * 0.85

func take_damage(amount: float, _from_pos: Vector3 = Vector3.INF) -> void:
	hp = maxf(0.0, hp - amount)
	if hp <= 0.0:
		_break()

func _break() -> void:
	_deployed = false
	_state = LadderState.DESTROYED
	remove_from_group("siege_ladder_active")
	if _link:
		_link.enabled = false
	destroyed.emit(self)
	queue_free()

func mark_released() -> void:
	_deployed = false
	_state = LadderState.RELEASED
	remove_from_group("siege_ladder_active")

func _refresh_state_from_occupancy() -> void:
	if _state == LadderState.DESTROYED or _state == LadderState.RELEASED:
		return
	if not _deployed:
		return
	_state = LadderState.OCCUPIED if active_climbers.size() > 0 else LadderState.DEPLOYED

func _ladder_state_name(state: LadderState) -> String:
	match state:
		LadderState.CARRIED:
			return "carried"
		LadderState.DEPLOYING:
			return "deploying"
		LadderState.DEPLOYED:
			return "deployed"
		LadderState.OCCUPIED:
			return "occupied"
		LadderState.DESTROYED:
			return "destroyed"
		LadderState.RELEASED:
			return "released"
	return "unknown"

func _build_link() -> void:
	if _link:
		_link.queue_free()
	_link = NavigationLink3D.new()
	_link.name = "LadderNavigationLink3D"
	add_child(_link)
	_link.global_position = (foot + top) * 0.5
	_link.start_position = _link.to_local(foot)
	_link.end_position = _link.to_local(top)
	_link.bidirectional = false
	_link.navigation_layers = CollisionLayers.ENEMY
	_link.add_to_group("ladder_navigation_link")
	_link.set_meta("kind", &"ladder")
	_link.set_meta("capacity", climb_capacity)
	_link.set_meta("ladder", get_path())

func _build_collision() -> void:
	if _body:
		_body.queue_free()
	_body = StaticBody3D.new()
	_body.name = "LadderBody"
	_body.collision_layer = CollisionLayers.LADDER_HITBOX
	_body.collision_mask = 0
	_body.add_to_group("siege_ladder_hitbox")
	add_child(_body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.85, 0.22, maxf(1.0, foot.distance_to(top)))
	shape.shape = box
	_body.add_child(shape)
	_body.global_position = foot.lerp(top, 0.5)
	_body.look_at(top, Vector3.UP)

func _build_visual() -> void:
	if _visual:
		_visual.queue_free()
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var wood := _wood_material()
	var side := normal.cross(Vector3.UP).normalized() * 0.34
	_add_beam(foot - side, top - side, 0.08, wood)
	_add_beam(foot + side, top + side, 0.08, wood)
	for i in 10:
		var t := float(i + 1) / 11.0
		_add_beam((foot - side).lerp(top - side, t), (foot + side).lerp(top + side, t), 0.055, wood)

func _add_beam(from: Vector3, to: Vector3, thickness: float, mat: Material) -> void:
	var beam := MeshInstance3D.new()
	beam.mesh = _beam_mesh()
	beam.scale = Vector3(thickness, thickness, maxf(1.0, from.distance_to(to)))
	beam.material_override = mat
	_visual.add_child(beam)
	beam.global_position = from.lerp(to, 0.5)
	beam.look_at(to, Vector3.UP)

static func _beam_mesh() -> BoxMesh:
	if _shared_beam_mesh == null:
		_shared_beam_mesh = BoxMesh.new()
		_shared_beam_mesh.size = Vector3.ONE
	return _shared_beam_mesh

static func _wood_material() -> StandardMaterial3D:
	if _shared_wood_material == null:
		_shared_wood_material = StandardMaterial3D.new()
		_shared_wood_material.albedo_color = Color(0.43, 0.27, 0.12)
		_shared_wood_material.roughness = 0.95
	return _shared_wood_material
