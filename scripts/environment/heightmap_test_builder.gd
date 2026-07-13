extends Node3D

## Heightmap audit scene (not gameplay).
## Imports the Motion Forge "Grand Mountain" heightmap into a Terrain3D node as
## a neutral-grey inspection terrain (full map, downsampled to a compact preview),
## draws PROPOSED fortress-planning overlays draped on the terrain, and provides
## free-fly + top-down inspection cameras. Nothing is cropped or committed here —
## this stage only proposes a terrain area for human approval.
##
## Controls:
##   Mouse look (captured) | WASD move | Q/E down/up | Shift sprint
##   T top-down toggle | H hide/show overlays | R reset | Esc release mouse / quit

const HEIGHT_EXR := "res://assets/raw/terrain/motion_forge/Height_Map.exr"
const PREVIEW_RES := 1024
const HEIGHT_SCALE := 2400.0   # raw span 0.0739 -> ~177 m peak over the 1024 m preview

# Proposed planning zones (world metres in the 1024 m preview).
# The mountain is a steep isolated peak (~(505,550), ~177 m) on a flat plain.
# The western plain is a broad natural enemy approach; the fortress sits on the
# lower western slope facing it, with the peak as the rear backdrop.
const ZONES := [
	{"name": "PROPOSED CROP  384 x 384 m", "color": Color(1.0, 0.85, 0.1), "rect": [208, 308, 592, 692], "ly": 34.0},
	{"name": "PLAYABLE  160 x 180 m", "color": Color(0.2, 0.8, 1.0), "rect": [280, 410, 440, 590], "ly": 24.0},
	{"name": "ENEMY APPROACH  ~80 m (flat plain)", "color": Color(1.0, 0.3, 0.25), "rect": [270, 470, 350, 530], "ly": 14.0},
	{"name": "FORTRESS  ~66 x 45 m", "color": Color(1.0, 0.55, 0.1), "rect": [350, 467, 395, 533], "ly": 16.0},
	{"name": "COURTYARD  30 x 35 m", "color": Color(0.35, 0.9, 0.4), "rect": [356, 483, 386, 518], "ly": 10.0},
	{"name": "REAR TERRACE", "color": Color(0.75, 0.4, 1.0), "rect": [386, 480, 401, 520], "ly": 10.0},
]
const WALL_LINE := [350, 467, 350, 533]     # runs N-S, faces west
const GATE_POS := Vector2(350, 500)
const LEFT_CLIFF := [350, 533, 328, 566]
const RIGHT_CLIFF := [350, 467, 328, 434]
const PEAK := Vector2(505, 550)

var _terrain: Node
var _cam: Camera3D
var _overlays: Node3D
var _top_down := false
var _yaw := -PI / 2.0        # look east (+X), toward the mountain
var _pitch := 0.12
var _spawn := Vector3(280, 20, 500)

func _ready() -> void:
	_terrain = $Terrain
	_cam = $FlyCamera
	_terrain.call("set_camera", _cam)
	await get_tree().process_frame
	await get_tree().process_frame
	_import_terrain()
	_build_overlays()
	_place_reference_capsule()
	_spawn = Vector3(280, _sample_h(280, 500) + 4.0, 500)
	_cam.global_position = _spawn
	_apply_cam_look()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _import_terrain() -> void:
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(HEIGHT_EXR)) != OK:
		push_error("Heightmap load failed"); return
	img.resize(PREVIEW_RES, PREVIEW_RES, Image.INTERPOLATE_LANCZOS)
	if img.get_format() != Image.FORMAT_RF:
		img.convert(Image.FORMAT_RF)
	var data = _terrain.get("data")
	if data == null:
		push_error("Terrain3D data not ready"); return
	if data.get_region_count() == 0:
		data.import_images([img, null, null], Vector3.ZERO, 0.0, HEIGHT_SCALE)
	data.calc_height_range(true)

func _sample_h(x: float, z: float) -> float:
	var h: float = _terrain.get("data").get_height(Vector3(x, 0.0, z))
	return 0.0 if is_nan(h) else h

# --- Overlays -------------------------------------------------------------

func _build_overlays() -> void:
	_overlays = Node3D.new()
	_overlays.name = "Overlays"
	add_child(_overlays)
	for z in ZONES:
		var r: Array = z["rect"]
		_draped_rect(r[0], r[1], r[2], r[3], z["color"])
		_add_label(z["name"], (r[0] + r[2]) * 0.5, (r[1] + r[3]) * 0.5, z["ly"], z["color"])
	_draped_line(WALL_LINE[0], WALL_LINE[1], WALL_LINE[2], WALL_LINE[3], Color(0.97, 0.97, 0.97), 6.0)
	_draped_line(LEFT_CLIFF[0], LEFT_CLIFF[1], LEFT_CLIFF[2], LEFT_CLIFF[3], Color(0.6, 0.6, 0.72), 8.0)
	_draped_line(RIGHT_CLIFF[0], RIGHT_CLIFF[1], RIGHT_CLIFF[2], RIGHT_CLIFF[3], Color(0.6, 0.6, 0.72), 8.0)
	_add_marker(GATE_POS.x, GATE_POS.y, Color(1, 1, 1), "GATE")
	_add_label("LEFT CLIFF", 326, 570, 12.0, Color(0.72, 0.72, 0.82))
	_add_label("RIGHT CLIFF", 326, 430, 12.0, Color(0.72, 0.72, 0.82))
	_add_label("REAR MOUNTAIN BACKDROP (peak ~177 m)", PEAK.x, PEAK.y, 40.0, Color(0.85, 0.85, 0.9))
	_add_label("N", 400, 300, 24.0, Color(1, 1, 1))
	_add_label("S", 400, 700, 12.0, Color(0.8, 0.8, 0.8))

