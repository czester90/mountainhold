class_name ProjectilePool
extends Node

const PLAYER_ARROW_SCENE := preload("res://scenes/player/arrow.tscn")
const MAX_PLAYER_ARROW_POOL := 96

static var _player_arrows: Array[Node] = []

static func acquire_player_arrow(owner: Node, parent: Node = null) -> Node:
	var arrow: Node = null
	while not _player_arrows.is_empty() and arrow == null:
		var candidate: Node = _player_arrows.pop_back()
		if is_instance_valid(candidate) and candidate.get_parent() == null:
			arrow = candidate
	if arrow == null:
		arrow = PLAYER_ARROW_SCENE.instantiate()
		if arrow.has_method("mark_pooled"):
			arrow.call("mark_pooled")
		if arrow.has_signal("recycle_requested"):
			var callback := Callable(ProjectilePool, "_recycle_player_arrow")
			if not arrow.is_connected("recycle_requested", callback):
				arrow.connect("recycle_requested", callback)
	if arrow.has_method("clear_hit_listeners"):
		arrow.call("clear_hit_listeners")
	var attach_parent := parent
	if attach_parent == null and owner != null:
		attach_parent = owner.get_tree().current_scene if owner.get_tree().current_scene else owner.get_parent()
	if attach_parent != null and arrow.get_parent() == null:
		attach_parent.add_child(arrow)
	return arrow

static func _recycle_player_arrow(arrow: Node) -> void:
	if arrow == null or not is_instance_valid(arrow):
		return
	if arrow is Node3D:
		(arrow as Node3D).visible = false
	if arrow is CollisionObject3D:
		var collision := arrow as CollisionObject3D
		collision.collision_layer = 0
		collision.collision_mask = 0
	if arrow is RigidBody3D:
		var body := arrow as RigidBody3D
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.sleeping = true
		body.freeze = true
	if arrow.get_parent() != null:
		arrow.get_parent().call_deferred("remove_child", arrow)
	_enqueue_player_arrow.call_deferred(arrow)

static func _enqueue_player_arrow(arrow: Node) -> void:
	if arrow == null or not is_instance_valid(arrow):
		return
	if _player_arrows.size() < MAX_PLAYER_ARROW_POOL:
		_player_arrows.append(arrow)
	else:
		arrow.queue_free()
