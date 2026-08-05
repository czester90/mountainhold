class_name TargetingComponent
extends Node

## Reusable target picker: the nearest node in `group` within `sight_range` that has a clear line of
## sight (raycast against world layer 1 only, so walls/towers block but units don't). Pure logic —
## the host passes in its origin + scene tree + space state.

@export var sight_range: float = 70.0
@export var group: String = "enemy"
@export var aim_height: float = 1.0
@export var priority_point: Vector3 = Vector3(285.0, 0.0, 500.0)
@export var priority_radius: float = 18.0
@export var priority_weight: float = 0.35
@export var max_los_candidates: int = 8

var _perf_monitor: Node = null

func setup(p_range: float, p_group: String = "enemy") -> void:
	sight_range = p_range
	group = p_group

func acquire(origin: Vector3, tree: SceneTree, space: PhysicsDirectSpaceState3D) -> Node3D:
	var start_us := Time.get_ticks_usec()
	var cand: Array = []
	for e in _candidates(tree):
		if not is_instance_valid(e):
			continue
		if not e is Node3D:
			continue
		var d: float = origin.distance_squared_to((e as Node3D).global_position)
		if d < sight_range * sight_range:
			var score := d
			var ep := (e as Node3D).global_position
			if e.is_in_group("ladder") or Vector2(ep.x - priority_point.x, ep.z - priority_point.z).length() <= priority_radius:
				score *= priority_weight
			cand.append([score, e])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	for i in mini(cand.size(), max_los_candidates):
		var c: Array = cand[i]
		var e: Node3D = c[1]
		var aim := _visible_aim_point(space, origin, e)
		if aim.x < 1.0e19:
			_record_perf_us(&"targeting_component_acquire", start_us)
			return e
	_record_perf_us(&"targeting_component_acquire", start_us)
	return null

func visible_aim_point(origin: Vector3, target: Node3D, space: PhysicsDirectSpaceState3D) -> Vector3:
	return _visible_aim_point(space, origin, target)

func _visible_aim_point(space: PhysicsDirectSpaceState3D, from: Vector3, target: Node3D) -> Vector3:
	var base := target.global_position
	for off: Vector3 in [Vector3.UP * aim_height, Vector3.UP * 1.65, Vector3.UP * 0.75, Vector3(0.35, 1.2, 0), Vector3(-0.35, 1.2, 0)]:
		var to: Vector3 = base + off
		if _has_los(space, from, to):
			return to
	return Vector3.INF

func _has_los(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var start_us := Time.get_ticks_usec()
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	var clear := space.intersect_ray(q).is_empty()
	_record_perf_us(&"targeting_los_ray", start_us)
	return clear

func _candidates(tree: SceneTree) -> Array:
	var registry := tree.get_first_node_in_group("combat_registry")
	if registry != null:
		if group == "enemy" and registry.has_method("active_enemies"):
			return registry.call("active_enemies")
		if group == "ally" and registry.has_method("active_allies"):
			return registry.call("active_allies")
		if group == "ram" and registry.has_method("active_rams"):
			return registry.call("active_rams")
	return tree.get_nodes_in_group(group)

func _record_perf_us(key: StringName, start_us: int) -> void:
	if not is_inside_tree():
		return
	if _perf_monitor == null or not is_instance_valid(_perf_monitor):
		_perf_monitor = get_tree().get_first_node_in_group("perf_monitor")
	if _perf_monitor != null and _perf_monitor.has_method("record_us"):
		_perf_monitor.call("record_us", key, Time.get_ticks_usec() - start_us)