func _draped_rect(x0: float, z0: float, x1: float, z1: float, col: Color) -> void:
	_draped_line(x0, z0, x1, z0, col, 4.0)
	_draped_line(x1, z0, x1, z1, col, 4.0)
	_draped_line(x1, z1, x0, z1, col, 4.0)
	_draped_line(x0, z1, x0, z0, col, 4.0)

func _draped_line(x0: float, z0: float, x1: float, z1: float, col: Color, height: float) -> void:
	var a := Vector2(x0, z0)
	var b := Vector2(x1, z1)
	var length := a.distance_to(b)
	if length < 0.01:
		return
	var seg := 5.0
	var n := int(ceil(length / seg))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3(seg + 0.6, height, 1.2)
	mm.mesh = box
	mm.instance_count = n
	var dir := (b - a).normalized()
	var yaw := -atan2(dir.y, dir.x)
	for i in n:
		var t := (float(i) + 0.5) / n
		var p := a.lerp(b, t)
		var h := _sample_h(p.x, p.y)
		var basis := Basis(Vector3.UP, yaw)
		mm.set_instance_transform(i, Transform3D(basis, Vector3(p.x, h + height * 0.35, p.y)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _overlay_mat(col)
	_overlays.add_child(mmi)

func _add_marker(x: float, z: float, col: Color, label: String) -> void:
	var post := BoxMesh.new()
	post.size = Vector3(2.0, 10.0, 2.0)
	var mi := MeshInstance3D.new()
	mi.mesh = post
	mi.material_override = _overlay_mat(col)
	mi.position = Vector3(x, _sample_h(x, z) + 5.0, z)
	_overlays.add_child(mi)
	_add_label(label, x, z, 13.0, col)

func _add_label(text: String, x: float, z: float, y_off: float, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 72
	l.pixel_size = 0.03
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = col
	l.outline_size = 24
	l.outline_modulate = Color(0, 0, 0, 0.95)
	l.no_depth_test = true
	l.position = Vector3(x, _sample_h(x, z) + y_off, z)
	_overlays.add_child(l)

func _place_reference_capsule() -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.3
	mesh.height = 1.8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.5, 0.2)
	mi.material_override = mat
	var gx := GATE_POS.x - 6.0
	mi.position = Vector3(gx, _sample_h(gx, GATE_POS.y) + 0.9, GATE_POS.y)
	add_child(mi)
	_add_label("1.8 m", gx, GATE_POS.y, 2.6, Color(1, 0.8, 0.5))

func _overlay_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, 0.75)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

# --- Cameras & input ------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _top_down:
		_yaw -= event.relative.x * 0.004
		_pitch = clamp(_pitch - event.relative.y * 0.004, -1.5, 1.5)
		_apply_cam_look()
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				else:
					get_tree().quit()
			KEY_T:
				_toggle_top_down()
			KEY_H:
				_overlays.visible = not _overlays.visible
			KEY_R:
				_top_down = false
				_cam.global_position = _spawn
				_yaw = -PI / 2.0
				_pitch = 0.12
				_apply_cam_look()

func _toggle_top_down() -> void:
	_top_down = not _top_down
	if _top_down:
		_cam.global_position = Vector3(400, 340, 500)
		_cam.rotation = Vector3(-PI / 2.0, 0, 0)
	else:
		_cam.global_position = _spawn
		_apply_cam_look()

func _apply_cam_look() -> void:
	_cam.rotation = Vector3(_pitch, _yaw, 0)

func _process(delta: float) -> void:
	if _top_down or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir -= _cam.global_transform.basis.z
	if Input.is_key_pressed(KEY_S): dir += _cam.global_transform.basis.z
	if Input.is_key_pressed(KEY_A): dir -= _cam.global_transform.basis.x
	if Input.is_key_pressed(KEY_D): dir += _cam.global_transform.basis.x
	if Input.is_key_pressed(KEY_E): dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q): dir += Vector3.DOWN
	if dir != Vector3.ZERO:
		var speed := 90.0 if Input.is_key_pressed(KEY_SHIFT) else 30.0
		_cam.global_position += dir.normalized() * speed * delta
