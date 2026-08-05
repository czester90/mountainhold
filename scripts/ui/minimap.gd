class_name Minimap
extends Control

const UPDATE_INTERVAL := 0.25
const INNER_PAD := 10.0
const FIELD_PAD_X := 46.0
const BACK_PAD_X := 18.0
const Z_PAD := 26.0
const CASTLE_SCRIPT_DIR := "res://scripts/castle/modules/"

var _scene_root: Node = null
var _castle_modules: Array[Node3D] = []
var _bounds_min := Vector2(260.0, 450.0)
var _bounds_max := Vector2(390.0, 550.0)
var _refresh_t := 0.0
var _combat_registry: Node = null

func setup(scene_root: Node) -> void:
	_scene_root = scene_root
	_combat_registry = get_tree().get_first_node_in_group("combat_registry")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_castle_modules()
	_refresh_bounds()
	_refresh_t = randf_range(0.0, UPDATE_INTERVAL)
	queue_redraw()

func _process(delta: float) -> void:
	_refresh_t -= delta
	if _refresh_t > 0.0:
		return
	_refresh_t = UPDATE_INTERVAL
	if _castle_modules.is_empty():
		_refresh_castle_modules()
	_refresh_bounds()
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.02, 0.025, 0.035, 0.78), true)
	draw_rect(rect, Color(0.62, 0.68, 0.80, 0.46), false, 1.5)
	_draw_grid()
	_draw_castle()
	_draw_units()
	_draw_legend()

func _draw_grid() -> void:
	var grid_color := Color(0.45, 0.52, 0.64, 0.13)
	for i in range(1, 4):
		var x := INNER_PAD + (size.x - INNER_PAD * 2.0) * float(i) / 4.0
		draw_line(Vector2(x, INNER_PAD), Vector2(x, size.y - INNER_PAD), grid_color, 1.0)
		var y := INNER_PAD + (size.y - INNER_PAD * 2.0) * float(i) / 4.0
		draw_line(Vector2(INNER_PAD, y), Vector2(size.x - INNER_PAD, y), grid_color, 1.0)

func _draw_castle() -> void:
	for module in _castle_modules:
		if not is_instance_valid(module):
			continue
		var kind := _module_kind(module)
		if kind == "tower":
			_draw_module_circle(module, _def_float(module, "radius", 6.0), Color(0.46, 0.48, 0.54, 0.82))
		else:
			_draw_module_poly(module, _module_footprint(module), _module_color(kind))

func _draw_units() -> void:
	for enemy in _active_enemies():
		if enemy is Node3D and is_instance_valid(enemy) and _is_drawable_enemy(enemy as Node3D):
			_draw_enemy(enemy as Node3D)
	for ally in _active_allies():
		if ally is Node3D and is_instance_valid(ally):
			_draw_unit_dot(ally as Node3D, Color(0.30, 0.68, 1.0, 0.95), 3.5)
	var player := _active_player() as Node3D
	if player != null and is_instance_valid(player):
		_draw_player(player)

func _draw_enemy(enemy: Node3D) -> void:
	var pos := _world_to_map(enemy.global_position)
	if enemy.is_in_group("ram"):
		draw_rect(Rect2(pos - Vector2(5.0, 4.0), Vector2(10.0, 8.0)), Color(1.0, 0.48, 0.16, 0.95), true)
		draw_rect(Rect2(pos - Vector2(5.0, 4.0), Vector2(10.0, 8.0)), Color.BLACK, false, 1.0)
		return
	if enemy.is_in_group("ladder"):
		var tri := PackedVector2Array([pos + Vector2(0, -5), pos + Vector2(5, 5), pos + Vector2(-5, 5)])
		draw_colored_polygon(tri, Color(0.85, 0.33, 1.0, 0.95))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color.BLACK, 1.0)
		return
	var color := Color(1.0, 0.20, 0.18, 0.92)
	if _is_archer(enemy):
		color = Color(1.0, 0.12, 0.38, 0.95)
		draw_arc(pos, 6.0, 0.0, TAU, 18, Color(1.0, 0.55, 0.65, 0.55), 1.0)
	_draw_unit_dot(enemy, color, 3.5)

func _is_drawable_enemy(enemy: Node3D) -> bool:
	if not enemy.visible or not enemy.is_inside_tree():
		return false
	if enemy.has_method("is_active_enemy") and not bool(enemy.call("is_active_enemy")):
		return false
	if enemy.global_position.y < -6.0 or enemy.global_position.y > 80.0:
		return false
	return true

func _draw_player(player: Node3D) -> void:
	var pos := _world_to_map(player.global_position)
	var forward3 := -player.global_transform.basis.z
	var dir := _world_dir_to_map(forward3)
	if dir.length() < 0.001:
		dir = Vector2.RIGHT
	dir = dir.normalized()
	var side := Vector2(-dir.y, dir.x)
	var arrow := PackedVector2Array([
		pos + dir * 8.0,
		pos - dir * 5.5 + side * 4.5,
		pos - dir * 5.5 - side * 4.5,
	])
	draw_colored_polygon(arrow, Color(1.0, 0.86, 0.22, 0.98))
	draw_polyline(PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[0]]), Color.BLACK, 1.0)

