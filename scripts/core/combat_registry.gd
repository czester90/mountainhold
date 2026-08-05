class_name CombatRegistry
extends Node

const FALL_FLOOR := -20.0
const SKY_CEILING := 120.0
const GRID_CELL_SIZE := 14.0

var _enemies: Array[Node] = []
var _allies: Array[Node] = []
var _rams: Array[Node] = []
var _ladders: Array[Node] = []
var _player: Node = null
var _synced_frame: int = -1
var _grid_frame: int = -1
var _enemy_grid: Dictionary = {}
var _ally_grid: Dictionary = {}

func _ready() -> void:
	add_to_group("combat_registry")
	sync_from_groups()

func register_enemy(unit: Node) -> void:
	_register(_enemies, unit)
	if unit != null and unit.is_in_group("ram"):
		_register(_rams, unit)

func unregister_enemy(unit: Node) -> void:
	_unregister(_enemies, unit)
	_unregister(_rams, unit)

func register_ally(unit: Node) -> void:
	_register(_allies, unit)

func unregister_ally(unit: Node) -> void:
	_unregister(_allies, unit)

func register_ram(unit: Node) -> void:
	_register(_rams, unit)
	register_enemy(unit)

func unregister_ram(unit: Node) -> void:
	_unregister(_rams, unit)

func register_ladder(unit: Node) -> void:
	_register(_ladders, unit)

func unregister_ladder(unit: Node) -> void:
	_unregister(_ladders, unit)

func register_player(unit: Node) -> void:
	_player = unit

func player() -> Node:
	if _player == null or not is_instance_valid(_player) or not _is_active_player(_player):
		_player = get_tree().get_first_node_in_group("player")
	return _player if _player != null and _is_active_player(_player) else null

func active_enemies() -> Array[Node]:
	_sync_once_per_frame()
	return _enemies.duplicate()

func active_allies() -> Array[Node]:
	_sync_once_per_frame()
	return _allies.duplicate()

func active_rams() -> Array[Node]:
	_sync_once_per_frame()
	return _rams.duplicate()

func active_ladders() -> Array[Node]:
	_sync_once_per_frame()
	return _ladders.duplicate()

func active_enemies_near(point: Vector3, radius: float) -> Array[Node]:
	_sync_once_per_frame()
	_ensure_spatial_grid()
	return _units_near(_enemy_grid, point, radius)

func active_allies_near(point: Vector3, radius: float) -> Array[Node]:
	_sync_once_per_frame()
	_ensure_spatial_grid()
	return _units_near(_ally_grid, point, radius)

func active_units_near(point: Vector3, radius: float, include_enemies: bool = true, include_allies: bool = true, include_player: bool = true) -> Array[Node]:
	_sync_once_per_frame()
	_ensure_spatial_grid()
	var result: Array[Node] = []
	if include_enemies:
		result.append_array(_units_near(_enemy_grid, point, radius))
	if include_allies:
		result.append_array(_units_near(_ally_grid, point, radius))
	if include_player and _player != null and _is_active_player(_player) and _player is Node3D:
		var player_3d := _player as Node3D
		var flat := Vector2(player_3d.global_position.x - point.x, player_3d.global_position.z - point.z)
		if flat.length_squared() <= radius * radius:
			result.append(_player)
	return result

func prune_invalid() -> void:
	_prune(_enemies, "enemy")
	_prune(_allies, "ally")
	_prune(_rams, "ram")
	_prune(_ladders, "ladder")
	if _player != null and (not is_instance_valid(_player) or not _is_active_player(_player)):
		_player = null

func sync_from_groups() -> void:
	_sync_group("enemy", _enemies)
	_sync_group("ally", _allies)
	_sync_group("ram", _rams)
	_sync_group("siege_ladder_active", _ladders)
	_player = get_tree().get_first_node_in_group("player")
	prune_invalid()
	_synced_frame = _frame_key()
	_grid_frame = -1

func summary() -> Dictionary:
	return {
		"enemies": active_enemies().size(),
		"allies": active_allies().size(),
		"rams": active_rams().size(),
		"ladders": active_ladders().size(),
		"player": player() != null,
	}

func _register(list: Array[Node], unit: Node) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if list.has(unit):
		return
	list.append(unit)
	var callback := Callable(self, "_on_unit_tree_exiting").bind(unit)
	if not unit.tree_exiting.is_connected(callback):
		unit.tree_exiting.connect(callback, CONNECT_ONE_SHOT)

