class_name SiegeDirector
extends Node3D

const CollisionLayers := preload("res://scripts/core/collision_layers.gd")

@export var assault_sector_count: int = 8

var spawn_centre: Vector3 = Vector3(248.0, 0.0, 500.0)
var spawn_spread: Vector3 = Vector3(6.0, 0.0, 30.0)
var terrain: TerrainModule = null
var ground_resolver: Node = null

var _ladder_lane: int = 0
var _assault_lane: int = 0
var _spawn_lane: int = 0
var _last_valid_slots: int = 0
var _last_rejected_slots: int = 0
var _assault_sectors: Array[Dictionary] = []
var _sectors_dirty: bool = true

func _ready() -> void:
	add_to_group("siege_director")

func setup(spawn_center_value: Vector3, spawn_spread_value: Vector3, terrain_module: TerrainModule, resolver: Node) -> void:
	spawn_centre = spawn_center_value
	spawn_spread = spawn_spread_value
	terrain = terrain_module
	ground_resolver = resolver
	_sectors_dirty = true

func reserve_ladder_slot() -> Node3D:
	var sectors := assault_sectors(true)
	if sectors.is_empty():
		sectors = assault_sectors(false)
	if sectors.is_empty():
		return null
	var sector := _sector_by_spread_order(sectors, _ladder_lane)
	_ladder_lane += 1
	return sector.get("slot", null) as Node3D

func pick_ladder_assault_point() -> Dictionary:
	var sectors := assault_sectors(false)
	if sectors.is_empty():
		var normal := Vector3(-1.0, 0.0, 0.0)
		var z := spawn_centre.z + (22.0 if _assault_lane % 2 == 0 else -22.0)
		_assault_lane += 1
		var foot := Vector3(288.0, _ground(288.0, z) + 0.15, z)
		return {"foot": foot, "approach": foot + normal * 14.0}
	var sector := _sector_by_spread_order(sectors, _assault_lane)
	_assault_lane += 1
	var normal: Vector3 = sector.get("normal", Vector3(-1.0, 0.0, 0.0))
	if normal.length() < 0.01:
		normal = Vector3(-1.0, 0.0, 0.0)
	normal = normal.normalized()
	var foot: Vector3 = sector.get("foot", spawn_centre)
	var top: Vector3 = sector.get("top", foot + Vector3.UP * 6.0)
	var side := normal.cross(Vector3.UP).normalized()
	if side.length() < 0.01:
		side = Vector3.FORWARD
	var lane_offset := randf_range(-4.0, 4.0)
	var lane_foot := foot + normal * randf_range(1.8, 3.8) + side * lane_offset
	var lane_top := resolved_ladder_landing(top + side * lane_offset, normal)
	return {
		"foot": lane_foot,
		"approach": foot + normal * randf_range(14.0, 22.0) + side * lane_offset,
		"top": lane_top,
	}

func next_wide_spawn_point() -> Vector3:
	var sectors := assault_sectors(false)
	if sectors.is_empty():
		return spawn_centre + Vector3(randf_range(-spawn_spread.x, spawn_spread.x), 0.0, randf_range(-spawn_spread.z, spawn_spread.z))
	var sector := _sector_by_spread_order(sectors, _spawn_lane)
	_spawn_lane += 1
	var spawn: Vector3 = sector.get("spawn", spawn_centre)
	return spawn + Vector3(randf_range(-1.8, 1.8), 0.0, randf_range(-1.8, 1.8))

func assault_sectors(require_free_ladder: bool = false) -> Array[Dictionary]:
	if _sectors_dirty or _assault_sectors.is_empty():
		_rebuild_assault_sectors()
	if not require_free_ladder:
		return _assault_sectors.duplicate(true)
	var free_sectors: Array[Dictionary] = []
	for sector in _assault_sectors:
		var slot := sector.get("slot", null) as Node3D
		if slot == null or not is_instance_valid(slot):
			continue
		if int(slot.get_meta("reserved_by", 0)) == 0:
			free_sectors.append(sector)
	return free_sectors

func role_for_kind(kind: String) -> String:
	match kind:
		"ram", "bossram":
			return "gate_engine"
		"archer":
			return "archer_cover"
		_:
			return "wall_assault"

func unit_order(kind: String, route: Array, gate_waypoint: int) -> Dictionary:
	var role := role_for_kind(kind)
	var order := {
		"kind": kind,
		"role": role,
		"spawn": next_wide_spawn_point(),
		"route": route,
		"gate_waypoint": gate_waypoint,
		"uses_wall_assault": role != "gate_engine",
	}
	if role != "gate_engine":
		var assault := pick_ladder_assault_point()
		order["approach"] = assault.get("approach", spawn_centre)
		order["foot"] = assault.get("foot", spawn_centre)
	return order

