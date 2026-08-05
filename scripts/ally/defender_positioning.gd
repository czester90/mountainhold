class_name DefenderPositioning
extends Node

const CollisionLayers := preload("res://scripts/core/collision_layers.gd")

const MAX_SLOT_DISTANCE := 42.0
const OCCUPIED_RADIUS := 1.35

func best_firing_slot(archer: Node3D, target: Node3D, muzzle_offset: Vector3, space: PhysicsDirectSpaceState3D) -> Node3D:
	if archer == null or target == null or not is_instance_valid(archer) or not is_instance_valid(target):
		return null
	var best: Node3D = null
	var best_score := INF
	for slot in _archer_slots(archer):
		if not _slot_available(slot, archer):
			continue
		var distance := archer.global_position.distance_to(slot.global_position)
		if distance > MAX_SLOT_DISTANCE:
			continue
		var muzzle := slot.global_position + muzzle_offset
		var aim := _visible_aim_point(space, muzzle, target)
		if aim.x >= 1.0e19:
			continue
		var priority := int(slot.get_meta("priority", 0))
		var target_distance := slot.global_position.distance_to(target.global_position)
		var gate_bonus := _gate_bonus(slot, target)
		var score := distance * 8.0 + target_distance * 0.25 + float(priority) * 35.0 - gate_bonus
		if score < best_score:
			best_score = score
			best = slot
	return best

func reserve_slot(archer: Node3D, slot: Node3D) -> bool:
	if archer == null or slot == null or not is_instance_valid(archer) or not is_instance_valid(slot):
		return false
	if not _slot_available(slot, archer):
		return false
	slot.set_meta("reserved_by", archer.get_instance_id())
	return true

func release_slot(archer: Node3D, slot: Node3D) -> void:
	if archer == null or slot == null or not is_instance_valid(slot):
		return
	if int(slot.get_meta("reserved_by", 0)) == archer.get_instance_id():
		slot.set_meta("reserved_by", 0)

func reserved_slot_count(context: Node) -> int:
	var count := 0
	for slot in _archer_slots(context):
		if is_instance_valid(slot) and int(slot.get_meta("reserved_by", 0)) != 0:
			count += 1
	return count

func visible_aim_point(space: PhysicsDirectSpaceState3D, from: Vector3, target: Node3D) -> Vector3:
	return _visible_aim_point(space, from, target)

func _archer_slots(context: Node) -> Array[Node3D]:
	var model := context.get_tree().get_first_node_in_group("castle_model")
	if model != null and model.has_method("archer_slots"):
		return model.call("archer_slots")
	var out: Array[Node3D] = []
	for node in context.get_tree().get_nodes_in_group("castle_tactical_slot_archer"):
		if node is Node3D and is_instance_valid(node):
			out.append(node as Node3D)
	return out

func _slot_available(slot: Node3D, archer: Node3D) -> bool:
	if slot == null or not is_instance_valid(slot):
		return false
	var reserved_by := int(slot.get_meta("reserved_by", 0))
	if reserved_by != 0 and reserved_by != archer.get_instance_id() and not _live_unit_ids(archer).has(reserved_by):
		slot.set_meta("reserved_by", 0)
		reserved_by = 0
	if reserved_by != 0 and reserved_by != archer.get_instance_id():
		return false
	for ally in _active_allies(archer):
		if ally == archer or not ally is Node3D or not is_instance_valid(ally):
			continue
		if (ally as Node3D).global_position.distance_to(slot.global_position) < OCCUPIED_RADIUS:
			return false
	return true

func _active_allies(context: Node) -> Array:
	var registry := context.get_tree().get_first_node_in_group("combat_registry")
	if registry != null and registry.has_method("active_allies"):
		return registry.call("active_allies")
	return context.get_tree().get_nodes_in_group("ally")

func _live_unit_ids(context: Node) -> Dictionary:
	var ids := {}
	var registry := context.get_tree().get_first_node_in_group("combat_registry")
	if registry != null:
		if registry.has_method("active_allies"):
			for ally in registry.call("active_allies"):
				if ally is Node and is_instance_valid(ally):
					ids[(ally as Node).get_instance_id()] = true
		if registry.has_method("active_enemies"):
			for enemy in registry.call("active_enemies"):
				if enemy is Node and is_instance_valid(enemy):
					ids[(enemy as Node).get_instance_id()] = true
		return ids
	for node in context.get_tree().get_nodes_in_group("ally"):
		if node is Node and is_instance_valid(node):
			ids[(node as Node).get_instance_id()] = true
	return ids

func _visible_aim_point(space: PhysicsDirectSpaceState3D, from: Vector3, target: Node3D) -> Vector3:
	var base := target.global_position
	for off: Vector3 in [Vector3.UP * 1.1, Vector3.UP * 1.65, Vector3.UP * 0.75, Vector3(0.35, 1.2, 0.0), Vector3(-0.35, 1.2, 0.0)]:
		var to := base + off
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = CollisionLayers.WORLD
		if space.intersect_ray(query).is_empty():
			return to
	return Vector3.INF

func _gate_bonus(slot: Node3D, target: Node3D) -> float:
	var target_pos := target.global_position
	var target_gate_dist := Vector2(target_pos.x - 285.0, target_pos.z - 500.0).length()
	if target_gate_dist > 22.0:
		return 0.0
	var slot_gate_dist := Vector2(slot.global_position.x - 285.0, slot.global_position.z - 500.0).length()
	return clampf(24.0 - slot_gate_dist, 0.0, 24.0) * 4.0
