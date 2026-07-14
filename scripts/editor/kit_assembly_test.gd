extends Node3D

## Validates how the loafbrr kit pieces assemble (wall + round tower + stairs)
## before rebuilding the fortress. Loads the kit at runtime, builds brick
## materials, places real kit pieces on flat ground. Free-fly camera.

const GLTF := "res://assets/raw/loafbrr_castle_wall_kit/gltf/CastleWallsKit.gltf"
const TEX_DIR := "res://assets/raw/loafbrr_castle_wall_kit/textures"

var _mats := {}
var _meshes := {}
var _cam: Camera3D
var _yaw := -0.7
var _pitch := 0.35
var _dist := 46.0
var _pivot := Vector3(16, 4, -3)

func _ready() -> void:
	_build_materials()
	_load_kit()
	_cam = $Camera
	_build()
	_update_cam()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _tex(p: String) -> ImageTexture:
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(p)) != OK:
		return null
	return ImageTexture.create_from_image(img)

func _brick(dir: String, tag: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var b := _tex("%s/%s/Base Color_%s.png" % [TEX_DIR, dir, tag])
	if b: m.albedo_texture = b
	var n := _tex("%s/%s/NORMAL_%s.png" % [TEX_DIR, dir, tag])
	if n: m.normal_enabled = true; m.normal_texture = n
	var mr := _tex("%s/%s/MRAO_%s.exr" % [TEX_DIR, dir, tag])
	if mr:
		m.metallic = 1.0; m.metallic_texture = mr; m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.roughness_texture = mr; m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		m.ao_enabled = true; m.ao_texture = mr; m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
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
		if n is MeshInstance3D and n.mesh:
			_meshes[String(n.name)] = n.mesh
		for c in n.get_children():
			stack.append(c)
	root.queue_free()

func _put(mesh_name: String, pos: Vector3, yaw_deg: float) -> void:
	var mesh = _meshes.get(mesh_name)
	if mesh == null:
		push_warning("missing " + mesh_name); return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	for i in mesh.get_surface_count():
		var sm = mesh.surface_get_material(i)
		mi.set_surface_override_material(i, _mats.get(sm.resource_name if sm else "", _mats["BrickWall"]))
	mi.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos)
	add_child(mi)

func _build() -> void:
	# --- straight wall: 4 x Courtine_Wall (6 m) along +X, floor walk + battlements on top
	for i in 4:
		_put("Courtine_Wall", Vector3(i * 6, 0, 0), 0)
		_put("Wall_Floor", Vector3(i * 6 + 3, 6, -3), 0)         # walk behind the wall
		_put("Wall_Battlements", Vector3(i * 6 + 3, 6, 0), 0)    # parapet on the front edge
	# --- round tower: 2 courses of 4 x Corner_Round drum + floor cap + battlement ring
	var tc := Vector3(30, 0, -3)
	for course in 2:
		for q in 4:
			_put("Wall_Corner_Round", tc + Vector3(0, course * 6, 0), q * 90)
	_put("Wall_Floor_Round", tc + Vector3(0, 12, 0), 0)
	for q in 4:
		_put("Wall_Battlements_Corner_Round", tc + Vector3(0, 12, 0), q * 90)
	# --- stairs piece seated on the ground, climbing toward the wall-walk
	_put("Stairs", Vector3(6, 0, -9), 0)
	_put("Stairs", Vector3(6, 0, -9), 90)
	_put("Stairs", Vector3(14, 0, -9), 180)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw -= event.relative.x * 0.005
		_pitch = clamp(_pitch - event.relative.y * 0.005, -1.4, 1.4)
		_update_cam()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_dist = max(6.0, _dist - 3.0); _update_cam()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_dist = min(120.0, _dist + 3.0); _update_cam()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()

func _update_cam() -> void:
	_cam.position = _pivot + Vector3(cos(_pitch) * sin(_yaw), sin(_pitch), cos(_pitch) * cos(_yaw)) * _dist
	_cam.look_at(_pivot, Vector3.UP)
