extends Node3D

## Loafbrr Castle Wall Kit catalog / inspection (not gameplay).
## Loads the kit gltf at RUNTIME via GLTFDocument (sidesteps the import system),
## builds PBR brick materials from the loose textures, lays every piece out on a
## grid over a 1 m reference floor with name + size labels, orbit/free-fly camera.
##
## Controls: RMB drag orbit | wheel zoom | WASD move pivot | R reset | Esc quit

const GLTF_PATH := "res://assets/raw/loafbrr_castle_wall_kit/gltf/CastleWallsKit.gltf"
const TEX_DIR := "res://assets/raw/loafbrr_castle_wall_kit/textures"
const COLUMNS := 10
const CELL := 8.0

@onready var _pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera

var _mats := {}
var _yaw := -0.6
var _pitch := 0.5
var _distance := 55.0
var _pivot_home: Vector3

func _ready() -> void:
	_build_materials()
	_build_catalog()
	_pivot_home = _pivot.position
	_update_camera()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _tex(path: String) -> ImageTexture:
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(path)) != OK:
		return null
	return ImageTexture.create_from_image(img)

func _brick(dir: String, tag: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var base := _tex("%s/%s/Base Color_%s.png" % [TEX_DIR, dir, tag])
	if base:
		m.albedo_texture = base
	var nrm := _tex("%s/%s/NORMAL_%s.png" % [TEX_DIR, dir, tag])
	if nrm:
		m.normal_enabled = true
		m.normal_texture = nrm
	var mrao := _tex("%s/%s/MRAO_%s.exr" % [TEX_DIR, dir, tag])
	if mrao:
		m.metallic = 1.0
		m.metallic_texture = mrao
		m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.roughness_texture = mrao
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		m.ao_enabled = true
		m.ao_texture = mrao
		m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	m.roughness = 1.0
	return m

func _build_materials() -> void:
	_mats["BrickWall"] = _brick("BrickWall", "BrickWall")
	_mats["BrickTrims"] = _brick("BrickTrims", "BrickTrims")
	_mats["BrickFloor"] = _brick("BrickFloor", "BrickFloor")
	var sticker := StandardMaterial3D.new()
	sticker.albedo_color = Color(0.3, 0.22, 0.15)
	_mats["WallStickers"] = sticker

func _load_kit() -> Node:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(GLTF_PATH), state) != OK:
		push_error("GLTF load failed")
		return null
	return doc.generate_scene(state)

func _apply_mats(mi: MeshInstance3D) -> void:
	for i in mi.mesh.get_surface_count():
		var sm := mi.mesh.surface_get_material(i)
		var key := sm.resource_name if sm else ""
		mi.set_surface_override_material(i, _mats.get(key, _mats["BrickWall"]))

func _build_catalog() -> void:
	var kit := _load_kit()
	if kit == null:
		return
	var pieces: Array[MeshInstance3D] = []
	var stack: Array[Node] = [kit]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			pieces.append(n)
		for c in n.get_children():
			stack.append(c)
	pieces.sort_custom(func(a, b): return String(a.name) < String(b.name))

	var grid := Node3D.new()
	grid.name = "Grid"
	add_child(grid)
	var origin_x := -(float(COLUMNS) - 1.0) * CELL * 0.5
	for i in pieces.size():
		var src: MeshInstance3D = pieces[i]
		var col := i % COLUMNS
		var row := i / COLUMNS
		_place(grid, src, Vector3(origin_x + col * CELL, 0.0, 4.0 + row * CELL))
	kit.queue_free()

func _place(parent: Node3D, src: MeshInstance3D, cell: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = cell
	parent.add_child(holder)
	var mi := MeshInstance3D.new()
	mi.mesh = src.mesh
	holder.add_child(mi)
	_apply_mats(mi)
	var aabb := src.mesh.get_aabb()
	var c := aabb.position + aabb.size * 0.5
	mi.position = Vector3(-c.x, -aabb.position.y, -c.z)
	var label := Label3D.new()
	label.text = "%s\n%.1f x %.1f x %.1f" % [src.name, aabb.size.x, aabb.size.y, aabb.size.z]
	label.font_size = 40
	label.pixel_size = 0.0055
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.95, 0.95, 0.85)
	label.outline_size = 14
	label.no_depth_test = true
	label.position = Vector3(0, aabb.size.y + 0.8, 0)
	holder.add_child(label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw -= event.relative.x * 0.005
		_pitch = clamp(_pitch - event.relative.y * 0.005, -1.4, 1.4)
		_update_camera()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_distance = max(5.0, _distance - 3.0); _update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_distance = min(160.0, _distance + 3.0); _update_camera()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
		elif event.keycode == KEY_R:
			_yaw = -0.6; _pitch = 0.5; _distance = 55.0
			_pivot.position = _pivot_home; _update_camera()

func _process(delta: float) -> void:
	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): move.z -= 1.0
	if Input.is_key_pressed(KEY_S): move.z += 1.0
	if Input.is_key_pressed(KEY_A): move.x -= 1.0
	if Input.is_key_pressed(KEY_D): move.x += 1.0
	if move != Vector3.ZERO:
		_pivot.position += Basis(Vector3.UP, _yaw) * move.normalized() * 25.0 * delta

func _update_camera() -> void:
	_camera.position = Vector3(cos(_pitch) * sin(_yaw), sin(_pitch), cos(_pitch) * cos(_yaw)) * _distance
	_camera.look_at(_pivot.global_position, Vector3.UP)