func ladder_crew_plan(crew_id: int) -> Dictionary:
	var slot := reserve_ladder_slot()
	var normal := Vector3(-1.0, 0.0, 0.0)
	var fallback_z := spawn_centre.z + (24.0 if crew_id % 2 == 0 else -24.0)
	var foot := Vector3(288.0, _ground(288.0, fallback_z) + 0.15, fallback_z)
	var top := Vector3(294.0, 22.0, fallback_z)
	if slot:
		foot = slot.get_meta("foot", foot)
		top = slot.get_meta("top", top)
		normal = slot.get_meta("normal", normal)
		slot.set_meta("reserved_by", crew_id)
	normal.y = 0.0
	if normal.length() < 0.01:
		normal = Vector3(-1.0, 0.0, 0.0)
	normal = normal.normalized()
	var side := normal.cross(Vector3.UP).normalized()
	if side.length() < 0.01:
		side = Vector3.FORWARD
	top = resolved_ladder_landing(top, normal)
	var crew_spawn := spawn_point_for_ladder_foot(foot, normal)
	return {
		"crew_id": crew_id,
		"slot": slot,
		"foot": foot,
		"top": top,
		"normal": normal,
		"side": side,
		"crew_spawn": crew_spawn,
	}

func ladder_carrier_order(plan: Dictionary, crew_index: int) -> Dictionary:
	var normal: Vector3 = plan.get("normal", Vector3(-1.0, 0.0, 0.0))
	var side: Vector3 = plan.get("side", Vector3.FORWARD)
	var crew_spawn: Vector3 = plan.get("crew_spawn", spawn_centre)
	return {
		"kind": "ladder_carrier",
		"role": "ladder_carrier",
		"crew_id": int(plan.get("crew_id", 0)),
		"crew_index": crew_index,
		"foot": plan.get("foot", spawn_centre),
		"top": plan.get("top", spawn_centre + Vector3.UP * 6.0),
		"normal": normal,
		"crew_spawn": crew_spawn,
		"spawn": crew_spawn + side * (-1.6 if crew_index % 2 == 0 else 1.6) + normal * (1.1 if crew_index < 2 else -1.1),
	}

func ladder_escort_order(plan: Dictionary, escort_index: int) -> Dictionary:
	var foot: Vector3 = plan.get("foot", spawn_centre)
	var normal: Vector3 = plan.get("normal", Vector3(-1.0, 0.0, 0.0))
	var side: Vector3 = plan.get("side", Vector3.FORWARD)
	var crew_spawn: Vector3 = plan.get("crew_spawn", spawn_centre)
	var cover_foot := foot + normal * randf_range(3.0, 5.0) + side * float(escort_index - 1) * 2.2
	var approach := crew_spawn + side * float(escort_index - 1) * 2.8
	cover_foot.y = foot.y
	approach.y = foot.y
	return {
		"kind": "ladder_escort",
		"role": "ladder_escort",
		"crew_id": int(plan.get("crew_id", 0)),
		"spawn": crew_spawn + side * float(escort_index - 1) * 2.4 - normal * 3.0,
		"approach": approach,
		"cover_foot": cover_foot,
	}

func spawn_point_for_ladder_foot(foot: Vector3, normal: Vector3) -> Vector3:
	normal.y = 0.0
	if normal.length() < 0.01:
		normal = Vector3(-1.0, 0.0, 0.0)
	normal = normal.normalized()
	var side := normal.cross(Vector3.UP).normalized()
	if side.length() < 0.01:
		side = Vector3.FORWARD
	var from_wall := normal * 36.0
	var anchor := foot + from_wall
	anchor.x = minf(anchor.x, spawn_centre.x + 18.0)
	anchor.z = clampf(anchor.z, spawn_centre.z - 44.0, spawn_centre.z + 44.0)
	anchor.y = 0.0
	for offset in _ground_search_offsets():
		var candidate := anchor + Vector3(offset.x, 0.0, offset.y)
		if _formation_anchor_has_ground(candidate, normal, side):
			return Vector3(candidate.x, 0.0, candidate.z)
	var valid_anchor := _nearest_physics_ground(anchor)
	if valid_anchor != Vector3.INF:
		return Vector3(valid_anchor.x, 0.0, valid_anchor.z)
	return anchor

func resolved_ladder_landing(top: Vector3, normal: Vector3) -> Vector3:
	normal.y = 0.0
	if normal.length() < 0.01:
		return top
	normal = normal.normalized()
	var offsets: Array[float] = [0.0, 0.8, 1.6, 2.4, 3.2, -0.8]
	for offset in offsets:
		var candidate: Vector3 = top - normal * offset
		var hit := _ground_hit(candidate.x, candidate.z, candidate.y + 5.0, 12.0)
		if not hit.is_empty():
			var pos := hit.position as Vector3
			if absf(pos.y - top.y) <= 2.2:
				return pos + Vector3.UP * 0.12
	return top

