extends Node3D

## Structural pass (environment only, no gameplay): a Helm's-Deep-style fortress
## built as SOLID stone geometry (no see-through) on a sculpted Terrain3D.
##  - the terrain is sculpted into a horseshoe: a flat plateau ringed by an
##    enclosing mountain ridge on the rear + both sides, open only at the front;
##  - a solid, thick curved curtain wall closes the open front, with an outer
##    merlon parapet and a stair that runs ALONG the wall up to the walk;
##  - small solid round drum towers punctuate the wall;
##  - a gate opening sits at the front apex.
## Controls: mouse look | WASD | Q/E | Shift | R reset | Esc release/quit.

const HEIGHT_EXR := "res://assets/raw/terrain/motion_forge/Height_Map.exr"
const PREVIEW_RES := 1024
const HEIGHT_SCALE := 900.0

const CX := 330.0
const CZ := 500.0
const R_FLAT := 46.0
const R_BLEND := 14.0
const WALL_R := 44.0
const OPEN_HALF := 1.20        # half-angle of the open front (rad), centred on west (PI)
const WALL_H := 6.0            # walk surface above plateau
const WALL_THICK := 2.6
const MERLON_H := 1.3
const TOWER_R := 3.2           # smaller towers
const TOWER_H := 7.5
const GATE_HALF := 0.055       # gate opening half-angle
const RIDGE_MAX := 58.0
const RIDGE_SLOPE := 1.35
const RMAX := 104.0

var _terrain: Node
var _cam: Camera3D
var _base := 0.0
var _stone: StandardMaterial3D
var _rock: StandardMaterial3D

var _yaw := -PI / 2.0
var _pitch := 0.05
var _spawn := Vector3(250, 20, 500)

func _ready() -> void:
	_stone = StandardMaterial3D.new()
	_stone.albedo_color = Color(0.44, 0.46, 0.43)
	_stone.roughness = 0.92
	_rock = StandardMaterial3D.new()
	_rock.albedo_color = Color(0.4, 0.4, 0.42)
	_rock.roughness = 1.0
	_terrain = $Terrain
	_cam = $FlyCamera
	_terrain.call("set_camera", _cam)
	await get_tree().process_frame
	await get_tree().process_frame
	_import_terrain()
	_sculpt_terrain()
	_build_wall()
	_build_towers()
	_build_stair_along_wall(PI - 0.35)
	_place_capsule()
	_spawn = Vector3(CX + (WALL_R + 26.0) * cos(PI), _base + 5.0, CZ)
	_cam.global_position = _spawn
	_apply_look()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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
	# absolute angular distance of direction (dx,dz) from west (-X)
	var a := atan2(dz, dx)
	var d: float = abs(a - PI)
	if d > PI:
		d = TAU - d
	return d

func _sculpt_terrain() -> void:
	var data = _terrain.get("data")
	_base = _h(CX - 12.0, CZ)
	var rr: int = int(RMAX)
	for dz in range(-rr, rr + 1):
		for dx in range(-rr, rr + 1):
			var d := sqrt(float(dx * dx + dz * dz))
			if d > RMAX:
				continue
			var x := CX + dx
			var z := CZ + dz
			var target: float
			if d <= R_FLAT:
				target = _base
			else:
				var orig := _h(x, z)
				var rim: float = clampf((d - R_FLAT) / R_BLEND, 0.0, 1.0)
				var hb: float = lerp(_base, orig, rim)
				var ad := _ang_to_west(float(dx), float(dz))
				var rf: float = clampf((ad - OPEN_HALF) / 0.45, 0.0, 1.0)
				var rise: float = min(RIDGE_MAX, maxf(0.0, d - R_FLAT) * RIDGE_SLOPE)
				target = hb + rf * rise
			data.set_height(Vector3(x, 0.0, z), target)
	data.calc_height_range(true)
	data.update_maps()

func _solid(center: Vector3, size: Vector3, yaw: float, mat: StandardMaterial3D) -> void:
	var box := BoxMesh.new()
	box.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = mat
	mi.transform = Transform3D(Basis(Vector3.UP, yaw), center)
	add_child(mi)