func _draw_unit_dot(unit: Node3D, color: Color, radius: float) -> void:
	var pos := _world_to_map(unit.global_position)
	draw_circle(pos, radius + 1.0, Color(0.0, 0.0, 0.0, 0.70))
	draw_circle(pos, radius, color)

func _draw_legend() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(12, 18), "MAPA", HORIZONTAL_ALIGNMENT_LEFT, 80.0, 13, Color(0.92, 0.94, 1.0, 0.92))
	draw_circle(Vector2(14, size.y - 31), 3.5, Color(0.30, 0.68, 1.0, 0.95))
	draw_string(ThemeDB.fallback_font, Vector2(24, size.y - 27), "nasi", HORIZONTAL_ALIGNMENT_LEFT, 50.0, 11, Color(0.80, 0.88, 1.0, 0.88))
	draw_circle(Vector2(74, size.y - 31), 3.5, Color(1.0, 0.20, 0.18, 0.92))
	draw_string(ThemeDB.fallback_font, Vector2(84, size.y - 27), "wróg", HORIZONTAL_ALIGNMENT_LEFT, 50.0, 11, Color(1.0, 0.76, 0.72, 0.88))
	draw_rect(Rect2(Vector2(135, size.y - 35), Vector2(10, 8)), Color(1.0, 0.48, 0.16, 0.95), true)
	draw_string(ThemeDB.fallback_font, Vector2(150, size.y - 27), "taran", HORIZONTAL_ALIGNMENT_LEFT, 55.0, 11, Color(1.0, 0.78, 0.55, 0.88))

func _draw_module_poly(_module: Node3D, world_points: PackedVector3Array, color: Color) -> void:
	if world_points.size() < 3:
		return
	var points := PackedVector2Array()
	for point in world_points:
		points.append(_world_to_map(point))
	draw_colored_polygon(points, color)
	points.append(points[0])
	draw_polyline(points, Color(0.75, 0.78, 0.86, 0.62), 1.0)

func _draw_module_circle(module: Node3D, radius: float, color: Color) -> void:
	var centre := _world_to_map(module.global_position)
	var edge := _world_to_map(module.global_position + module.global_transform.basis.x.normalized() * radius)
	var map_radius := maxf(4.0, centre.distance_to(edge))
	draw_circle(centre, map_radius, color)
	draw_arc(centre, map_radius, 0.0, TAU, 24, Color(0.75, 0.78, 0.86, 0.62), 1.0)

func _refresh_castle_modules() -> void:
	_castle_modules.clear()
	var root := _scene_root if _scene_root != null else get_tree().current_scene
	if root != null:
		_collect_castle_modules(root)

func _collect_castle_modules(node: Node) -> void:
	if node is Node3D and _is_castle_module(node):
		_castle_modules.append(node as Node3D)
	for child in node.get_children():
		_collect_castle_modules(child)

func _is_castle_module(node: Node) -> bool:
	var script := node.get_script() as Script
	if script == null:
		return false
	var path := script.resource_path
	return path.begins_with(CASTLE_SCRIPT_DIR) and not path.ends_with("/castle_module.gd") and not path.ends_with("/terrain_module.gd")

func _module_kind(module: Node3D) -> String:
	var script := module.get_script() as Script
	if script == null:
		return ""
	return script.resource_path.get_file().get_basename()

func _module_color(kind: String) -> Color:
	if kind == "keep":
		return Color(0.58, 0.57, 0.66, 0.88)
	if kind == "gate_tower" or kind == "gatehouse":
		return Color(0.56, 0.53, 0.48, 0.90)
	if kind.contains("stair") or kind == "causeway":
		return Color(0.42, 0.42, 0.38, 0.68)
	return Color(0.43, 0.45, 0.51, 0.78)

func _module_footprint(module: Node3D) -> PackedVector3Array:
	var kind := _module_kind(module)
	if kind == "keep":
		return _rect_points(module, _def_float(module, "width", 18.0), _def_float(module, "depth", 12.0))
	if kind == "gate_tower":
		return _rect_points(module, _def_float(module, "length", 14.0), 7.2)
	if kind == "gatehouse":
		return _rect_points(module, _def_float(module, "length", 8.0), _def_float(module, "thickness", 3.0))
	if kind == "wall_segment":
		return _rect_points(module, _def_float(module, "length", 12.0), maxf(_def_float(module, "thickness", 2.6), _def_float(module, "walk_width", 3.4)))
	if kind == "wall_corner":
		var side := _def_float(module, "side", 4.5)
		return _rect_points(module, side, side)
	if kind == "causeway":
		return _rect_points(module, _def_float(module, "run", 18.0), _def_float(module, "width", 7.0))
	if kind == "stair_tower":
		return _rect_points(module, _node_float(module, "flight_run", 3.0) * 2.4, _node_float(module, "width", 2.4) + 1.8)
	if kind == "stone_stairs" or kind == "stairs":
		return _rect_points(module, _def_float(module, "total_rise", 6.0) * 2.0, _def_float(module, "width", 2.0) + 0.6)
	if kind == "cave":
		return _rect_points(module, _node_float(module, "width", 15.0), _node_float(module, "depth", 17.0))
	return _rect_points(module, 5.0, 5.0)

