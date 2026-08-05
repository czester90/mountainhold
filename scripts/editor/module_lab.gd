extends Node3D

## Module lab v2 — fixes the two broken assemblies before they touch the fortress:
##  (A) OPEN-GORGE round tower: the drum is only the outer ~180 deg (field side);
##      the courtyard side is open so the wall-walk flows straight in (real entry),
##      the internal stone stair is visible climbing the gorge to the top deck, and
##      the tower reads whole (full battlements on the kept arc, nothing "blown off").
##  (B) DONJON over the gate: square keep, double gate at base, 4 arched windows,
##      machicolation + battlement crown, and a door on each side into the wall-walk.
## Wall faces +Z (field); courtyard is -Z. Kit's own per-surface brick throughout.

const GLTF := "res://assets/raw/loafbrr_castle_wall_kit/gltf/CastleWallsKit.gltf"
const TEX_DIR := "res://assets/raw/loafbrr_castle_wall_kit/textures"
const WALL_H := 6.0
const ARC_C := Vector3(6, 0, -6)   # Wall_Corner_Round arc centre (measured)
const ARC_C2 := Vector3(3, 0, -3)  # round Battlements/Floor arc centre (measured)

var _mats := {}
var _meshes := {}

func _ready() -> void:
	_build_materials()
	_load_kit()
	_build()

func _tex(p: String) -> ImageTexture:
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(p)) != OK: return null
	return ImageTexture.create_from_image(img)

func _mk(dir: String, tag: String) -> StandardMaterial3D:
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
	_mats["BrickWall"] = _mk("BrickWall", "BrickWall")
	_mats["BrickTrims"] = _mk("BrickTrims", "BrickTrims")
	_mats["BrickFloor"] = _mk("BrickFloor", "BrickFloor")

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

func _put_b(mesh_name: String, pos: Vector3, basis: Basis) -> void:
	var mesh = _meshes.get(mesh_name)
	if mesh == null:
		push_warning("missing " + mesh_name); return
	var mi := MeshInstance3D.new(); mi.mesh = mesh
	for i in mesh.get_surface_count():
		var sm = mesh.surface_get_material(i)
		mi.set_surface_override_material(i, _mats.get(sm.resource_name if sm else "", _mats["BrickWall"]))
	mi.transform = Transform3D(basis, pos)
	add_child(mi)

func _put(mesh_name: String, pos: Vector3, yaw_deg: float) -> void:
	_put_b(mesh_name, pos, Basis(Vector3.UP, deg_to_rad(yaw_deg)))

func _box(c: Vector3, s: Vector3, yaw: float, mat_key: String) -> void:
	var b := BoxMesh.new(); b.size = s
	var mi := MeshInstance3D.new(); mi.mesh = b
	mi.material_override = _mats.get(mat_key, _mats["BrickWall"])
	mi.transform = Transform3D(Basis(Vector3.UP, yaw), c)
	add_child(mi)

# Solid-column stone stairs: seated, never floating. Climbs foot->top_y along dir.
func _stone_stairs(foot: Vector3, dir: Vector3, top_y: float, width: float) -> void:
	var rise := top_y - foot.y
	if rise <= 0.1: return
	var n: int = maxi(1, int(round(rise / 0.5)))
	var r := rise / n
	var run := 0.55
	var yaw := atan2(-dir.z, dir.x)
	for i in n:
		var h := r * (i + 1)
		var c := foot + dir * (run * (float(i) + 0.5))
		_box(Vector3(c.x, foot.y + h * 0.5, c.z), Vector3(run + 0.02, h, width), yaw, "BrickFloor")

# --- open-gorge round tower -------------------------------------------------
# Quarters map (base_yaw 0): q0=(-X,+Z) q1=(+X,+Z) q2=(+X,-Z) q3=(-X,-Z).
# Keep field-side quarters, skip courtyard-side ones.
func _drum(centre: Vector3, courses: int, base_yaw: float, skip: Array) -> void:
	for course in courses:
		var y := course * WALL_H
		for q in 4:
			if q in skip: continue
			var basis := Basis(Vector3.UP, base_yaw + deg_to_rad(q * 90.0))
			_put_b("Wall_Corner_Round", Vector3(centre.x, y, centre.z) - basis * ARC_C, basis)

func _deck(centre: Vector3, y: float, base_yaw: float, skip: Array) -> void:
	for q in 4:
		if q in skip: continue
		var basis := Basis(Vector3.UP, base_yaw + deg_to_rad(q * 90.0))
		_put_b("Wall_Floor_Round", Vector3(centre.x, y, centre.z) - basis * ARC_C2, basis)

func _ring(centre: Vector3, y: float, base_yaw: float, skip: Array) -> void:
	for q in 4:
		if q in skip: continue
		var basis := Basis(Vector3.UP, base_yaw + deg_to_rad(q * 90.0))
		_put_b("Wall_Battlements_Corner_Round", Vector3(centre.x, y, centre.z) - basis * ARC_C2, basis)