func _build_wall() -> void:
	var walk := _base + WALL_H
	var seg := 2.0
	var n: int = int(round(WALL_R * (2.0 * OPEN_HALF) / seg))
	for i in n + 1:
		var a: float = lerp(PI - OPEN_HALF, PI + OPEN_HALF, float(i) / n)
		var px := CX + WALL_R * cos(a)
		var pz := CZ + WALL_R * sin(a)
		var yaw := -a
		var in_gate: bool = abs(a - PI) < GATE_HALF
		if in_gate:
			# lintel above the gate opening only (opening _base.._base+4)
			_solid(Vector3(px, _base + 5.0, pz), Vector3(seg + 0.4, 2.0, WALL_THICK), yaw, _stone)
		else:
			var hgt := WALL_H + 2.0
			_solid(Vector3(px, _base + WALL_H - hgt * 0.5, pz), Vector3(seg + 0.4, hgt, WALL_THICK), yaw, _stone)
		# merlons on the outer edge, every other segment (skip over gate)
		if i % 2 == 0 and not in_gate:
			var ro := WALL_R + WALL_THICK * 0.5 - 0.35
			_solid(Vector3(CX + ro * cos(a), walk + MERLON_H * 0.5, CZ + ro * sin(a)),
				Vector3(1.1, MERLON_H, 0.6), yaw, _stone)
	# gate door (simple slab) + jambs
	_solid(Vector3(CX + WALL_R * cos(PI), _base + 2.0, CZ), Vector3(3.4, 4.0, 0.4), 0.0, _rock)

func _build_towers() -> void:
	for a in [PI - OPEN_HALF, PI + OPEN_HALF, PI - 0.5, PI + 0.5]:
		_drum_tower(CX + WALL_R * cos(a), CZ + WALL_R * sin(a))

func _drum_tower(cx: float, cz: float) -> void:
	var body := CylinderMesh.new()
	body.top_radius = TOWER_R
	body.bottom_radius = TOWER_R
	body.height = TOWER_H + 3.0
	var mi := MeshInstance3D.new()
	mi.mesh = body
	mi.material_override = _stone
	mi.position = Vector3(cx, _base + TOWER_H - (TOWER_H + 3.0) * 0.5, cz)
	add_child(mi)
	# merlon ring on top
	var top := _base + TOWER_H
	var mn := 10
	for i in mn:
		if i % 2 != 0:
			continue
		var a := TAU * float(i) / mn
		_solid(Vector3(cx + TOWER_R * cos(a), top + MERLON_H * 0.5, cz + TOWER_R * sin(a)),
			Vector3(1.0, MERLON_H, 0.7), -a, _stone)

# Stair running ALONG the inner face of the wall, climbing to the wall-walk.
func _build_stair_along_wall(a_start: float) -> void:
	var n := 16
	var span := 1.1                     # angular length of the stair
	var r := WALL_R - WALL_THICK * 0.5 - 1.6
	for i in n:
		var t := float(i) / (n - 1)
		var a: float = a_start + span * t
		var y: float = lerp(_base + 0.3, _base + WALL_H, t)
		var px := CX + r * cos(a)
		var pz := CZ + r * sin(a)
		_solid(Vector3(px, y - 0.3, pz), Vector3(2.6, 0.6, 2.4), -a, _rock)

func _place_capsule() -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.3
	mesh.height = 1.8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.5, 0.2)
	mi.material_override = m
	var gx := CX + (WALL_R + 6.0) * cos(PI)
	mi.position = Vector3(gx, _h(gx, CZ) + 0.9, CZ)
	add_child(mi)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * 0.004
		_pitch = clamp(_pitch - event.relative.y * 0.004, -1.5, 1.5)
		_apply_look()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				get_tree().quit()
		elif event.keycode == KEY_R:
			_cam.global_position = _spawn
			_yaw = -PI / 2.0
			_pitch = 0.05
			_apply_look()

func _apply_look() -> void:
	_cam.rotation = Vector3(_pitch, _yaw, 0)

func _process(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
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
