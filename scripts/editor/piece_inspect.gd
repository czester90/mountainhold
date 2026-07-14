extends Node3D

## Inspect individual kit corner/stair pieces to learn their true geometry, so
## the drum tower and stairs assemble correctly. Runtime GLTF load.

const GLTF := "res://assets/raw/loafbrr_castle_wall_kit/gltf/CastleWallsKit.gltf"
const TEX_DIR := "res://assets/raw/loafbrr_castle_wall_kit/textures"

var _mats := {}
var _meshes := {}

func _ready() -> void:
	_build_materials()
	_load_kit()
	# reference cubes at each test origin (red) to read pivots
	_marker(Vector3(0, 0, 0))
	_marker(Vector3(18, 0, 0))
	_marker(Vector3(40, 0, 0))
	_marker(Vector3(0, 0, 20))
	_marker(Vector3(20, 0, 20))
	# 1) single Wall_Corner_Round at origin
	_put("Wall_Corner_Round", Vector3(0, 0, 0), 0)
	# 2) drum attempt: 4 x Wall_Corner_Round, same centre, yaw 0/90/180/270
	for q in 4:
		_put("Wall_Corner_Round", Vector3(18, 0, 0), q * 90)
	# 3) drum attempt with Courtine_Corner_Round
	for q in 4:
		_put("Courtine_Corner_Round", Vector3(40, 0, 0), q * 90)
	# 4) single Courtine_Corner_Round
	_put("Courtine_Corner_Round", Vector3(0, 0, 20), 0)
	# 5) Stairs piece (to read climb direction)
	_put("Stairs", Vector3(20, 0, 20), 0)

func _marker(p: Vector3) -> void:
	var b := BoxMesh.new(); b.size = Vector3(0.6, 0.6, 0.6)
	var m := StandardMaterial3D.new(); m.albedo_color = Color(1, 0.2, 0.1)
	var mi := MeshInstance3D.new(); mi.mesh = b; mi.material_override = m; mi.position = p + Vector3(0, 0.3, 0)
	add_child(mi)

func _tex(p: String) -> ImageTexture:
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(p)) != OK: return null
	return ImageTexture.create_from_image(img)

func _brick(dir: String, tag: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var b := _tex("%s/%s/Base Color_%s.png" % [TEX_DIR, dir, tag])
	if b: m.albedo_texture = b
	m.roughness = 1.0
	return m

func _build_materials() -> void:
	_mats["BrickWall"] = _brick("BrickWall", "BrickWall")
	_mats["BrickTrims"] = _brick("BrickTrims", "BrickTrims")
	_mats["BrickFloor"] = _brick("BrickFloor", "BrickFloor")

func _load_kit() -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	doc.append_from_file(ProjectSettings.globalize_path(GLTF), state)
	var root := doc.generate_scene(state)
	var stack: Array = [root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D and n.mesh: _meshes[String(n.name)] = n.mesh
		for c in n.get_children(): stack.append(c)
	root.queue_free()

func _put(mesh_name: String, pos: Vector3, yaw_deg: float) -> void:
	var mesh = _meshes.get(mesh_name)
	if mesh == null: return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	for i in mesh.get_surface_count():
		var sm = mesh.surface_get_material(i)
		mi.set_surface_override_material(i, _mats.get(sm.resource_name if sm else "", _mats["BrickWall"]))
	mi.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos)
	add_child(mi)
