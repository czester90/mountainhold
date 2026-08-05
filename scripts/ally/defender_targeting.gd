class_name DefenderTargeting
extends Node

const ORDER_AUTO := 0
const ORDER_ATTACK_RAM := 1
const ORDER_ATTACK_ARCHERS := 2
const ORDER_ATTACK_CLOSEST := 3
const ORDER_DEFEND_GATE := 4
const ORDER_RETREAT_KEEP := 5
const GATE_KILL_POINT := Vector3(285.0, 0.0, 500.0)
const GATE_KILL_RADIUS := 20.0
const MAX_TARGET_CANDIDATES := 16

func acquire(archer: Node3D, targeting: TargetingComponent, order_mode: int, range: float, muzzle: Vector3) -> Dictionary:
	if archer == null or targeting == null or not is_instance_valid(archer):
		return _empty()
	var ordered := _acquire_order_target(archer, targeting, order_mode, range, muzzle)
	if ordered.get("target", null) != null:
		return ordered
	if _is_gate_defender(archer):
		var gate_target := _acquire_gate_threat(archer, range, muzzle)
		if gate_target != null:
			return {
				"target": gate_target,
				"aim": gate_target.global_position + Vector3.UP * 1.1,
				"has_los": false,
				"forced_gate": true,
			}
	return _acquire_by_filter(archer, targeting, range, muzzle, func(_enemy: Node3D) -> bool:
		return true
	)

func _acquire_order_target(archer: Node3D, targeting: TargetingComponent, order_mode: int, range: float, muzzle: Vector3) -> Dictionary:
	match order_mode:
		ORDER_ATTACK_RAM:
			return _acquire_by_filter(archer, targeting, range, muzzle, func(enemy: Node3D) -> bool:
				return enemy.is_in_group("ram")
			)
		ORDER_ATTACK_ARCHERS:
			return _acquire_by_filter(archer, targeting, range, muzzle, func(enemy: Node3D) -> bool:
				return _is_enemy_archer(enemy)
			)
		ORDER_ATTACK_CLOSEST:
			return _acquire_by_filter(archer, targeting, range, muzzle, func(_enemy: Node3D) -> bool:
				return true
			)
		ORDER_DEFEND_GATE:
			var gate_target := _acquire_gate_threat(archer, range, muzzle)
			if gate_target != null:
				return {
					"target": gate_target,
					"aim": gate_target.global_position + Vector3.UP * 1.1,
					"has_los": false,
					"forced_gate": true,
				}
		ORDER_RETREAT_KEEP:
			return _acquire_by_filter(archer, targeting, range, muzzle, func(enemy: Node3D) -> bool:
				return enemy.global_position.x >= 300.0
			)
	return _empty()

func _acquire_by_filter(archer: Node3D, targeting: TargetingComponent, range: float, muzzle: Vector3, accepts: Callable) -> Dictionary:
	var candidates := _scored_candidates(archer, range, muzzle, accepts)
	for i in mini(candidates.size(), MAX_TARGET_CANDIDATES):
		var enemy_3d: Node3D = candidates[i][1]
		return {"target": enemy_3d, "aim": enemy_3d.global_position + Vector3.UP * targeting.aim_height, "has_los": true, "forced_gate": false}
	return _empty()

func _scored_candidates(archer: Node3D, range: float, muzzle: Vector3, accepts: Callable) -> Array:
	var out := []
	var range_sq := range * range
	for enemy in _active_enemies_near(archer, muzzle, range):
		if not enemy is Node3D or not is_instance_valid(enemy):
			continue
		var enemy_3d := enemy as Node3D
		if not _same_scene_scope(archer, enemy_3d):
			continue
		if not accepts.call(enemy_3d):
			continue
		var dist_sq := muzzle.distance_squared_to(enemy_3d.global_position)
		if dist_sq > range_sq:
			continue
		var score := dist_sq
		if enemy_3d.is_in_group("ram"):
			score *= 0.4
		elif enemy_3d.is_in_group("ladder"):
			score *= 0.55
		out.append([score, enemy_3d])
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out

func _acquire_gate_threat(archer: Node3D, range: float, muzzle: Vector3) -> Node3D:
	var best: Node3D = null
	var best_score := INF
	for enemy in _active_enemies_near(archer, muzzle, range):
		if not enemy is Node3D or not is_instance_valid(enemy):
			continue
		var enemy_3d := enemy as Node3D
		if not _same_scene_scope(archer, enemy_3d):
			continue
		if muzzle.distance_squared_to(enemy_3d.global_position) > range * range:
			continue
		var ep := enemy_3d.global_position
		var gate_d := Vector2(ep.x - GATE_KILL_POINT.x, ep.z - GATE_KILL_POINT.z).length()
		if gate_d > GATE_KILL_RADIUS and not enemy_3d.is_in_group("ladder"):
			continue
		var score := gate_d * 20.0 + muzzle.distance_to(ep)
		if enemy_3d.is_in_group("ladder"):
			score *= 0.5
		if score < best_score:
			best_score = score
			best = enemy_3d
	return best

func _acquire_blocked_threat(archer: Node3D, range: float, muzzle: Vector3) -> Node3D:
	var best: Node3D = null
	var best_score := INF
	for enemy in _active_enemies_near(archer, muzzle, range):
		if not enemy is Node3D or not is_instance_valid(enemy):
			continue
		var enemy_3d := enemy as Node3D
		if not _same_scene_scope(archer, enemy_3d):
			continue
		var dist_sq := muzzle.distance_squared_to(enemy_3d.global_position)
		if dist_sq > range * range:
			continue
		var score := dist_sq
		if enemy_3d.is_in_group("ladder"):
			score *= 0.35
		if _is_gate_threat(enemy_3d):
			score *= 0.45
		if score < best_score:
			best_score = score
			best = enemy_3d
	return best

func _active_enemies(context: Node) -> Array:
	var registry := context.get_tree().get_first_node_in_group("combat_registry")
	if registry != null and registry.has_method("active_enemies"):
		return registry.call("active_enemies")
	return context.get_tree().get_nodes_in_group("enemy")

func _active_enemies_near(context: Node, point: Vector3, radius: float) -> Array:
	var registry := context.get_tree().get_first_node_in_group("combat_registry")
	if registry != null and registry.has_method("active_enemies_near"):
		return registry.call("active_enemies_near", point, radius)
	return _active_enemies(context)

func _is_gate_defender(archer: Node3D) -> bool:
	return archer.global_position.x >= 283.0 and archer.global_position.x <= 286.8 and absf(archer.global_position.z - GATE_KILL_POINT.z) <= 7.0

func _is_gate_threat(enemy: Node3D) -> bool:
	var pos := enemy.global_position
	return Vector2(pos.x - GATE_KILL_POINT.x, pos.z - GATE_KILL_POINT.z).length() <= GATE_KILL_RADIUS or enemy.is_in_group("ladder")

func _is_enemy_archer(enemy: Node3D) -> bool:
	var type_value: Variant = enemy.get("type_id")
	if type_value != null and str(type_value).contains("archer"):
		return true
	var role_value: Variant = enemy.get("role")
	return role_value != null and int(role_value) == UnitStats.Role.ARCHER

func _same_scene_scope(a: Node, b: Node) -> bool:
	return _scene_scope(a) == _scene_scope(b)

func _scene_scope(node: Node) -> Node:
	var scope := node
	while scope.get_parent() != null and scope.get_parent() != node.get_tree().root:
		scope = scope.get_parent()
	return scope

func _empty() -> Dictionary:
	return {"target": null, "aim": Vector3.INF, "has_los": false, "forced_gate": false}