func _unregister(list: Array[Node], unit: Node) -> void:
	list.erase(unit)

func _on_unit_tree_exiting(unit: Node) -> void:
	_enemies.erase(unit)
	_allies.erase(unit)
	_rams.erase(unit)
	_ladders.erase(unit)
	if _player == unit:
		_player = null

func _sync_once_per_frame() -> void:
	var frame := _frame_key()
	if frame == _synced_frame:
		return
	_sync_group("enemy", _enemies)
	_sync_group("ally", _allies)
	_sync_group("ram", _rams)
	_sync_group("siege_ladder_active", _ladders)
	_sync_rams_from_enemies()
	prune_invalid()
	_synced_frame = frame
	_grid_frame = -1

func _frame_key() -> int:
	return Engine.get_process_frames() * 1000000 + Engine.get_physics_frames()

func _sync_group(group_name: StringName, list: Array[Node]) -> void:
	for node in get_tree().get_nodes_in_group(group_name):
		if node is Node:
			_register(list, node)

func _sync_rams_from_enemies() -> void:
	for enemy in _enemies:
		if is_instance_valid(enemy) and enemy.is_in_group("ram"):
			_register(_rams, enemy)
	_prune(_rams, "ram")

func _prune(list: Array[Node], kind: String) -> void:
	for i in range(list.size() - 1, -1, -1):
		if not _is_active(list[i], kind):
			list.remove_at(i)

func _is_active(unit: Node, kind: String) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	if unit.is_queued_for_deletion() or not unit.is_inside_tree():
		return false
	if kind == "enemy" or kind == "ram":
		return _is_active_enemy(unit)
	if kind == "ally":
		return _is_active_ally(unit)
	if kind == "ladder":
		return unit.visible
	return unit.visible

func _is_active_enemy(unit: Node) -> bool:
	if bool(unit.get_meta("staged_waiting", false)):
		return false
	if unit.has_method("is_active_enemy") and not bool(unit.call("is_active_enemy")):
		return false
	if not unit.visible:
		return false
	return _has_valid_world_position(unit)

func _is_active_ally(unit: Node) -> bool:
	if unit.has_method("is_active_ally"):
		return bool(unit.call("is_active_ally"))
	if not unit.visible:
		return false
	return _has_valid_world_position(unit)

func _is_active_player(unit: Node) -> bool:
	if unit.has_method("is_dead") and bool(unit.call("is_dead")):
		return false
	return unit.is_inside_tree() and unit.visible

func _has_valid_world_position(unit: Node) -> bool:
	if not unit is Node3D:
		return true
	var pos := (unit as Node3D).global_position
	return pos.y >= FALL_FLOOR and pos.y <= SKY_CEILING

func _ensure_spatial_grid() -> void:
	var frame := _frame_key()
	if frame == _grid_frame:
		return
	_enemy_grid.clear()
	_ally_grid.clear()
	for enemy in _enemies:
		_add_to_grid(_enemy_grid, enemy)
	for ally in _allies:
		_add_to_grid(_ally_grid, ally)
	_grid_frame = frame

func _add_to_grid(grid: Dictionary, unit: Node) -> void:
	if unit == null or not is_instance_valid(unit) or not unit is Node3D:
		return
	var pos := (unit as Node3D).global_position
	var key := _grid_key(pos)
	if not grid.has(key):
		grid[key] = []
	grid[key].append(unit)

func _units_near(grid: Dictionary, point: Vector3, radius: float) -> Array[Node]:
	var result: Array[Node] = []
	var radius_sq := radius * radius
	var min_cell := _grid_key(point - Vector3(radius, 0.0, radius))
	var max_cell := _grid_key(point + Vector3(radius, 0.0, radius))
	for gx in range(min_cell.x, max_cell.x + 1):
		for gz in range(min_cell.y, max_cell.y + 1):
			var key := Vector2i(gx, gz)
			if not grid.has(key):
				continue
			for unit in grid[key]:
				if not unit is Node3D or not is_instance_valid(unit):
					continue
				var pos := (unit as Node3D).global_position
				var flat := Vector2(pos.x - point.x, pos.z - point.z)
				if flat.length_squared() <= radius_sq:
					result.append(unit)
	return result

func _grid_key(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / GRID_CELL_SIZE), floori(point.z / GRID_CELL_SIZE))
