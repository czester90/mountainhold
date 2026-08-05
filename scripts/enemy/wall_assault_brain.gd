class_name WallAssaultBrain
extends Node

const CastlePathfinderScript := preload("res://scripts/castle/castle_pathfinder.gd")

const MAX_TARGET_RANGE := 120.0
const DIRECT_HEIGHT_DELTA := 3.2
const ROUTED_HEIGHT_DELTA := 18.0
const SLOT_SEARCH_RANGE := 160.0

var _pathfinder: Node = null
var _last_reason: String = "idle"
var _last_target_name: String = "-"
var _last_route_size: int = 0

func _ready() -> void:
	_ensure_pathfinder()

func route_to(context: Node, from: Vector3, to: Vector3) -> Array[Vector3]:
	_ensure_pathfinder()
	if _pathfinder == null:
		return []
	return _pathfinder.call("route", context, from, to)

func choose_defender(context: Node, body: Node3D) -> Node3D:
	var best: Node3D = null
	var best_score := INF
	_last_reason = "no_target"
	_last_target_name = "-"
	_last_route_size = 0
	for candidate in _defender_candidates(context):
		if not candidate is Node3D or not is_instance_valid(candidate):
			continue
		var defender := candidate as Node3D
		var delta := defender.global_position - body.global_position
		var flat_distance := Vector2(delta.x, delta.z).length()
		if flat_distance > MAX_TARGET_RANGE:
			continue
		var height_delta := absf(delta.y)
		var direct := height_delta <= DIRECT_HEIGHT_DELTA
		var route: Array[Vector3] = []
		var routed := false
		if not direct and height_delta <= ROUTED_HEIGHT_DELTA:
			route = route_to(context, body.global_position, defender.global_position)
			routed = not route.is_empty()
		if not direct and not routed:
			continue
		var score := flat_distance
		if routed:
			score = _route_length(body.global_position, route) * 0.85
		if direct:
			score *= 0.75
		if defender.is_in_group("player"):
			score *= 0.9
		if defender.global_position.y > body.global_position.y + 1.5:
			score *= 0.82
		if score < best_score:
			best_score = score
			best = defender
			_last_route_size = route.size()
	if best != null:
		_last_reason = "target"
		_last_target_name = best.name
	return best

func pressure_point(context: Node, body: Node3D) -> Vector3:
	var best := _nearest_tactical_point(context, body.global_position)
	if best.x < 1.0e19:
		_last_reason = "pressure_slot"
		return best
	var player := _active_player(context)
	if player is Node3D and is_instance_valid(player):
		_last_reason = "pressure_player"
		return (player as Node3D).global_position
	_last_reason = "pressure_hold"
	return body.global_position

func debug_summary() -> String:
	return "%s target:%s route:%d" % [_last_reason, _last_target_name, _last_route_size]

func _ensure_pathfinder() -> void:
	if _pathfinder != null and is_instance_valid(_pathfinder):
		return
	_pathfinder = CastlePathfinderScript.new()
	_pathfinder.name = "CastlePathfinder"
	add_child(_pathfinder)

func _defender_candidates(context: Node) -> Array:
	var result: Array = []
	if context == null or not context.is_inside_tree():
		return result
	var registry := _registry(context)
	if registry != null and registry.has_method("active_allies"):
		result.append_array(registry.call("active_allies"))
	else:
		result.append_array(context.get_tree().get_nodes_in_group("ally"))
	var player := _active_player(context)
	if player != null:
		result.append(player)
	return result

func _active_player(context: Node) -> Node:
	if context == null or not context.is_inside_tree():
		return null
	var registry := _registry(context)
	if registry != null and registry.has_method("player"):
		return registry.call("player")
	return context.get_tree().get_first_node_in_group("player")

func _registry(context: Node) -> Node:
	if context == null or not context.is_inside_tree():
		return null
	return context.get_tree().get_first_node_in_group("combat_registry")

func _nearest_tactical_point(context: Node, from: Vector3) -> Vector3:
	var best := Vector3(1.0e20, 1.0e20, 1.0e20)
	var best_score := INF
	for slot in _tactical_slots(context):
		if not slot is Node3D or not is_instance_valid(slot):
			continue
		var point := (slot as Node3D).global_position
		var distance := from.distance_to(point)
		if distance > SLOT_SEARCH_RANGE:
			continue
		var route := route_to(context, from, point)
		var routed_score := _route_length(from, route) if not route.is_empty() else distance
		var score := routed_score
		var slot_kind := str(slot.get_meta("slot_kind", ""))
		if slot_kind == "keep":
			score *= 0.75
		elif slot_kind == "gate":
			score *= 0.9
		elif slot_kind == "ladder":
			score *= 1.2
		if score < best_score:
			best_score = score
			best = point
	return best

func _tactical_slots(context: Node) -> Array:
	if context == null or not context.is_inside_tree():
		return []
	var model := context.get_tree().get_first_node_in_group("castle_model")
	if model != null and model.get("tactical_slots") != null:
		var slots: Array = model.get("tactical_slots")
		if not slots.is_empty():
			return slots
	return context.get_tree().get_nodes_in_group("castle_tactical_slot")

func _route_length(from: Vector3, route: Array[Vector3]) -> float:
	var total := 0.0
	var previous := from
	for point in route:
		total += previous.distance_to(point)
		previous = point
	return total
