class_name GroundResolver
extends Node3D

const CollisionLayers := preload("res://scripts/core/collision_layers.gd")

@export var ground_ray_top: float = 90.0
@export var ground_ray_depth: float = 190.0
@export var spawn_height_offset: float = 1.5
@export var ground_skin: float = 0.15

var terrain: TerrainModule = null

func _ready() -> void:
	add_to_group("ground_resolver")

func setup(terrain_module: TerrainModule) -> void:
	terrain = terrain_module

func terrain_height(x: float, z: float) -> float:
	return terrain.height(x, z) if terrain else ground_y(x, z)

func ground_y(x: float, z: float) -> float:
	var hit := raycast_ground(Vector3(x, 0.0, z))
	if not hit.is_empty():
		return (hit.position as Vector3).y
	return terrain.height(x, z) if terrain else 0.0

func raycast_ground(point: Vector3, from_y: float = ground_ray_top, depth: float = ground_ray_depth) -> Dictionary:
	if not is_inside_tree():
		return {}
	var from := Vector3(point.x, from_y, point.z)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * depth)
	query.collision_mask = CollisionLayers.WORLD
	return get_world_3d().direct_space_state.intersect_ray(query)

func has_physics_ground(x: float, z: float) -> bool:
	return not raycast_ground(Vector3(x, 0.0, z)).is_empty()

func nearest_physics_ground(point: Vector3) -> Vector3:
	for offset in ground_search_offsets():
		var hit := raycast_ground(Vector3(point.x + offset.x, point.y, point.z + offset.y))
		if not hit.is_empty():
			return hit.position as Vector3
	return Vector3.INF

func valid_spawn_point(point: Vector3) -> Vector3:
	var ground := nearest_physics_ground(point)
	if ground != Vector3.INF:
		return Vector3(ground.x, ground.y + spawn_height_offset, ground.z)
	return Vector3(point.x, ground_y(point.x, point.z) + spawn_height_offset, point.z)

func grounded_point(point: Vector3, offset: float = ground_skin) -> Vector3:
	var hit := raycast_ground(point)
	if hit.is_empty():
		return Vector3(point.x, ground_y(point.x, point.z) + offset, point.z)
	var pos := hit.position as Vector3
	return Vector3(pos.x, pos.y + offset, pos.z)

func validate_physics_samples(samples: Array[Vector3]) -> bool:
	for sample in samples:
		if not has_physics_ground(sample.x, sample.z):
			return false
	return true

func has_floor_below(node: Node3D, up: float = 2.0, depth: float = 14.0) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var point := node.global_position
	return not raycast_ground(point, point.y + up, depth).is_empty()

func ground_search_offsets() -> Array[Vector2]:
	return [
		Vector2.ZERO,
		Vector2(0.0, -4.0), Vector2(0.0, 4.0), Vector2(-4.0, 0.0), Vector2(4.0, 0.0),
		Vector2(0.0, -8.0), Vector2(0.0, 8.0), Vector2(-8.0, 0.0), Vector2(8.0, 0.0),
		Vector2(-4.0, -4.0), Vector2(-4.0, 4.0), Vector2(4.0, -4.0), Vector2(4.0, 4.0),
		Vector2(0.0, -12.0), Vector2(0.0, 12.0), Vector2(-12.0, 0.0), Vector2(12.0, 0.0),
	]
