extends Node3D

## Fortress built from the loafbrr Castle Wall Kit (runtime GLTF) on a horseshoe
## Terrain3D. Environment only, no gameplay.
##  - faceted curtain wall of Courtine_Wall (6 m) segments on the D arc + walk
##    floor + battlement cap; a Courtine_Door_Arch gate at the apex;
##  - round drum towers from Wall_Corner_Round quarters at the bends/ends;
##  - Stairs (kit) hugging the inner wall face, one per span.
## Controls: mouse look | WASD | Q/E | Shift | R | Esc.

const HEIGHT_EXR := "res://assets/raw/terrain/motion_forge/Height_Map.exr"
const GLTF := "res://assets/raw/loafbrr_castle_wall_kit/gltf/CastleWallsKit.gltf"
const TEX_DIR := "res://assets/raw/loafbrr_castle_wall_kit/textures"
const PREVIEW_RES := 1024
const HEIGHT_SCALE := 900.0

const CX := 330.0
const CZ := 500.0
const R_FLAT := 52.0
const R_BLEND := 16.0
const WALL_R := 44.0
const OPEN_HALF := 1.25
const RIDGE_MAX := 58.0
const RIDGE_SLOPE := 1.35
const RMAX := 112.0
const MODULE := 6.0

var _terrain: Node
var _cam: Camera3D
var _base := 0.0
var _mats := {}
var _meshes := {}

var _yaw := -PI / 2.0
var _pitch := 0.05
var _spawn := Vector3(250, 20, 500)

func _ready() -> void:
	_build_materials()
	_load_kit_meshes()
	_terrain = $Terrain
	_cam = $FlyCamera
	_terrain.call("set_camera", _cam)
	await get_tree().process_frame
	await get_tree().process_frame
	_import_terrain()
	_sculpt_terrain()
	_build_wall()
	_build_towers()
	_build_stairs()
	_place_capsule()
	_spawn = Vector3(CX + (WALL_R + 30.0) * cos(PI), _base + 6.0, CZ)
	_cam.global_position = _spawn
	_apply_look()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# --- kit assets -----------------------------------------------------------

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

func _load_kit_meshes() -> void:
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

func _put(mesh_name: String, pos: Vector3, yaw: float) -> void:
	var mesh = _meshes.get(mesh_name)
	if mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	for i in mesh.get_surface_count():
		var sm = mesh.surface_get_material(i)
		var key = sm.resource_name if sm else ""
		mi.set_surface_override_material(i, _mats.get(key, _mats["BrickWall"]))
	mi.transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	add_child(mi)

# --- terrain --------------------------------------------------------------

func _import_terrain() -> void:
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(HEIGHT_EXR)) != OK:
		push_error("heightmap load failed"); return
	img.resize(PREVIEW_RES, PREVIEW_RES, Image.INTERPOLATE_LANCZOS)
	if img.get_format() != Image.FORMAT_RF:
		img.convert(Image.FORMAT_RF)
	var data = _terrain.get("data")
	if data.get_region_count() == 0:
		data.import_images([img, null, null], Vector3.ZERO, 0.0, HEIGHT_SCALE)
	data.calc_height_range(true)

func _h(x: float, z: float) -> float:
	var v: float = _terrain.get("data").get_height(Vector3(x, 0.0, z))
	return 0.0 if is_nan(v) else v

func _ang_to_west(dx: float, dz: float) -> float:
	var a := atan2(dz, dx); var d: float = abs(a - PI)
	if d > PI: d = TAU - d
	return d

func _sculpt_terrain() -> void:
	var data = _terrain.get("data")
	_base = _h(CX - 12.0, CZ)
	var rr: int = int(RMAX)
	for dz in range(-rr, rr + 1):
		for dx in range(-rr, rr + 1):
			var d := sqrt(float(dx * dx + dz * dz))
			if d > RMAX: continue
			var target: float
			if d <= R_FLAT:
				target = _base
			else:
				var orig := _h(CX + dx, CZ + dz)
				var rim: float = clampf((d - R_FLAT) / R_BLEND, 0.0, 1.0)
				var hb: float = lerp(_base, orig, rim)
				var rf: float = clampf((_ang_to_west(float(dx), float(dz)) - OPEN_HALF) / 0.45, 0.0, 1.0)
				var rise: float = min(RIDGE_MAX, maxf(0.0, d - R_FLAT) * RIDGE_SLOPE)
				target = hb + rf * rise
			data.set_height(Vector3(CX + dx, 0.0, CZ + dz), target)
	data.calc_height_range(true)
	data.update_maps()

# --- fortress -------------------------------------------------------------

