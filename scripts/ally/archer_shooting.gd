class_name ArcherShooting
extends Node

const ARROW := preload("res://scenes/player/arrow.tscn")
const CollisionLayers := preload("res://scripts/core/collision_layers.gd")
const ProjectilePoolScript := preload("res://scripts/core/projectile_pool.gd")
const PROJECTILE_GRAVITY := 9.8

var _perf_monitor: Node = null

func shoot(owner: Node3D, target: Node3D, target_point: Vector3, muzzle: Vector3, arrow_speed: float, arrow_damage: float, spread_deg: float) -> Dictionary:
	if owner == null or target == null or not is_instance_valid(owner) or not is_instance_valid(target):
		return {}
	var target_velocity: Vector3 = target.velocity if "velocity" in target else Vector3.ZERO
	var flight_time: float = maxf(0.05, muzzle.distance_to(target_point) / maxf(arrow_speed, 0.001))
	var aim := target_point + target_velocity * flight_time
	aim.y += 0.5 * PROJECTILE_GRAVITY * flight_time * flight_time
	var dir := aim - muzzle
	if dir.length() < 0.01:
		return {}
	var basis := Basis.looking_at(dir.normalized(), Vector3.UP)
	var spread := deg_to_rad(spread_deg)
	basis = basis.rotated(basis.y.normalized(), randf_range(-spread, spread)).rotated(basis.x.normalized(), randf_range(-spread, spread))
	var arrow := ProjectilePoolScript.acquire_player_arrow(owner)
	arrow.damage = arrow_damage
	arrow.launch(Transform3D(basis, muzzle), arrow_speed, owner)
	return {
		"arrow": arrow,
		"flight_time": flight_time,
		"aim": aim,
	}

func has_clear_ballistic_launch(owner: Node3D, target: Node3D, target_point: Vector3, muzzle: Vector3, arrow_speed: float) -> bool:
	if owner == null or target == null or not is_instance_valid(owner) or not is_instance_valid(target):
		return false
	var start_us := Time.get_ticks_usec()
	var target_velocity: Vector3 = target.velocity if "velocity" in target else Vector3.ZERO
	var flight_time: float = maxf(0.05, muzzle.distance_to(target_point) / maxf(arrow_speed, 0.001))
	var aim := target_point + target_velocity * flight_time
	aim.y += 0.5 * PROJECTILE_GRAVITY * flight_time * flight_time
	var velocity := (aim - muzzle).normalized() * arrow_speed
	var previous := muzzle
	var space := owner.get_world_3d().direct_space_state
	var steps := clampi(int(ceil(flight_time / 0.08)), 3, 18)
	for i in range(1, steps + 1):
		var t := flight_time * float(i) / float(steps)
		var current := muzzle + velocity * t + Vector3.DOWN * (0.5 * PROJECTILE_GRAVITY * t * t)
		var query := PhysicsRayQueryParameters3D.create(previous, current)
		query.collision_mask = CollisionLayers.WORLD
		var ray_start_us := Time.get_ticks_usec()
		var hit := space.intersect_ray(query)
		_record_perf_us(&"ally_ballistic_ray", ray_start_us)
		if not hit.is_empty():
			_record_perf_us(&"ally_ballistic_launch", start_us)
			return false
		previous = current
	_record_perf_us(&"ally_ballistic_launch", start_us)
	return true

func _record_perf_us(key: StringName, start_us: int) -> void:
	if not is_inside_tree():
		return
	if _perf_monitor == null or not is_instance_valid(_perf_monitor):
		_perf_monitor = get_tree().get_first_node_in_group("perf_monitor")
	if _perf_monitor != null and _perf_monitor.has_method("record_us"):
		_perf_monitor.call("record_us", key, Time.get_ticks_usec() - start_us)
