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
	_brick_tri = _brick("BrickWall", "BrickWall")
	_brick_tri.uv1_triplanar = true
	_brick_tri.uv1_world_triplanar = true
	_brick_tri.uv1_scale = Vector3(0.16, 0.16, 0.16)
	_floor_mat = _brick("BrickFloor", "BrickFloor")
	_floor_mat.uv1_triplanar = true
	_floor_mat.uv1_world_triplanar = true
	_floor_mat.uv1_scale = Vector3(0.16, 0.16, 0.16)
	_wood = StandardMaterial3D.new()
	_wood.albedo_color = Color(0.34, 0.22, 0.12)
	_wood.roughness = 0.9
	_dark = StandardMaterial3D.new()
	_dark.albedo_color = Color(0.08, 0.07, 0.06)
	_dark.roughness = 1.0

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

const RUNS := 4          # straight wall runs; RUNS+1 towers at the joints
const WALL_H := 6.0
const TOWER_R := 4.2
const TOWER_H := 8.5     # a bit taller than the 6 m wall
const WALL_THICK := 3.0
const MERLON_H := 1.1
const PARAPET_H := 0.5
const CREN_STEP := 2.0
const GATE_W := 4.0

var _brick_tri: StandardMaterial3D
var _floor_mat: StandardMaterial3D
var _wood: StandardMaterial3D
var _dark: StandardMaterial3D

func _arc_pt(a: float) -> Vector3:
	return Vector3(CX + WALL_R * cos(a), _base, CZ + WALL_R * sin(a))

func _inward(p: Vector3) -> Vector3:
	return Vector3(CX - p.x, 0, CZ - p.z).normalized()

func _tower_angle(k: int) -> float:
	return lerp(PI - OPEN_HALF, PI + OPEN_HALF, float(k) / float(RUNS))

func _box(centre: Vector3, size: Vector3, yaw: float, mat: StandardMaterial3D) -> void:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = mat
	mi.transform = Transform3D(Basis(Vector3.UP, yaw), centre)
	add_child(mi)

# crenellation: continuous sill + merlon, sitting on the outer edge
func _merlon(pos: Vector3, yaw: float, merlon: bool) -> void:
	_box(Vector3(pos.x, pos.y + PARAPET_H * 0.5, pos.z), Vector3(CREN_STEP + 0.1, PARAPET_H, 0.5), yaw, _brick_tri)
	if merlon:
		_box(Vector3(pos.x, pos.y + PARAPET_H + MERLON_H * 0.5, pos.z), Vector3(1.0, MERLON_H, 0.55), yaw, _brick_tri)

# a simple stepped stair from p0 (floor) up to p1 (top)
func _stair(p0: Vector3, p1: Vector3, width: float, mat: StandardMaterial3D) -> void:
	var horiz := Vector3(p1.x - p0.x, 0, p1.z - p0.z)
	var run := horiz.length()
	if run < 0.5:
		return
	var dir := horiz / run
	var yaw := atan2(-dir.z, dir.x)
	var n: int = maxi(5, int((p1.y - p0.y) / 0.45))
	for i in n:
		var t := (float(i) + 0.5) / n
		var c := p0.lerp(p1, t)
		_box(c, Vector3(width, 0.5, run / n + 0.5), yaw, mat)

func _build_wall() -> void:
	var gate_run := RUNS / 2
	for k in RUNS:
		_wall_run(_arc_pt(_tower_angle(k)), _arc_pt(_tower_angle(k + 1)), k == gate_run)

