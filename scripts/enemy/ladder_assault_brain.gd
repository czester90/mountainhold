class_name LadderAssaultBrain
extends Node

const LADDER_SEARCH_RANGE := 120.0
const CLIMBER_PENALTY := 180.0
const ENTRY_PENALTY := 260.0
const QUEUE_PENALTY := 22.0
const PREFERRED_FOOT_WEIGHT := 0.35

var _last_ladder_name := "-"
var _last_reason := "idle"
var _last_queue := Vector3.INF

func choose_active_ladder(context: Node, body: Node3D, preferred_foot: Vector3 = Vector3.INF) -> Node:
	var best: Node = null
	var best_score := INF
	var best_available: Node = null
	var best_available_score := INF
	_last_reason = "no_ladder"
	_last_ladder_name = "-"
	_last_queue = Vector3.INF
	for ladder in _active_ladders(context):
		if not ladder is Node3D or not is_instance_valid(ladder):
			continue
		if ladder.has_method("is_deployed") and not bool(ladder.call("is_deployed")):
			continue
		var queue := queue_preview_point(ladder)
		var flat := queue - body.global_position
		flat.y = 0.0
		var distance := flat.length()
		if distance > LADDER_SEARCH_RANGE:
			continue
		var score := distance
		var available := true
		if ladder.has_method("active_climber_count"):
			score += float(ladder.call("active_climber_count")) * CLIMBER_PENALTY
		if ladder.has_method("entry_count"):
			score += float(ladder.call("entry_count")) * ENTRY_PENALTY
		if ladder.has_method("queue_count"):
			score += float(ladder.call("queue_count")) * QUEUE_PENALTY
		if ladder.has_method("can_reserve_entry") and not bool(ladder.call("can_reserve_entry", body)):
			available = false
			score += CLIMBER_PENALTY + ENTRY_PENALTY
		if preferred_foot != Vector3.INF and ladder.get("foot") != null:
			score += (ladder.get("foot") as Vector3).distance_to(preferred_foot) * PREFERRED_FOOT_WEIGHT
		if available and score < best_available_score:
			best_available_score = score
			best_available = ladder
		if score < best_score:
			best_score = score
			best = ladder
			_last_queue = queue
	if best_available != null:
		best = best_available
	if best != null:
		_last_reason = "ladder"
		_last_ladder_name = best.name
	return best

func queue_point(ladder: Node, unit: Node) -> Vector3:
	if ladder == null or not is_instance_valid(ladder):
		return Vector3.INF
	if ladder.has_method("queue_point_for_unit"):
		return ladder.call("queue_point_for_unit", unit)
	if ladder.has_method("queue_point"):
		return ladder.call("queue_point", unit.get_instance_id() % 8)
	return (ladder as Node3D).global_position if ladder is Node3D else Vector3.INF

func queue_preview_point(ladder: Node) -> Vector3:
	if ladder == null or not is_instance_valid(ladder):
		return Vector3.INF
	if ladder.has_method("queue_point"):
		return ladder.call("queue_point", 0)
	if ladder.get("foot") != null:
		return ladder.get("foot")
	return (ladder as Node3D).global_position if ladder is Node3D else Vector3.INF

func reserve_or_queue(ladder: Node, unit: Node) -> bool:
	if ladder == null or not is_instance_valid(ladder):
		_last_reason = "missing"
		return false
	if ladder.has_method("reserve_climb") and bool(ladder.call("reserve_climb", unit)):
		_last_reason = "reserved"
		return true
	_last_reason = "queued"
	return false

func reserve_entry(ladder: Node, unit: Node) -> bool:
	if ladder == null or not is_instance_valid(ladder):
		_last_reason = "missing"
		return false
	if ladder.has_method("reserve_entry") and bool(ladder.call("reserve_entry", unit)):
		_last_reason = "entry"
		return true
	if ladder.has_method("has_entry_reservation") and bool(ladder.call("has_entry_reservation", unit)):
		_last_reason = "entry"
		return true
	_last_reason = "queued"
	return false

func entry_point(ladder: Node, unit: Node = null) -> Vector3:
	if ladder == null or not is_instance_valid(ladder):
		return Vector3.INF
	if unit != null and ladder.has_method("entry_point_for_unit"):
		return ladder.call("entry_point_for_unit", unit)
	if ladder.has_method("entry_point"):
		return ladder.call("entry_point")
	if ladder.get("foot") != null:
		return ladder.get("foot")
	return (ladder as Node3D).global_position if ladder is Node3D else Vector3.INF

func debug_summary() -> String:
	return "%s ladder:%s queue:%s" % [_last_reason, _last_ladder_name, _last_queue]

func _active_ladders(context: Node) -> Array:
	if context == null or not context.is_inside_tree():
		return []
	var registry := context.get_tree().get_first_node_in_group("combat_registry")
	if registry != null and registry.has_method("active_ladders"):
		return registry.call("active_ladders")
	return context.get_tree().get_nodes_in_group("siege_ladder_active")