const RUNS := 3          # straight wall runs; RUNS+1 towers at the joints

func _arc_pt(a: float) -> Vector3:
	return Vector3(CX + WALL_R * cos(a), _base, CZ + WALL_R * sin(a))

func _up() -> Vector3:
	return Vector3(0, MODULE, 0)

func _inward(p: Vector3) -> Vector3:
	return Vector3(CX - p.x, 0, CZ - p.z).normalized()

func _tower_angle(k: int) -> float:
	return lerp(PI - OPEN_HALF, PI + OPEN_HALF, float(k) / float(RUNS))

func _build_wall() -> void:
	# straight runs between tower joints; towers hide the bends so each run's
	# walk + battlements stay aligned (no zig-zag).
	var gate_run := RUNS / 2
	for k in RUNS:
		_wall_run(_arc_pt(_tower_angle(k)), _arc_pt(_tower_angle(k + 1)), k == gate_run)

func _wall_run(a: Vector3, b: Vector3, has_gate: bool) -> void:
	var span := b - a
	var length := span.length()
	var dir := span / length
	var yaw := atan2(-dir.z, dir.x)
	var n: int = int(ceil(length / MODULE))
	var step := length / n
	var gate_j := n / 2 if has_gate else -1
	for j in n:
		var base_p := a + dir * step * j
		var centre_p := a + dir * step * (float(j) + 0.5)
		var inw := _inward(centre_p)
		if j == gate_j:
			_put("Courtine_Door_Arch", base_p, yaw)
		else:
			_put("Courtine_Wall", base_p, yaw)
		_put("Wall_Battlements", centre_p + _up(), yaw)
		_put("Wall_Floor", centre_p + inw * 2.6 + _up(), yaw)

func _build_towers() -> void:
	for k in RUNS + 1:
		_drum(_arc_pt(_tower_angle(k)))

func _drum(centre: Vector3) -> void:
	# hexagonal drum from 6 Courtine_Wall panels (chord = 6 m at R = 6), ~12 m dia,
	# battlement ring on top, 2x2 floor cap.
	var rt := 6.0
	var panels := 6
	for i in panels:
		var a := TAU * float(i) / panels
		var an := TAU * float(i + 1) / panels
		var p := Vector3(centre.x + rt * cos(a), _base, centre.z + rt * sin(a))
		var pn := Vector3(centre.x + rt * cos(an), _base, centre.z + rt * sin(an))
		var dir := (pn - p).normalized()
		var yaw := atan2(-dir.z, dir.x)
		_put("Courtine_Wall", p, yaw)
		_put("Wall_Battlements", (p + pn) * 0.5 + _up(), yaw)
	for sx in [-3.0, 3.0]:
		for sz in [-3.0, 3.0]:
			_put("Wall_Floor", centre + Vector3(sx, MODULE, sz), 0.0)

func _build_stairs() -> void:
	for k in RUNS:
		var mid := (_arc_pt(_tower_angle(k)) + _arc_pt(_tower_angle(k + 1))) * 0.5
		var inw := _inward(mid)
		var yaw := atan2(-inw.z, inw.x) + PI
		_put("Stairs", mid + inw * 5.0, yaw)

func _place_capsule() -> void:
	var mesh := CapsuleMesh.new(); mesh.radius = 0.3; mesh.height = 1.8
	var mi := MeshInstance3D.new(); mi.mesh = mesh
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.9, 0.5, 0.2)
	mi.material_override = m
	var gx := CX + (WALL_R + 8.0) * cos(PI)
	mi.position = Vector3(gx, _h(gx, CZ) + 0.9, CZ)
	add_child(mi)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * 0.004
		_pitch = clamp(_pitch - event.relative.y * 0.004, -1.5, 1.5)
		_apply_look()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else: get_tree().quit()
		elif event.keycode == KEY_R:
			_cam.global_position = _spawn; _yaw = -PI / 2.0; _pitch = 0.05; _apply_look()

func _apply_look() -> void:
	_cam.rotation = Vector3(_pitch, _yaw, 0)

func _process(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir -= _cam.global_transform.basis.z
	if Input.is_key_pressed(KEY_S): dir += _cam.global_transform.basis.z
	if Input.is_key_pressed(KEY_A): dir -= _cam.global_transform.basis.x
	if Input.is_key_pressed(KEY_D): dir += _cam.global_transform.basis.x
	if Input.is_key_pressed(KEY_E): dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q): dir += Vector3.DOWN
	if dir != Vector3.ZERO:
		var speed := 45.0 if Input.is_key_pressed(KEY_SHIFT) else 14.0
		_cam.global_position += dir.normalized() * speed * delta
