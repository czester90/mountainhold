extends RigidBody3D

## Ballistic arrow projectile. Fired with an initial velocity; gravity arcs it. On first contact
## it sticks (freezes) and despawns after a delay. Builds its own simple shaft+head mesh so it
## needs no authored art. Enemies (group "enemy") take a hit via the `hit` signal.

signal hit(body: Node)
signal recycle_requested(arrow: Node)

const CollisionLayers := preload("res://scripts/core/collision_layers.gd")

@export var life: float = 8.0
@export var damage: float = 55.0
var _stuck := false
var _age := 0.0
var _shooter: Node = null
var _pooled := false

static var _shaft_mesh: CylinderMesh
static var _head_mesh: CylinderMesh
static var _collision_shape: CapsuleShape3D
static var _wood_material: StandardMaterial3D
static var _steel_material: StandardMaterial3D

func _ready() -> void:
	gravity_scale = 1.0
	contact_monitor = true
	max_contacts_reported = 2
	continuous_cd = true
	# arrows live on their own layer (3) and only collide with the world (1) and enemies (2) —
	# NEVER with other arrows, otherwise each shot sticks to the previous one and builds a chain.
	collision_layer = CollisionLayers.PLAYER_ARROW
	collision_mask = CollisionLayers.PLAYER_ARROW_MASK
	_build_mesh()
	body_entered.connect(_on_body_entered)

func _build_mesh() -> void:
	_ensure_shared_assets()
	var shaft := MeshInstance3D.new()
	shaft.mesh = _shaft_mesh
	shaft.material_override = _wood_material
	shaft.rotation.x = PI * 0.5                       # cylinder is +Y; point it along -Z (forward)
	add_child(shaft)
	var head := MeshInstance3D.new()
	head.mesh = _head_mesh
	head.material_override = _steel_material
	head.rotation.x = PI * 0.5
	head.position = Vector3(0, 0, -0.5)
	add_child(head)
	var col := CollisionShape3D.new()
	col.shape = _collision_shape
	col.rotation.x = PI * 0.5
	add_child(col)

func _ensure_shared_assets() -> void:
	if _shaft_mesh != null:
		return
	_wood_material = StandardMaterial3D.new()
	_wood_material.albedo_color = Color(0.45, 0.30, 0.16)
	_steel_material = StandardMaterial3D.new()
	_steel_material.albedo_color = Color(0.6, 0.6, 0.65)
	_steel_material.metallic = 0.6
	_shaft_mesh = CylinderMesh.new()
	_shaft_mesh.top_radius = 0.012
	_shaft_mesh.bottom_radius = 0.012
	_shaft_mesh.height = 0.9
	_head_mesh = CylinderMesh.new()
	_head_mesh.top_radius = 0.0
	_head_mesh.bottom_radius = 0.03
	_head_mesh.height = 0.12
	_collision_shape = CapsuleShape3D.new()
	_collision_shape.radius = 0.03
	_collision_shape.height = 0.9

func launch(from: Transform3D, speed: float, shooter: Node = null) -> void:
	_reset_for_launch()
	global_transform = from
	# never collide with the archer that fired us (spawn point is right in front of the capsule)
	_shooter = shooter
	if shooter and shooter is CollisionObject3D:
		add_collision_exception_with(shooter)
	linear_velocity = -from.basis.z * speed           # -Z is forward

func mark_pooled() -> void:
	_pooled = true

func clear_hit_listeners() -> void:
	for connection in hit.get_connections():
		var callable: Callable = connection.get("callable", Callable())
		if callable.is_valid() and hit.is_connected(callable):
			hit.disconnect(callable)

func _physics_process(delta: float) -> void:
	_age += delta
	if _age > life:
		_despawn()
		return
	if not _stuck and linear_velocity.length() > 0.5:
		# point the arrow along its flight direction
		look_at(global_position + linear_velocity, Vector3.UP)

func _on_body_entered(body: Node) -> void:
	if _stuck or body == _shooter:
		return
	_stuck = true
	var target := _damage_target(body)
	# damage FIRST so `hit` listeners can tell a kill from a mere hit (the target is now dying/dead).
	# pass the hit height to enemies so a well-aimed shot (headshot / ram crew) does double.
	if target.has_method("take_damage_at"):
		target.take_damage_at(damage, global_position.y)
	elif target.has_method("take_damage"):
		target.take_damage(damage)
	emit_signal("hit", target)
	var au := get_node_or_null("/root/Audio")
	if au:
		au.play_3d("impact_body" if target.is_in_group("enemy") or target.is_in_group("siege_ladder") else "impact_env", global_position)
	if target.has_method("take_damage"):
		_despawn()
		return
	freeze = true
	await get_tree().create_timer(4.0).timeout
	_despawn()

func _reset_for_launch() -> void:
	_stuck = false
	_age = 0.0
	freeze = false
	sleeping = false
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	collision_layer = CollisionLayers.PLAYER_ARROW
	collision_mask = CollisionLayers.PLAYER_ARROW_MASK
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	if _shooter != null and is_instance_valid(_shooter) and _shooter is CollisionObject3D:
		remove_collision_exception_with(_shooter)
	_shooter = null

func _despawn() -> void:
	if _pooled:
		recycle_requested.emit(self)
	else:
		queue_free()

func _damage_target(body: Node) -> Node:
	if body == null:
		return self
	if body.has_method("take_damage") or body.has_method("take_damage_at"):
		return body
	var parent := body.get_parent()
	if parent != null and (parent.has_method("take_damage") or parent.has_method("take_damage_at")):
		return parent
	return body
