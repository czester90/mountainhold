extends Node3D

## Enemy archer's projectile. Flies straight and, each physics step, raycasts from its previous to
## its next position — so it never tunnels, and it only deals damage on ACTUAL contact. It's aimed at
## where the target was AT FIRE TIME, so a defender who moves is missed (the arrow sails past for no
## damage — the visual miss now matches the outcome). Masonry (world) stops it, so cover protects.
## Hits the player (layer 5) and allies (layer 4); ignores other enemies.

const MASK := (1 << 0) | (1 << 3) | (1 << 4)   # world + allies + player

var _vel: Vector3 = Vector3.ZERO
var _dmg: float = 8.0
var _age: float = 0.0
var _prev: Vector3

static var _shaft_mesh: CylinderMesh
static var _wood_material: StandardMaterial3D

func _ready() -> void:
	_build_mesh()

func setup(from: Vector3, dir: Vector3, speed: float, dmg: float) -> void:
	global_position = from
	_prev = from
	_vel = dir.normalized() * speed
	_dmg = dmg
	look_at(from + dir, Vector3.UP)

func _build_mesh() -> void:
	_ensure_shared_assets()
	var shaft := MeshInstance3D.new()
	shaft.mesh = _shaft_mesh
	shaft.material_override = _wood_material
	shaft.rotation.x = PI * 0.5                       # point along -Z (forward)
	add_child(shaft)

func _ensure_shared_assets() -> void:
	if _shaft_mesh != null:
		return
	_shaft_mesh = CylinderMesh.new()
	_shaft_mesh.top_radius = 0.02
	_shaft_mesh.bottom_radius = 0.02
	_shaft_mesh.height = 0.8
	_wood_material = StandardMaterial3D.new()
	_wood_material.albedo_color = Color(0.2, 0.14, 0.08)

func _physics_process(delta: float) -> void:
	_age += delta
	if _age > 6.0:
		queue_free()
		return
	var next := global_position + _vel * delta
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(_prev, next)
	q.collision_mask = MASK
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		var t: Node = hit.get("collider")
		if t != null and not t.has_method("take_damage") and t.get_parent() != null:
			t = t.get_parent()                        # ally's collision lives on a child StaticBody
		if t != null and t.has_method("take_damage"):
			t.take_damage(_dmg, global_position - _vel.normalized() * 40.0)   # from_pos ~ back toward the archer
		queue_free()
		return
	_prev = global_position
	global_position = next
	if _vel.length() > 0.1:
		look_at(next + _vel, Vector3.UP)
