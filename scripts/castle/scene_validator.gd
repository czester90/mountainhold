class_name SceneValidator
extends RefCounted

## Formalises the ad-hoc probe/qa raycast checks into a reusable fortress-integrity validator.
## Each walk check casts a ray straight down at a point that MUST have a walkable surface at (or
## above) a minimum height — if the ray misses or hits low (bare ground / void), the structure has
## a gap or a floating/detached piece there. This directly guards the gate<->wall seam bug we hit.
## Ground checks assert terrain is present. Returns a list of human-readable issues (empty = OK).

## [label, x, z, min_y]  — a walk surface must exist at >= min_y here
const WALK_CHECKS := [
	["gate walk (courtyard junction)", 289.0, 492.0, 19.0],
	["gate walk (over passage, roofed)", 289.0, 500.0, 19.0],
	["gate walk (north junction)", 289.0, 508.0, 19.0],
	["rampart at mural-stair top", 293.0, 481.0, 19.0],
	["curtain rampart (mid run)", 290.0, 486.0, 19.0],
]

## [label, x, z]  — terrain/ground must exist here (not a hole in the world)
const GROUND_CHECKS := [
	["courtyard floor", 310.0, 500.0],
	["western field", 250.0, 500.0],
]

func validate(space: PhysicsDirectSpaceState3D, root: Node = null) -> Array:
	var issues: Array = []
	for c in WALK_CHECKS:
		var y: Variant = _walk_y_near(space, c[1], c[2])
		if y == null:
			issues.append("%s: NO surface (void/gap)" % c[0])
		elif float(y) < float(c[3]):
			issues.append("%s: surface y=%.1f below expected %.1f (gap/floating)" % [c[0], y, c[3]])
	for c in GROUND_CHECKS:
		if _ray(space, c[1], c[2]) == null:
			issues.append("%s: NO ground (hole in world)" % c[0])
	if root != null:
		issues.append_array(validate_model(_model_from(root)))
	return issues

func validate_model(model: Node) -> Array:
	var issues: Array = []
	if model == null:
		return ["castle_model: missing"]
	var summary: Dictionary = model.call("summary") if model.has_method("summary") else {}
	_require_count(issues, summary, "wall_ladder_slots", 4)
	_require_count(issues, summary, "tactical_slots", 8)
	_require_count(issues, summary, "navigation_edges", 8)
	_require_count(issues, summary, "navigation_links", int(summary.get("navigation_edges", 0)))
	_require_count(issues, summary, "navigation_regions", 1)
	for region_name in [&"wall_front", &"staging_horizon", &"ladder_zone", &"archer_band", &"gate", &"keep"]:
		var region: Dictionary = model.call("region", region_name) if model.has_method("region") else {}
		if region.is_empty():
			issues.append("region %s: missing" % str(region_name))
			continue
		if not region.has("center") or not region["center"] is Vector3:
			issues.append("region %s: missing center" % str(region_name))
		if not region.has("radius") or float(region["radius"]) <= 0.0:
			issues.append("region %s: invalid radius" % str(region_name))
	_validate_ladder_slots(issues, model.call("wall_ladder_slots") if model.has_method("wall_ladder_slots") else [])
	_validate_tactical_slots(issues, model.get("tactical_slots") if model.get("tactical_slots") != null else [])
	_validate_navigation_edges(issues, model.get("navigation_edges") if model.get("navigation_edges") != null else [])
	_validate_navigation_regions(issues, model.get("navigation_regions") if model.get("navigation_regions") != null else [])
	return issues

func _model_from(root: Node) -> Node:
	if root == null:
		return null
	if root.is_in_group("castle_model"):
		return root
	if root.is_inside_tree():
		return root.get_tree().get_first_node_in_group("castle_model")
	return null

func _require_count(issues: Array, summary: Dictionary, key: String, minimum: int) -> void:
	var value := int(summary.get(key, 0))
	if value < minimum:
		issues.append("%s: expected >= %d, got %d" % [key, minimum, value])

func _validate_ladder_slots(issues: Array, slots: Array) -> void:
	for slot in slots:
		if not slot is Node3D or not is_instance_valid(slot):
			issues.append("ladder_slot: invalid node")
			continue
		var slot_node := slot as Node3D
		if slot_node.get_meta("ladder_surface", &"") != &"wall":
			issues.append("%s: invalid ladder_surface" % slot_node.name)
		var foot: Variant = slot_node.get_meta("foot", null)
		var top: Variant = slot_node.get_meta("top", null)
		var normal: Variant = slot_node.get_meta("normal", null)
		if not foot is Vector3 or not top is Vector3:
			issues.append("%s: missing ladder foot/top" % slot_node.name)
		elif (top as Vector3).y <= (foot as Vector3).y:
			issues.append("%s: ladder top below foot" % slot_node.name)
		if not normal is Vector3 or (normal as Vector3).length() < 0.01:
			issues.append("%s: invalid ladder normal" % slot_node.name)

func _validate_tactical_slots(issues: Array, slots: Array) -> void:
	for slot in slots:
		if not slot is Node3D or not is_instance_valid(slot):
			issues.append("tactical_slot: invalid node")
			continue
		var slot_node := slot as Node3D
		if str(slot_node.get_meta("slot_kind", "")) == "":
			issues.append("%s: missing slot_kind" % slot_node.name)

func _validate_navigation_edges(issues: Array, edges: Array) -> void:
	for edge in edges:
		if edge == null or not is_instance_valid(edge):
			issues.append("navigation_edge: invalid node")
			continue
		if not edge.has_meta("nav_a") or not edge.has_meta("nav_b"):
			issues.append("%s: missing nav endpoints" % edge.name)
			continue
		var a: Variant = edge.get_meta("nav_a")
		var b: Variant = edge.get_meta("nav_b")
		if not a is Vector3 or not b is Vector3 or (a as Vector3).distance_to(b as Vector3) < 0.5:
			issues.append("%s: invalid nav endpoints" % edge.name)

func _validate_navigation_regions(issues: Array, regions: Array) -> void:
	for region in regions:
		if not region is NavigationRegion3D or not is_instance_valid(region):
			issues.append("navigation_region: invalid node")
			continue
		if (region as NavigationRegion3D).navigation_mesh == null:
			issues.append("%s: missing navigation_mesh" % (region as Node).name)

func _walk_y_near(space: PhysicsDirectSpaceState3D, x: float, z: float) -> Variant:
	var best: Variant = null
	for off in [Vector2.ZERO, Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(0.0, -1.0)]:
		var y: Variant = _ray(space, x + off.x, z + off.y)
		if y == null:
			continue
		if best == null or float(y) > float(best):
			best = y
	return best

func _ray(space: PhysicsDirectSpaceState3D, x: float, z: float) -> Variant:
	var from := Vector3(x, 60.0, z)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -90, 0))
	q.collision_mask = 1
	var r := space.intersect_ray(q)
	return r.position.y if r else null