## SOLID capped round tower (QTg11X style): full drum both courses -> a solid 12 m
## cylinder; a SOLID roof deck (4 floor quarters = full r6 disc) flush under the
## merlon ring at 12 m. No central hole, no pillar, no open quarter -> reads as a
## real tower, not a bandstand. (Entry/stairs added separately once the look is right.)
func _tower(centre: Vector3, base_yaw: float, gorge: Array) -> void:
	var q_open: int = gorge[0]                        # courtyard doorway quarter (course 1 only)
	for q in 4:                                       # course 0: fully solid base
		var b0 := Basis(Vector3.UP, base_yaw + deg_to_rad(q * 90.0))
		_put_b("Wall_Corner_Round", Vector3(centre.x, 0, centre.z) - b0 * ARC_C, b0)
	for q in 4:                                       # course 1: solid except the doorway
		if q == q_open:
			continue
		var b1 := Basis(Vector3.UP, base_yaw + deg_to_rad(q * 90.0))
		_put_b("Wall_Corner_Round", Vector3(centre.x, WALL_H, centre.z) - b1 * ARC_C, b1)
	_deck(centre, WALL_H, base_yaw, [])               # interior floor at 6 m (no see-through)
	_deck(centre, 2 * WALL_H, base_yaw, [])           # SOLID full-radius roof disc
	_ring(centre, 2 * WALL_H, base_yaw, [])           # merlon ring flush on the roof rim
	var base_deg: float = [135.0, 45.0, -45.0, -135.0][q_open]
	var oa := base_yaw + deg_to_rad(base_deg)
	var od := Vector3(cos(oa), 0, sin(oa))
	_stone_stairs(centre + Vector3(0, WALL_H, 0) + od * 3.4, -od, 2 * WALL_H, 1.8)  # 6m -> roof

# --- donjon over the gate ---------------------------------------------------
# 2x2-cell square keep. Front (+Z) = double gate then 4 arched windows; sides get
# a door at walk level (entry from the wall-walk); machicolation+battlement crown.
func _donjon(o: Vector3) -> void:
	var wide := 2
	var storeys := 3
	var span := wide * WALL_H
	for s in storeys:
		var y := s * WALL_H
		for c in wide:
			var x := o.x + c * WALL_H
			# front (+Z), faces +Z (yaw 0), corner-origin x:[0,6]
			var fp := "Courtine_Door_Arch" if s == 0 else "Courtine_Window_Arch"
			_put(fp, Vector3(x, y, o.z + span), 0)
			# back (-Z), yaw 180 -> corner-origin flips in X, shift by +6
			_put("Courtine_Wall", Vector3(x + WALL_H, y, o.z), 180)
		for c in wide:
			var z := o.z + c * WALL_H
			# right (+X): front faces +X => yaw 90; corner-origin maps x->-z, shift
			var rp := "Courtine_Door_Square" if s == 1 and c == 0 else "Courtine_Wall"
			_put(rp, Vector3(o.x + span, y, z), 90)
			# left (-X): faces -X => yaw 270; shift by +6 in z
			var lp := "Courtine_Door_Square" if s == 1 and c == 0 else "Courtine_Wall"
			_put(lp, Vector3(o.x, y, z + WALL_H), 270)
	# crown: machicolation + battlements around the top on all four sides
	var top := storeys * WALL_H
	for c in wide:
		var x := o.x + c * WALL_H + WALL_H * 0.5
		_put("Wall_Machicolation", Vector3(x, top, o.z + span), 0)
		_put("Wall_Battlements", Vector3(x, top, o.z + span), 0)
		_put("Wall_Battlements", Vector3(x, top, o.z), 180)
	for c in wide:
		var z := o.z + c * WALL_H + WALL_H * 0.5
		_put("Wall_Battlements", Vector3(o.x + span, top, z), 90)
		_put("Wall_Battlements", Vector3(o.x, top, z), 270)

func _build() -> void:
	# --- wall run along +X, front face +Z, walk + battlements
	for i in 3:
		var x := i * 6.0
		_put("Courtine_Wall", Vector3(x, 0, 0), 0)
		_put("Wall_Floor", Vector3(x + 3, WALL_H, -3), 0)
		_put("Wall_Battlements", Vector3(x + 3, WALL_H, 0), 0)
	# --- open-gorge tower (270 deg): skip ONE quarter (q3) with base_yaw 45 so the
	# opening faces -Z (courtyard); reads as a round tower with an open back.
	_tower(Vector3(24, 0, -3), deg_to_rad(45.0), [3])
	# --- donjon set apart at z=-40
	_donjon(Vector3(4, 0, -46))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