func _rect_points(module: Node3D, local_x: float, local_z: float) -> PackedVector3Array:
	var hx := local_x * 0.5
	var hz := local_z * 0.5
	return PackedVector3Array([
		module.global_transform * Vector3(-hx, 0.0, -hz),
		module.global_transform * Vector3(hx, 0.0, -hz),
		module.global_transform * Vector3(hx, 0.0, hz),
		module.global_transform * Vector3(-hx, 0.0, hz),
	])

func _refresh_bounds() -> void:
	var bounds: Array[Vector2] = [Vector2(INF, INF), Vector2(-INF, -INF)]
	for module in _castle_modules:
		if not is_instance_valid(module):
			continue
		if _module_kind(module) == "tower":
			_extend_bounds_point(bounds, module.global_position)
		for point in _module_footprint(module):
			_extend_bounds_point(bounds, point)
	var player := _active_player()
	if player is Node3D and is_instance_valid(player):
		_extend_bounds_point(bounds, (player as Node3D).global_position)
	for node in _active_enemies():
		if node is Node3D and is_instance_valid(node) and _is_drawable_enemy(node as Node3D):
			_extend_bounds_point(bounds, (node as Node3D).global_position)
	for node in _active_allies():
		if node is Node3D and is_instance_valid(node):
			_extend_bounds_point(bounds, (node as Node3D).global_position)
	var min_v := bounds[0]
	var max_v := bounds[1]
	if min_v.x == INF:
		min_v = Vector2(260.0, 450.0)
		max_v = Vector2(390.0, 550.0)
	_bounds_min = min_v - Vector2(FIELD_PAD_X, Z_PAD)
	_bounds_max = max_v + Vector2(BACK_PAD_X, Z_PAD)
	if _bounds_max.x - _bounds_min.x < 50.0:
		_bounds_max.x = _bounds_min.x + 50.0
	if _bounds_max.y - _bounds_min.y < 50.0:
		_bounds_max.y = _bounds_min.y + 50.0

func _extend_bounds_point(bounds: Array[Vector2], point: Vector3) -> void:
	var min_v := bounds[0]
	var max_v := bounds[1]
	min_v.x = minf(min_v.x, point.x)
	min_v.y = minf(min_v.y, point.z)
	max_v.x = maxf(max_v.x, point.x)
	max_v.y = maxf(max_v.y, point.z)
	bounds[0] = min_v
	bounds[1] = max_v

func _world_to_map(world: Vector3) -> Vector2:
	var usable := Vector2(maxf(1.0, size.x - INNER_PAD * 2.0), maxf(1.0, size.y - INNER_PAD * 2.0))
	var span := _bounds_max - _bounds_min
	var map_x := 1.0 - clampf((world.z - _bounds_min.y) / maxf(span.y, 0.001), 0.0, 1.0)
	var map_y := clampf((world.x - _bounds_min.x) / maxf(span.x, 0.001), 0.0, 1.0)
	return Vector2(INNER_PAD + map_x * usable.x, INNER_PAD + map_y * usable.y)

func _world_dir_to_map(world_dir: Vector3) -> Vector2:
	return Vector2(-world_dir.z, world_dir.x)

func _def_float(module: Node, property_name: String, fallback: float) -> float:
	var definition: Variant = module.get("definition")
	if definition == null:
		return _node_float(module, property_name, fallback)
	var value: Variant = definition.get(property_name)
	return float(value) if value != null else fallback

func _node_float(node: Node, property_name: String, fallback: float) -> float:
	var value: Variant = node.get(property_name)
	return float(value) if value != null else fallback

func _is_archer(unit: Node) -> bool:
	var type_value: Variant = unit.get("type_id")
	if type_value != null and str(type_value).contains("archer"):
		return true
	var role_value: Variant = unit.get("role")
	return role_value != null and int(role_value) == UnitStats.Role.ARCHER

func _registry() -> Node:
	if _combat_registry == null:
		_combat_registry = get_tree().get_first_node_in_group("combat_registry")
	return _combat_registry

func _active_enemies() -> Array:
	var registry := _registry()
	if registry != null and registry.has_method("active_enemies"):
		return registry.call("active_enemies")
	return get_tree().get_nodes_in_group("enemy")

func _active_allies() -> Array:
	var registry := _registry()
	if registry != null and registry.has_method("active_allies"):
		return registry.call("active_allies")
	return get_tree().get_nodes_in_group("ally")

func _active_player() -> Node:
	var registry := _registry()
	if registry != null and registry.has_method("player"):
		return registry.call("player")
	return get_tree().get_first_node_in_group("player")
