extends Node3D

## Module lab: one wall run + one tower + one stair, on flat ground, to get the
## wall-walk -> tower connection and the stairs right before touching the fortress.
## Wall faces +Z (field); courtyard is -Z. Wall-walk at y = WALL_H, continuous onto
## the tower platform; battlements on the field side only; stair climbs to the walk.

const GLTF := "res://assets/raw/loafbrr_castle_wall_kit/gltf/CastleWallsKit.gltf"
const TEX_DIR := "res://assets/raw/loafbrr_castle_wall_kit/textures"
const WALL_H := 6.0
const WALL_THICK := 2.6
const TOWER_R := 4.0

var _mats := {}
var _meshes := {}
var _brick: StandardMaterial3D
var _floor: StandardMaterial3D

func _ready() -> void:
	_build_materials()
	_load_kit()
	_build()

func _tex(p: String) -> ImageTexture:
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(p)) != OK: return null
	return ImageTexture.create_from_image(img)

func _mk(dir: String, tag: String, tri: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var b := _tex("%s/%s/Base Color_%s.png" % [TEX_DIR, dir, tag])
	if b: m.albedo_texture = b
	var n := _tex("%s/%s/NORMAL_%s.png" % [TEX_DIR, dir, tag])
	if n: m.normal_enabled = true; m.normal_texture = n
	m.roughness = 1.0
	if tri:
		m.uv1_triplanar = true; m.uv1_world_triplanar = true; m.uv1_scale = Vector3(0.16, 0.16, 0.16)
	return m

func _build_materials() -> void:
	_mats["BrickWall"] = _mk("BrickWall", "BrickWall", false)
	_mats["BrickTrims"] = _mk("BrickTrims", "BrickTrims", false)
	_mats["BrickFloor"] = _mk("BrickFloor", "BrickFloor", false)
	_brick = _mk("BrickWall", "BrickWall", true)
	_floor = _mk("BrickFloor", "BrickFloor", true)

func _load_kit() -> void:
	var doc := GLTFDocument.new(); var st := GLTFState.new()
	doc.append_from_file(ProjectSettings.globalize_path(GLTF), st)
	var root := doc.generate_scene(st)
	var stack: Array = [root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D and n.mesh: _meshes[String(n.name)] = n.mesh
		for c in n.get_children(): stack.append(c)
	root.queue_free()

func _put(mesh_name: String, pos: Vector3, yaw: float, scale := Vector3.ONE) -> void:
	var mesh = _meshes.get(mesh_name)
	if mesh == null: return
	var mi := MeshInstance3D.new(); mi.mesh = mesh
	for i in mesh.get_surface_count():
		var sm = mesh.surface_get_material(i)
		mi.set_surface_override_material(i, _mats.get(sm.resource_name if sm else "", _mats["BrickWall"]))
	mi.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(scale), pos)
	add_child(mi)

func _box(c: Vector3, s: Vector3, yaw: float, mat: StandardMaterial3D) -> void:
	var b := BoxMesh.new(); b.size = s
	var mi := MeshInstance3D.new(); mi.mesh = b; mi.material_override = mat
	mi.transform = Transform3D(Basis(Vector3.UP, yaw), c); add_child(mi)

func _build() -> void:
	var tower_x := 18.0
	# --- wall run along +X, facing +Z, courtyard on -Z
	for i in 3:
		var x := i * 6.0
		_put("Courtine_Wall", Vector3(x, 0, 0), 0)                                  # field facing
		_box(Vector3(x + 3, WALL_H * 0.5, -WALL_THICK * 0.5), Vector3(6.1, WALL_H, WALL_THICK), 0, _brick)  # body
		_box(Vector3(x + 3, WALL_H + 0.15, -WALL_THICK * 0.5), Vector3(6.1, 0.3, WALL_THICK + 0.4), 0, _floor)  # walk
		_put("Wall_Battlements", Vector3(x + 3, WALL_H, 0), 0)                       # parapet on field edge
	# --- round tower at the wall's end, platform flush with the wall-walk
	var tc := Vector3(tower_x, 0, -WALL_THICK * 0.5)
	var cyl := CylinderMesh.new(); cyl.top_radius = TOWER_R; cyl.bottom_radius = TOWER_R; cyl.height = WALL_H
	var mi := MeshInstance3D.new(); mi.mesh = cyl; mi.material_override = _brick
	mi.position = Vector3(tc.x, WALL_H * 0.5, tc.z); add_child(mi)
	var cap := CylinderMesh.new(); cap.top_radius = TOWER_R; cap.bottom_radius = TOWER_R; cap.height = 0.3
	var ci := MeshInstance3D.new(); ci.mesh = cap; ci.material_override = _floor
	ci.position = Vector3(tc.x, WALL_H + 0.15, tc.z); add_child(ci)
	# merlon ring on the FIELD side only (open toward the wall-walk / courtyard)
	var n := 16
	for i in n:
		var a := TAU * float(i) / n
		# open the arc facing -X (toward the wall) and -Z (courtyard) so the walk enters
		if cos(a) < -0.3 or sin(a) < -0.5:
			continue
		var p := Vector3(tc.x + TOWER_R * cos(a), WALL_H + 0.9, tc.z + TOWER_R * sin(a))
		_box(p, Vector3(1.0, 1.4, 0.7), -a, _brick)
	# --- kit Stairs from courtyard floor up to the wall-walk (inner side, -Z)
	_put("Stairs", Vector3(6, 0, -8), PI, Vector3(1, 1, 1.5))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
