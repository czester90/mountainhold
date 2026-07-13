extends Node3D

## First structural pass (environment only, no gameplay): a Helm's-Deep-style
## fortress from MCSTEEG modules on the Terrain3D heightmap.
##  - a level plateau is carved at the mountain foot (with a blended rim);
##  - a curved curtain wall (~6 m, battlemented top course) sweeps the arc;
##  - round towers (rings of wall modules) stand taller at the arc ends + gate;
##  - a gate sits at the arc apex facing the plain; the mountain is the rear.
## MultiMesh per module type. Controls: mouse look | WASD | Q/E | Shift | R | Esc.

const HEIGHT_EXR := "res://assets/raw/terrain/motion_forge/Height_Map.exr"
const GLB := "res://assets/raw/mcsteeg_castle/Castles_and_Forts.glb"
const PREVIEW_RES := 1024
const HEIGHT_SCALE := 900.0

const COURSE := 2.0        # module height (m)
const MODULE := 4.0        # module length (m)
const WALL_H := 6.0        # visible wall height
const TOWER_H := 9.0

const CX := 330.0
const CZ := 500.0
const R_FLAT := 50.0       # flat plateau radius
const R_BLEND := 16.0      # blended rim
const ARC_R := 42.0
const ARC_A0 := PI * 0.5
const ARC_A1 := PI * 1.5
const TOWER_R := 4.5

var _terrain: Node
var _cam: Camera3D
var _meshes := {}
var _base := 0.0

var _yaw := -PI / 2.0
var _pitch := 0.03
var _spawn := Vector3(250, 20, 500)

func _ready() -> void:
	_terrain = $Terrain
	_cam = $FlyCamera
	_terrain.call("set_camera", _cam)
	await get_tree().process_frame
	await get_tree().process_frame
	_import_terrain()
	_flatten_plateau()
	_load_modules()
	_build_walls()
	_build_towers()
	_place_capsule()
	_spawn = Vector3(CX - ARC_R - 30.0, _base + 6.0, CZ)
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

func _flatten_plateau() -> void:
	var data = _terrain.get("data")
	_base = _h(CX - 12.0, CZ)          # nestle at a low foot elevation
	var rr: int = int(R_FLAT + R_BLEND)
	for dz in range(-rr, rr + 1):
		for dx in range(-rr, rr + 1):
			var d := sqrt(float(dx * dx + dz * dz))
			if d > R_FLAT + R_BLEND:
				continue
			var x := CX + dx
			var z := CZ + dz
			var target := _base
			if d > R_FLAT:
				var t: float = smoothstep(0.0, 1.0, (d - R_FLAT) / R_BLEND)
				target = lerp(_base, _h(x, z), t)
			data.set_height(Vector3(x, 0.0, z), target)
	data.calc_height_range(true)

func _load_modules() -> void:
	var glb: Node = load(GLB).instantiate()
	var stack: Array[Node] = [glb]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			_meshes[String(n.name)] = (n as MeshInstance3D).mesh
		for c in n.get_children():
			stack.append(c)
	glb.queue_free()

func _emit(mesh_name: String, transforms: Array) -> void:
	if not _meshes.has(mesh_name) or transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _meshes[mesh_name]
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = "MM_" + mesh_name + "_" + str(get_child_count())
	add_child(mmi)

# Stack a column of wall modules at (px,pz,yaw): plain courses + battlemented top.
func _column(px: float, pz: float, yaw: float, top_y: float, plain: Array, walk: Array) -> void:
	var b := Basis(Vector3.UP, yaw)
	walk.append(Transform3D(b, Vector3(px, top_y - COURSE, pz)))
	var y := top_y - 2.0 * COURSE
	while y > _base - 2.5:
		plain.append(Transform3D(b, Vector3(px, y, pz)))
		y -= COURSE

func _build_walls() -> void:
	var top := _base + WALL_H
	var plain: Array = []
	var walk: Array = []
	var n_seg := int(round(ARC_R * absf(ARC_A1 - ARC_A0) / MODULE))
	var gate_i := n_seg / 2
	for i in n_seg:
		if i == gate_i:
			_build_gate(i, n_seg, top)
			continue
		var a: float = lerp(ARC_A0, ARC_A1, (float(i) + 0.5) / n_seg)
		_column(CX + ARC_R * cos(a), CZ + ARC_R * sin(a), -a, top, plain, walk)
	_emit("Wall_2x4", plain)
	_emit("Wall_2x4_walkway", walk)

func _build_gate(i: int, n_seg: int, top: float) -> void:
	var a: float = lerp(ARC_A0, ARC_A1, (float(i) + 0.5) / n_seg)
	var px := CX + ARC_R * cos(a)
	var pz := CZ + ARC_R * sin(a)
	var b := Basis(Vector3.UP, -a)
	if _meshes.has("Gate_2x4"):
		var g := MeshInstance3D.new()
		g.mesh = _meshes["Gate_2x4"]
		g.transform = Transform3D(b, Vector3(px, _base, pz))
		add_child(g)
	if _meshes.has("Gate_Door"):
		var d := MeshInstance3D.new()
		d.mesh = _meshes["Gate_Door"]
		d.transform = Transform3D(b, Vector3(px, _base, pz))
		add_child(d)
	# wall course + battlement above the gate opening
	var w := MeshInstance3D.new()
	w.mesh = _meshes.get("Wall_2x4")
	w.transform = Transform3D(b, Vector3(px, _base + COURSE, pz))
	add_child(w)
	var wk := MeshInstance3D.new()
	wk.mesh = _meshes.get("Wall_2x4_walkway")
	wk.transform = Transform3D(b, Vector3(px, top - COURSE, pz))
	add_child(wk)

func _build_towers() -> void:
	var top := _base + TOWER_H
	for a in [ARC_A0, ARC_A1, PI - 0.5, PI + 0.5]:
		_round_tower(CX + ARC_R * cos(a), CZ + ARC_R * sin(a), top)

# Round tower = a closed ring of wall modules, battlemented top course.
func _round_tower(cx: float, cz: float, top_y: float) -> void:
	var plain: Array = []
	var walk: Array = []
	var circ := TAU * TOWER_R
	var n: int = maxi(6, int(round(circ / MODULE)))
	for i in n:
		var a := TAU * float(i) / n
		_column(cx + TOWER_R * cos(a), cz + TOWER_R * sin(a), -a + PI * 0.5, top_y, plain, walk)
	_emit("Wall_2x2", plain)
	_emit("Wall_2x2_walkway", walk)

func _place_capsule() -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.3
	mesh.height = 1.8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.5, 0.2)
	mi.material_override = m
	var gx := CX - ARC_R - 4.0
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
			_pitch = 0.03
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
