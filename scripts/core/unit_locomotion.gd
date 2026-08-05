class_name UnitLocomotion
extends Node

var _body: CharacterBody3D

func setup(body: CharacterBody3D) -> void:
	_body = body

func move_direction(direction: Vector3, move_speed: float, gravity: float, delta: float, face_direction: bool = true) -> Dictionary:
	if _body == null or not is_instance_valid(_body):
		return {"pre": Vector3.ZERO, "post": Vector3.ZERO, "moved": Vector3.ZERO}
	var flat_dir := direction
	flat_dir.y = 0.0
	if flat_dir.length() > 0.001:
		flat_dir = flat_dir.normalized()
	else:
		return idle(gravity, delta)
	_body.velocity.x = flat_dir.x * move_speed
	_body.velocity.z = flat_dir.z * move_speed
	_apply_gravity(gravity, delta)
	var pre := _body.global_position
	_body.move_and_slide()
	if face_direction:
		_body.rotation.y = atan2(flat_dir.x, flat_dir.z)
	return {"pre": pre, "post": _body.global_position, "moved": _body.global_position - pre}

func idle(gravity: float, delta: float) -> Dictionary:
	if _body == null or not is_instance_valid(_body):
		return {"pre": Vector3.ZERO, "post": Vector3.ZERO, "moved": Vector3.ZERO}
	_body.velocity.x = 0.0
	_body.velocity.z = 0.0
	_apply_gravity(gravity, delta)
	var pre := _body.global_position
	_body.move_and_slide()
	return {"pre": pre, "post": _body.global_position, "moved": _body.global_position - pre}

func stop() -> void:
	if _body == null or not is_instance_valid(_body):
		return
	_body.velocity = Vector3.ZERO

func _apply_gravity(gravity: float, delta: float) -> void:
	if _body.is_on_floor():
		if _body.velocity.y < 0.0:
			_body.velocity.y = -1.0
	else:
		_body.velocity.y -= gravity * delta
