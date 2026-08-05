class_name TraversalController
extends Node

signal completed(kind: StringName, landing: Vector3)
signal failed(kind: StringName, reason: String)

const CollisionLayers := preload("res://scripts/core/collision_layers.gd")

var _body: CharacterBody3D
var _kind: StringName = &""
var _active := false
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _landing := Vector3.ZERO
var _speed := 4.0
var _t := 0.0
var _ladder: Node = null

func setup(body: CharacterBody3D) -> void:
	_body = body

func is_active() -> bool:
	return _active

func active_kind() -> StringName:
	return _kind if _active else &""

func start_ladder(ladder: Node, from: Vector3, to: Vector3, speed: float = 4.0) -> bool:
	if _body == null or not is_instance_valid(_body):
		return false
	if ladder == null or not is_instance_valid(ladder):
		return false
	if not _validate_ladder_segment(from, to):
		return false
	var landing := _resolve_landing(to)
	if landing.x >= 1.0e19:
		return false
	_kind = &"ladder"
	_active = true
	_from = from
	_to = to
	_landing = landing
	_speed = maxf(0.1, speed)
	_t = 0.0
	_ladder = ladder
	_body.velocity = Vector3.ZERO
	return true

func cancel(reason: String = "cancelled") -> void:
	if not _active:
		return
	var kind := _kind
	_release_ladder()
	_active = false
	_kind = &""
	failed.emit(kind, reason)

func physics_tick(delta: float) -> bool:
	if not _active:
		return false
	if _body == null or not is_instance_valid(_body):
		cancel("missing_body")
		return false
	if _kind == &"ladder":
		_tick_ladder(delta)
		return true
	cancel("unknown_kind")
	return false

func _tick_ladder(delta: float) -> void:
	if _ladder == null or not is_instance_valid(_ladder):
		cancel("missing_ladder")
		return
	if _ladder.has_method("is_deployed") and not bool(_ladder.call("is_deployed")):
		cancel("ladder_not_deployed")
		return
	var distance := maxf(1.0, _from.distance_to(_to))
	_t = minf(1.0, _t + delta * _speed / distance)
	var position := _from.lerp(_to, _t)
	_body.global_position = position
	_body.velocity = Vector3.ZERO
	var dir := _to - _from
	dir.y = 0.0
	if dir.length() > 0.01:
		_body.rotation.y = atan2(dir.x, dir.z)
	if _t >= 1.0:
		_finish(_landing)

func _finish(landing: Vector3) -> void:
	var kind := _kind
	_release_ladder()
	_active = false
	_kind = &""
	_body.global_position = landing
	_body.velocity = Vector3.ZERO
	completed.emit(kind, landing)

func _release_ladder() -> void:
	if _ladder != null and is_instance_valid(_ladder) and _ladder.has_method("release_climb"):
		_ladder.call("release_climb", _body)
	_ladder = null

func _validate_ladder_segment(from: Vector3, to: Vector3) -> bool:
	var delta := to - from
	var flat := Vector2(delta.x, delta.z).length()
	if flat < 0.8:
		return false
	if delta.y < 2.0:
		return false
	if delta.y / maxf(flat, 0.001) > 5.0:
		return false
	return true

func _resolve_landing(top: Vector3) -> Vector3:
	if _body == null or not is_instance_valid(_body) or _body.get_world_3d() == null:
		return Vector3.INF
	var from := top + Vector3.UP * 2.0
	var to := top - Vector3.UP * 5.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = CollisionLayers.WORLD
	var hit := _body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector3.INF
	var landing: Vector3 = hit.position
	if Vector2(landing.x - top.x, landing.z - top.z).length() > 1.25:
		return Vector3.INF
	return landing + Vector3.UP * 0.12