func _wall_run(a: Vector3, b: Vector3, has_gate: bool) -> void:
	# overlap slightly INTO the towers so wall and tower touch (no gap)
	var full := (b - a).normalized()
	var a2 := a + full * (TOWER_R - 1.2)
	var b2 := b - full * (TOWER_R - 1.2)
	var span := b2 - a2
	var length := span.length()
	if length < 1.0:
		return
	var dir := span / length
	var yaw := atan2(-dir.z, dir.x)
	var mid := (a2 + b2) * 0.5
	var inw := _inward(mid)
	var half_off := inw * (WALL_THICK * 0.5)
	var gate_lo := length * 0.5 - GATE_W * 0.5
	var gate_hi := length * 0.5 + GATE_W * 0.5
	# body in 1.5 m columns (lets the gate leave an opening)
	var seg := 1.5
	var n: int = maxi(1, int(ceil(length / seg)))
	var s := length / n
	for j in n:
		var tc := (float(j) + 0.5) * s
		var c := a2 + dir * tc
		var core_c := Vector3(c.x + half_off.x, _base + MODULE * 0.5, c.z + half_off.z)
		if has_gate and tc > gate_lo and tc < gate_hi:
			_box(Vector3(core_c.x, _base + 5.0, core_c.z), Vector3(s + 0.1, 2.0, WALL_THICK), yaw, _brick_tri)  # lintel
		else:
			_box(core_c, Vector3(s + 0.1, MODULE, WALL_THICK), yaw, _brick_tri)
	# walk floor along the whole run
	_box(Vector3(mid.x + half_off.x, _base + MODULE + 0.15, mid.z + half_off.z), Vector3(length, 0.3, WALL_THICK), yaw, _floor_mat)
	# merlons along the outer edge
	var nm: int = maxi(1, int(length / CREN_STEP))
	for m in nm + 1:
		var tt := float(m) / nm * length
		if has_gate and tt > gate_lo - 1.0 and tt < gate_hi + 1.0:
			continue
		var pm := a2 + dir * tt
		_merlon(Vector3(pm.x, _base + MODULE, pm.z), yaw, m % 2 == 0)
	if has_gate:
		var gp := a2 + dir * (length * 0.5)
		_box(Vector3(gp.x, _base + 2.0, gp.z), Vector3(GATE_W - 0.6, 4.0, 0.4), yaw, _dark)  # gate leaves

func _build_towers() -> void:
	for k in RUNS + 1:
		_drum(_arc_pt(_tower_angle(k)))

func _drum(centre: Vector3) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = TOWER_R
	cyl.bottom_radius = TOWER_R
	cyl.height = TOWER_H + 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = _brick_tri
	mi.position = Vector3(centre.x, _base + TOWER_H - (TOWER_H + 2.0) * 0.5, centre.z)
	add_child(mi)
	# platform cap
	var cap := CylinderMesh.new()
	cap.top_radius = TOWER_R
	cap.bottom_radius = TOWER_R
	cap.height = 0.3
	var ci := MeshInstance3D.new()
	ci.mesh = cap
	ci.material_override = _floor_mat
	ci.position = Vector3(centre.x, _base + TOWER_H + 0.15, centre.z)
	add_child(ci)
	# small even merlon ring (no overhang)
	var ring: int = maxi(10, int(TAU * TOWER_R / CREN_STEP))
	for i in ring:
		var a := TAU * float(i) / ring
		var p := Vector3(centre.x + TOWER_R * cos(a), _base + TOWER_H, centre.z + TOWER_R * sin(a))
		_merlon(p, -a, i % 2 == 0)
	# door facing the courtyard + short stair from wall-walk up to the platform
	var inw := _inward(centre)
	var dyaw := atan2(-inw.z, inw.x)
	_box(Vector3(centre.x + inw.x * TOWER_R, _base + WALL_H - 1.0 + 1.1, centre.z + inw.z * TOWER_R), Vector3(1.4, 2.2, 0.5), dyaw, _dark)
	_stair(centre + inw * (TOWER_R + 3.0) + Vector3(0, WALL_H - 5.0, 0), centre + inw * (TOWER_R - 0.5) + Vector3(0, TOWER_H, 0), 2.2, _wood)

func _build_stairs() -> void:
	var gate_run := RUNS / 2
	for k in RUNS:
		if k == gate_run:
			continue     # keep the gate span clear
		var mid := (_arc_pt(_tower_angle(k)) + _arc_pt(_tower_angle(k + 1))) * 0.5
		var inw := _inward(mid)
		var top := Vector3(mid.x + inw.x * (WALL_THICK + 0.5), _base + WALL_H, mid.z + inw.z * (WALL_THICK + 0.5))
		var bottom := Vector3(mid.x + inw.x * 8.0, _base + 0.25, mid.z + inw.z * 8.0)
		_stair(bottom, top, 2.2, _wood)

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