func debug_summary() -> String:
	return "lanes L:%d A:%d S:%d sectors:%d slots:%d rejected:%d" % [_ladder_lane, _assault_lane, _spawn_lane, assault_sectors(false).size(), _last_valid_slots, _last_rejected_slots]

func _ladder_slots(require_free: bool) -> Array[Node3D]:
	var slots: Array[Node3D] = []
	_last_rejected_slots = 0
	for node in _candidate_ladder_slot_nodes():
		if not node is Node3D or not is_instance_valid(node):
			_last_rejected_slots += 1
			continue
		var slot := node as Node3D
		if slot.get_meta("ladder_surface", &"") != &"wall":
			_last_rejected_slots += 1
			continue
		if require_free and int(slot.get_meta("reserved_by", 0)) != 0:
			_last_rejected_slots += 1
			continue
		if not _is_ladder_slot_accessible(slot):
			_last_rejected_slots += 1
			continue
		slots.append(slot)
	slots.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		var az := a.global_position.z - spawn_centre.z
		var bz := b.global_position.z - spawn_centre.z
		if absf(absf(az) - absf(bz)) > 0.1:
			return absf(az) < absf(bz)
		if signf(az) != signf(bz):
			return az > bz
		return a.global_position.x < b.global_position.x
	)
	_last_valid_slots = slots.size()
	return slots

func _rebuild_assault_sectors() -> void:
	_assault_sectors.clear()
	var slots := _ladder_slots(false)
	if not slots.is_empty():
		var limited_slots := _sample_slots_for_sector_count(slots)
		for slot_index in limited_slots.size():
			var slot := limited_slots[slot_index]
			var normal: Vector3 = slot.get_meta("normal", Vector3(-1.0, 0.0, 0.0))
			normal.y = 0.0
			if normal.length() < 0.01:
				normal = Vector3(-1.0, 0.0, 0.0)
			normal = normal.normalized()
			var foot: Vector3 = slot.get_meta("foot", slot.global_position)
			var top: Vector3 = slot.get_meta("top", foot + Vector3.UP * 6.0)
			_assault_sectors.append({
				"index": slot_index,
				"name": "wall_sector_%02d" % slot_index,
				"slot": slot,
				"foot": foot,
				"top": top,
				"normal": normal,
				"spawn": spawn_point_for_ladder_foot(foot, normal),
				"approach": foot + normal * 18.0,
				"z_min": foot.z - 4.0,
				"z_max": foot.z + 4.0,
			})
	else:
		_rebuild_fallback_assault_sectors()
	_sectors_dirty = false

func _rebuild_fallback_assault_sectors() -> void:
	var count: int = max(1, assault_sector_count)
	var center := spawn_centre
	var radius := maxf(spawn_spread.z, 30.0)
	var normal := Vector3(-1.0, 0.0, 0.0)
	var wall_x := spawn_centre.x + 40.0
	var model: Node = get_tree().get_first_node_in_group("castle_model")
	if model != null and model.has_method("region"):
		var wall_region: Dictionary = model.call("region", &"wall_front")
		var horizon_region: Dictionary = model.call("region", &"staging_horizon")
		if not wall_region.is_empty():
			center = wall_region.get("center", center)
			radius = maxf(float(wall_region.get("radius", radius)), radius)
			normal = wall_region.get("normal", normal)
			wall_x = center.x
		if not horizon_region.is_empty():
			var horizon_center: Vector3 = horizon_region.get("center", spawn_centre)
			center.z = horizon_center.z
	for sector_index in count:
		var fraction: float = 0.5 if count == 1 else float(sector_index) / float(count - 1)
		var z: float = center.z - radius + radius * 2.0 * fraction
		var foot := Vector3(wall_x, _ground(wall_x, z) + 0.15, z)
		_assault_sectors.append({
			"index": sector_index,
			"name": "fallback_sector_%02d" % sector_index,
			"slot": null,
			"foot": foot,
			"top": foot + Vector3.UP * 6.0,
			"normal": normal.normalized(),
			"spawn": spawn_point_for_ladder_foot(foot, normal),
			"approach": foot + normal.normalized() * 18.0,
			"z_min": z - radius / float(count),
			"z_max": z + radius / float(count),
		})

func _sample_slots_for_sector_count(slots: Array[Node3D]) -> Array[Node3D]:
	var ordered: Array[Node3D] = slots.duplicate()
	ordered.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.z < b.global_position.z
	)
	var max_count: int = min(ordered.size(), max(1, assault_sector_count))
	if ordered.size() <= max_count:
		return ordered
	var selected: Array[Node3D] = []
	for index in max_count:
		var source_index := int(round(float(index) * float(ordered.size() - 1) / float(max_count - 1)))
		selected.append(ordered[source_index])
	return selected

