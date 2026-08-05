class_name ThreatEvaluator
extends RefCounted

static func distance_score(from: Vector3, target: Node3D) -> float:
	return from.distance_squared_to(target.global_position)

static func weighted_distance_score(from: Vector3, target: Node3D, ram_weight: float = 1.0, ladder_weight: float = 1.0) -> float:
	return distance_score(from, target) * role_weight(target, ram_weight, ladder_weight)

static func role_weight(target: Node3D, ram_weight: float = 1.0, ladder_weight: float = 1.0) -> float:
	if target.is_in_group("ram"):
		return ram_weight
	if target.is_in_group("ladder"):
		return ladder_weight
	return 1.0

static func flat_distance_to_point(pos: Vector3, point: Vector3) -> float:
	return Vector2(pos.x - point.x, pos.z - point.z).length()

static func is_near_flat_point(target: Node3D, point: Vector3, radius: float) -> bool:
	return flat_distance_to_point(target.global_position, point) <= radius

static func gate_threat_score(from: Vector3, target: Node3D, gate_point: Vector3, gate_distance_weight: float = 20.0, ladder_weight: float = 1.0) -> float:
	var target_pos := target.global_position
	var score := flat_distance_to_point(target_pos, gate_point) * gate_distance_weight + from.distance_to(target_pos)
	if target.is_in_group("ladder"):
		score *= ladder_weight
	return score

static func priority_distance_score(from: Vector3, target: Node3D, priority_point: Vector3, priority_radius: float, priority_weight: float) -> float:
	var score := distance_score(from, target)
	if target.is_in_group("ladder") or is_near_flat_point(target, priority_point, priority_radius):
		score *= priority_weight
	return score