func _slot_by_spread_order(slots: Array[Node3D], lane: int) -> Node3D:
	if slots.is_empty():
		return null
	var ordered: Array[Node3D] = slots.duplicate()
	ordered.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.z < b.global_position.z
	)
	var spread: Array[Node3D] = []
	var left := 0
	var right := ordered.size() - 1
	while left <= right:
		spread.append(ordered[left])
		if right != left:
			spread.append(ordered[right])
		left += 1
		right -= 1
	return spread[lane % spread.size()]

func _sector_by_spread_order(sectors: Array[Dictionary], lane: int) -> Dictionary:
	if sectors.is_empty():
		return {}
	var ordered: Array[Dictionary] = sectors.duplicate(true)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var foot_a: Vector3 = a.get("foot", spawn_centre)
		var foot_b: Vector3 = b.get("foot", spawn_centre)
		return foot_a.z < foot_b.z
	)
	var spread: Array[Dictionary] = []
	var left := 0
	var right := ordered.size() - 1
	while left <= right:
		spread.append(ordered[left])
		if right != left:
			spread.append(ordered[right])
		left += 1
		right -= 1
	return spread[lane % spread.size()]

func _candidate_ladder_slot_nodes() -> Array:
	var model := get_tree().get_first_node_in_group("castle_model")
	if model != null and model.has_method("wall_ladder_slots"):
		var model_slots: Array = model.call("wall_ladder_slots")
		if not model_slots.is_empty():
			return model_slots
	return get_tree().get_nodes_in_group("castle_ladder_slot")

func _is_ladder_slot_accessible(slot: Node3D) -> bool:
	var foot: Vector3 = slot.get_meta("foot", slot.global_position)
	var normal: Vector3 = slot.get_meta("normal", Vector3(-1.0, 0.0, 0.0))
	normal.y = 0.0
	if normal.length() < 0.01:
		return false
	normal = normal.normalized()
	var to_spawn := spawn_centre - foot
	to_spawn.y = 0.0
	if to_spawn.length() < 0.01:
		return false
	if foot.x > 312.0:
		return false
	if absf(foot.z - spawn_centre.z) < 10.0:
		return false
	if absf(foot.z - spawn_centre.z) > 46.0:
		return false
	var field_base := _ground(spawn_centre.x, spawn_centre.z)
	if foot.y > field_base + 6.0:
		return false
	if terrain != null:
		var samples := [
			foot,
			foot + normal * 6.0,
			foot + normal * 14.0,
			foot + normal * 24.0,
			spawn_point_for_ladder_foot(foot, normal),
		]
		for sample in samples:
			if not _has_physics_ground(sample.x, sample.z):
				return false
		var previous_height: float = terrain.height(samples[0].x, samples[0].z)
		for i in range(1, samples.size()):
			var sample: Vector3 = samples[i]
			var height: float = terrain.height(sample.x, sample.z)
			if absf(height - previous_height) > 5.0:
				return false
			if height > field_base + 8.0:
				return false
			previous_height = height
	return true

func _formation_anchor_has_ground(anchor: Vector3, normal: Vector3, side: Vector3) -> bool:
	var samples: Array[Vector3] = [
		anchor,
		anchor + side * -1.6 + normal * 1.1,
		anchor + side * 1.6 + normal * 1.1,
		anchor + side * -1.6 - normal * 1.1,
		anchor + side * 1.6 - normal * 1.1,
		anchor - normal * 3.0,
		anchor + side * 2.4 - normal * 3.0,
		anchor - side * 2.4 - normal * 3.0,
	]
	for sample in samples:
		if not _has_physics_ground(sample.x, sample.z):
			return false
	return true

func _ground(x: float, z: float) -> float:
	return ground_resolver.ground_y(x, z) if ground_resolver else 0.0

func _ground_hit(x: float, z: float, from_y: float = 90.0, depth: float = 190.0) -> Dictionary:
	return ground_resolver.raycast_ground(Vector3(x, 0.0, z), from_y, depth) if ground_resolver else {}

func _has_physics_ground(x: float, z: float) -> bool:
	return ground_resolver.has_physics_ground(x, z) if ground_resolver else false

func _nearest_physics_ground(point: Vector3) -> Vector3:
	return ground_resolver.nearest_physics_ground(point) if ground_resolver else Vector3.INF

func _ground_search_offsets() -> Array[Vector2]:
	if ground_resolver:
		return ground_resolver.ground_search_offsets()
	return [Vector2.ZERO] as Array[Vector2]
