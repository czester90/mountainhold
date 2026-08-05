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
const R_FLAT := 56.0        # flat courtyard radius in the frontal (open field) wedge
const R_FLAT_BACK := 36.0   # shrinks inside the wall line at the back so rock buries the wall ends
const R_BLEND := 16.0
const WALL_R := 44.0
const OPEN_HALF := 1.35
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
	# steep, near-overhead sun so the walls cast short shadows and the courtyard floor
	# stays lit/walkable (a low sun threw the whole courtyard into black shadow).
	$Sun.rotation_degrees = Vector3(-68.0, -34.0, 0.0)
	_terrain.call("set_camera", _cam)
	await get_tree().process_frame
	await get_tree().process_frame
	_import_terrain()
	_sculpt_terrain()
	_setup_terrain_textures()
	_build_wall()
	_build_towers()
	_prep_stairs()
	_build_walk_ring()
	_build_stairs()
	_place_capsule()
	_add_collision()
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
	# kit pieces are single-surface panels (brick faces one way); render BOTH sides so
	# towers/keep don't turn see-through when viewed from the courtyard / inside.
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
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
	_put_b(mesh_name, pos, Basis(Vector3.UP, yaw))

func _put_b(mesh_name: String, pos: Vector3, basis: Basis) -> void:
	var mesh = _meshes.get(mesh_name)
	if mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	for i in mesh.get_surface_count():
		var sm = mesh.surface_get_material(i)
		var key = sm.resource_name if sm else ""
		mi.set_surface_override_material(i, _mats.get(key, _mats["BrickWall"]))
	mi.transform = Transform3D(basis, pos)
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

# Procedural noisy albedo so the terrain reads as stone/scree instead of the checker.
func _noise_tex(base: Color, contrast: float, freq: float, seed: int) -> ImageTexture:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.seed = seed
	n.fractal_octaves = 4
	var sz := 512
	var img := Image.create(sz, sz, true, Image.FORMAT_RGB8)
	for y in sz:
		for x in sz:
			var v: float = n.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var s: float = 1.0 + (v - 0.5) * contrast
			img.set_pixel(x, y, Color(clampf(base.r * s, 0, 1), clampf(base.g * s, 0, 1), clampf(base.b * s, 0, 1)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# Muted dark-stone terrain: a scree/ground base on the flats (auto_shader id 0) and
# rock on the slopes (id 1). Kills the debug checker/grey overlay.
func _setup_terrain_textures() -> void:
	var ground := Terrain3DTextureAsset.new()
	ground.set("name", "ground")
	ground.set("id", 0)
	ground.set("albedo_color", Color(0.37, 0.38, 0.34))
	ground.set("albedo_texture", _noise_tex(Color(0.38, 0.39, 0.34), 0.4, 0.02, 7))
	ground.set("uv_scale", 0.10)
	ground.set("roughness", 1.0)
	var rock := Terrain3DTextureAsset.new()
	rock.set("name", "rock")
	rock.set("id", 1)
	rock.set("albedo_color", Color(0.35, 0.34, 0.32))
	rock.set("albedo_texture", _noise_tex(Color(0.37, 0.36, 0.34), 0.55, 0.015, 3))
	rock.set("uv_scale", 0.08)
	rock.set("roughness", 0.95)
	var assets := Terrain3DAssets.new()
	assets.set_texture_list([ground, rock])
	_terrain.set_assets(assets)
	var mat = _terrain.get("material")
	if mat:
		mat.set("auto_shader", true)
		mat.set("show_grey", false)
		mat.set("show_checkered", false)
		mat.set("world_background", 1)
	_terrain.set("show_grey", false)
	_terrain.set("show_checkered", false)

func _ang_to_west(dx: float, dz: float) -> float:
	var a := atan2(dz, dx); var d: float = abs(a - PI)
	if d > PI: d = TAU - d
	return d

# Procedural SYMMETRIC horseshoe bowl (independent of the asymmetric source EXR):
#  - flat courtyard plateau inside R_FLAT;
#  - a rim that rises with distance beyond R_FLAT, gated by angle so it forms a
#    horseshoe: high mountain wrapping the back and both sides, open only in a
#    frontal wedge under the gate. The curtain-wall ends (at ang_to_west≈OPEN_HALF)
#    land right where the rim starts rising, so they embed into the rock symmetrically.
func _sculpt_terrain() -> void:
	var data = _terrain.get("data")
	_base = _h(CX - 12.0, CZ)
	var rr: int = int(RMAX)
	var front_open := 0.95        # frontal wedge (open field) half-angle, rad
	var front_band := 0.45        # smooth ramp from open field -> full mountain
	for dz in range(-rr, rr + 1):
		for dx in range(-rr, rr + 1):
			var d := sqrt(float(dx * dx + dz * dz))
			if d > RMAX: continue
			# angle gate: 0 in the frontal wedge (open field), 1 on the sides/back (mountain)
			var g: float = clampf((_ang_to_west(float(dx), float(dz)) - front_open) / front_band, 0.0, 1.0)
			# flat radius shrinks from a wide front (open field) to inside the wall line at
			# the back, so rock climbs right onto the curtain ends -> the wall dies into rock.
			var rflat_eff: float = lerp(R_FLAT, R_FLAT_BACK, g)
			var over := d - rflat_eff
			var target := _base
			if over > 0.0:
				target = _base + g * min(RIDGE_MAX, over * RIDGE_SLOPE)
			data.set_height(Vector3(CX + dx, 0.0, CZ + dz), target)
	data.calc_height_range(true)
	data.update_maps()

# --- fortress -------------------------------------------------------------

const RUNS := 5          # odd -> the middle run (gate) sits on the west apex, flanked by towers
const WALL_H := 6.0
const TOWER_R := 6.0     # drum radius = 6 m (matches the kit round-corner arc radius)
const WALL_THICK := 2.6
const GATE_W := 6.0
const ARC_C := Vector3(6, 0, -6)   # Wall_Corner_Round arc centre (measured)
const ARC_C2 := Vector3(3, 0, -3)  # round Battlements/Floor arc centre (measured)

var _brick_tri: StandardMaterial3D
var _floor_mat: StandardMaterial3D
var _wood: StandardMaterial3D
var _dark: StandardMaterial3D

# navigation reference points (world coords) exposed for the automated player test
var nav := {"stairs": [], "towers": [], "keep": {}}
var _stair_specs: Array = []           # computed before the walk ring so it can gap over stairs

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

# Narrow stone stairs from solid step-columns: each step rises from the ground to
# its tread height, so the flight is seated (never floating). Climbs from `foot`
# along horizontal unit `dir` up to `top_y`; `width` across the run.
func _stone_stairs(foot: Vector3, dir: Vector3, top_y: float, width: float) -> void:
	var rise := top_y - foot.y
	if rise <= 0.1:
		return
	var n: int = maxi(1, int(round(rise / 0.5)))
	var r := rise / n
	var run := 0.55
	var yaw := atan2(-dir.z, dir.x)
	for i in n:
		var h := r * (i + 1)
		var c := foot + dir * (run * (float(i) + 0.5))
		_box(Vector3(c.x, foot.y + h * 0.5, c.z), Vector3(run + 0.02, h, width), yaw, _floor_mat)
	# collision-only ramp under the steps so a CharacterBody walks up smoothly
	_stair_ramp(foot, dir, run * n, rise, width)

# Invisible inclined box matching a stair's slope, for smooth character movement.
func _stair_ramp(foot: Vector3, dir: Vector3, run_total: float, rise: float, width: float) -> void:
	var fwd := (dir * run_total + Vector3.UP * rise).normalized()
	var side := dir.cross(Vector3.UP).normalized()
	var upn := side.cross(fwd).normalized()
	if upn.y < 0.0:
		upn = -upn; side = -side
	var hyp := sqrt(run_total * run_total + rise * rise)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new(); bs.size = Vector3(width, 0.5, hyp)
	cs.shape = bs
	body.add_child(cs)
	body.transform = Transform3D(Basis(side, upn, fwd), foot + dir * (run_total * 0.5) + Vector3.UP * (rise * 0.5) - upn * 0.22)
	add_child(body)

# --- wooden switchback stairs (flights + landings) ------------------------

func _box_into_y(parent: Node3D, c: Vector3, s: Vector3, yaw: float, mat: StandardMaterial3D) -> void:
	var b := BoxMesh.new(); b.size = s
	var mi := MeshInstance3D.new(); mi.mesh = b; mi.material_override = mat
	mi.transform = Transform3D(Basis(Vector3.UP, yaw), c)
	parent.add_child(mi)

# Collision-only inclined box for one flight, parented locally (keep-interior use).
func _ramp_into(parent: Node3D, foot: Vector3, dir: Vector3, run_total: float, rise: float, width: float) -> void:
	var fwd := (dir * run_total + Vector3.UP * rise).normalized()
	var side := dir.cross(Vector3.UP).normalized()
	var upn := side.cross(fwd).normalized()
	if upn.y < 0.0:
		upn = -upn; side = -side
	var hyp := sqrt(run_total * run_total + rise * rise)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new(); bs.size = Vector3(width, 0.5, hyp)
	cs.shape = bs
	body.add_child(cs)
	body.transform = Transform3D(Basis(side, upn, fwd), foot + dir * (run_total * 0.5) + Vector3.UP * (rise * 0.5) - upn * 0.22)
	parent.add_child(body)

# Wooden switchback: straight flights zig-zagging up from y0 to y1, connected by landings.
# `put(pos, size, yaw)` places one wooden box; `ramp(foot, dir, run_total, rise, width)` lays a
# collision incline. Flights alternate direction along +/- d in two lanes offset along `side`.
# Returns {top, hatch_c, hatch_d, hatch_run, hatch_w} so the caller can cut a stair hatch.
func _wooden_core(put: Callable, ramp: Callable, centre: Vector3, y0: float, y1: float, d: Vector3, run: float, width: float, per_flight: float) -> Dictionary:
	var rise := y1 - y0
	var side := d.cross(Vector3.UP).normalized()
	var nf: int = maxi(1, int(round(rise / per_flight)))
	var per := rise / float(nf)
	var steps: int = maxi(3, int(round(per / 0.42)))
	var r := per / float(steps)
	var tread := run / float(steps)
	var lane := width * 0.5 + 0.2
	var out := {"top": centre, "hatch_c": centre, "hatch_d": d, "hatch_run": run + 1.4, "hatch_w": width + 0.5}
	for f in nf:
		var up_dir: Vector3 = d if (f % 2 == 0) else -d
		var lo: Vector3 = side * (lane if (f % 2 == 0) else -lane)
		var fy := y0 + f * per
		var bottom := centre + lo - up_dir * (run * 0.5)
		var yaw := atan2(-up_dir.z, up_dir.x)
		for i in steps:
			var c := bottom + up_dir * (tread * (float(i) + 0.5))
			var ty := fy + r * (float(i) + 1.0) - 0.06
			put.call(Vector3(c.x, ty, c.z), Vector3(tread + 0.05, 0.12, width), yaw)
		ramp.call(Vector3(bottom.x, fy, bottom.z), up_dir, tread * float(steps), per, width)
		var land_c := centre + up_dir * (run * 0.5)
		var ly := fy + per
		put.call(Vector3(land_c.x, ly - 0.07, land_c.z), Vector3(1.5, 0.14, 2.0 * lane + width + 0.4), yaw)
		if f == nf - 1:
			out["top"] = Vector3(land_c.x, ly, land_c.z)
			out["hatch_c"] = centre + lo
			out["hatch_d"] = up_dir
	return out

# Full brick roof deck at height y with a rectangular hatch over the top flight.
func _tower_roof_hatch(centre: Vector3, y: float, hc: Vector3, hd: Vector3, hrun: float, hw: float) -> void:
	var hs := hd.cross(Vector3.UP).normalized()
	var r_out := TOWER_RAD - 0.2
	var step := 1.4
	var m: int = int(r_out / step) + 1
	for ix in range(-m, m + 1):
		for iz in range(-m, m + 1):
			var px := ix * step
			var pz := iz * step
			if sqrt(px * px + pz * pz) > r_out:
				continue
			var rel := Vector3(centre.x + px - hc.x, 0.0, centre.z + pz - hc.z)
			if absf(rel.dot(hd)) < hrun * 0.5 and absf(rel.dot(hs)) < hw * 0.5:
				continue                                   # stair hatch
			_box(Vector3(centre.x + px, y - 0.15, centre.z + pz), Vector3(step + 0.05, 0.3, step + 0.05), 0.0, _floor_mat)

# List of tower node indices (matches _build_towers): interior, non-gate, non-terminal.
func _tower_ks() -> Array:
	var gate_run := RUNS / 2
	var out: Array = []
	for k in RUNS + 1:
		if k == gate_run or k == gate_run + 1:
			continue
		if k == 0 or k == RUNS:
			continue
		out.append(k)
	return out

# Move `from` along the segment toward `toward` until it lands on the drum circle
# (centre c, radius TOWER_RAD), so the curtain butts the tower instead of piercing it.
func _trim_end(from: Vector3, toward: Vector3, c: Vector3) -> Vector3:
	var dir := (toward - from); dir.y = 0.0
	if dir.length() < 0.01:
		return from
	dir = dir.normalized()
	var e := from - c; e.y = 0.0
	var bq := e.dot(dir)
	var cq := e.dot(e) - TOWER_RAD * TOWER_RAD
	var disc := bq * bq - cq
	if disc <= 0.0:
		return from
	var t := -bq + sqrt(disc)
	if t <= 0.0:
		return from
	return from + dir * t

func _put_s(mesh_name: String, pos: Vector3, yaw: float, scale: Vector3) -> void:
	var mesh = _meshes.get(mesh_name)
	if mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	for i in mesh.get_surface_count():
		var sm = mesh.surface_get_material(i)
		mi.set_surface_override_material(i, _mats.get(sm.resource_name if sm else "", _mats["BrickWall"]))
	mi.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(scale), pos)
	add_child(mi)

func _build_wall() -> void:
	var gate_run := RUNS / 2
	var tks := _tower_ks()
	for k in RUNS:
		var oa := _arc_pt(_tower_angle(k))
		var ob := _arc_pt(_tower_angle(k + 1))
		if k == gate_run:
			_donjon_arc(oa, ob)
			continue
		# butt each end that meets a tower against the drum surface (no piercing)
		var a := oa
		var b := ob
		if k in tks:
			a = _trim_end(oa, ob, _proj_pt(_tower_angle(k)))
		if (k + 1) in tks:
			b = _trim_end(ob, oa, _proj_pt(_tower_angle(k + 1)))
		_wall_run(a, b, false)

# Hollow 3-D gate keep spanning the apex. Built in a rotated container so the proven
# axis-aligned assembly (front windows/gate, back, two sides, crown) just works:
# four thin walls enclosing an empty interior -> windows read as real openings (not
# bricked), the gate passes through, side doors let the wall-walk in.
func _donjon_arc(a_in: Vector3, b_in: Vector3) -> void:
	var mid := (a_in + b_in) * 0.5
	var out_dir := (-_inward(mid)).normalized()               # field direction
	var keep := Node3D.new()
	add_child(keep)
	keep.transform = Transform3D(Basis(Vector3.UP, atan2(out_dir.x, out_dir.z)), Vector3(mid.x, _base, mid.z))
	_donjon_local(keep)

func _put_into(parent: Node3D, mesh_name: String, pos: Vector3, yaw: float) -> void:
	var mesh = _meshes.get(mesh_name)
	if mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	for i in mesh.get_surface_count():
		var sm = mesh.surface_get_material(i)
		mi.set_surface_override_material(i, _mats.get(sm.resource_name if sm else "", _mats["BrickWall"]))
	mi.transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	parent.add_child(mi)

func _box_into(parent: Node3D, c: Vector3, s: Vector3, mat: StandardMaterial3D) -> void:
	var b := BoxMesh.new(); b.size = s
	var mi := MeshInstance3D.new(); mi.mesh = b; mi.material_override = mat
	mi.transform = Transform3D(Basis.IDENTITY, c)
	parent.add_child(mi)

# Local keep: 3 cells wide (X, front/back) x 2 deep (Z, sides), front faces +Z.
# Footprint x:[-9,9] z:[-6,6]. ONE big central gate (front+back centre cell, passage
# through), arched windows on the upper front, a floor at 6 m (the wall-walk crosses
# it) with doors on both sides at 6 m, machicolation + battlement crown.
# Corner-origin edge placement (HX=9, HZ=6):
#   front(+Z z=HZ):  yaw 0    P.x=-HX+c*6   c=0..2
#   back (-Z z=-HZ): yaw 180  P.x= HX-c*6   c=0..2
#   right(+X x=HX):  yaw 90   P.z= HZ-c*6   c=0..1
#   left (-X x=-HX): yaw 270  P.z=-HZ+c*6   c=0..1
func _donjon_local(keep: Node3D) -> void:
	var HX := 9.0
	var HZ := 6.0
	for s in 3:
		var y := s * WALL_H
		for c in 3:
			var fx := -HX + c * WALL_H
			# defensive front: arrow-slits + a small square window over the gate (no big arches)
			var front := "Courtine_Wall"
			if s == 0:
				front = "Courtine_Door_Arch" if c == 1 else "Courtine_Slit"     # centre gate, slits flanking
			elif s == 1:
				front = "Courtine_Window_Square"       # three small windows across the front
			else:
				front = "Courtine_Slit"
			var back := "Courtine_Door_Arch" if (s == 0 and c == 1) else "Courtine_Wall"
			_put_into(keep, front, Vector3(fx, y, HZ), 0.0)                    # front (+Z)
			_put_into(keep, back, Vector3(HX - c * WALL_H, y, -HZ), PI)        # back (-Z)
		for c in 2:
			# side doors on the courtyard-side cell (-Z) at walk level, for the walk to pass
			var rp := "Courtine_Door_Square" if (s == 1 and c == 1) else "Courtine_Wall"
			var lp := "Courtine_Door_Square" if (s == 1 and c == 0) else "Courtine_Wall"
			_put_into(keep, rp, Vector3(HX, y, HZ - c * WALL_H), PI * 0.5)     # right (+X)
			_put_into(keep, lp, Vector3(-HX, y, -HZ + c * WALL_H), PI * 1.5)   # left (-X)
	# floor at 6 m (top surface at _base+WALL_H, unified with the wall-walk).
	_box_into(keep, Vector3(0, WALL_H - 0.15, 0), Vector3(2 * HX + 6.0, 0.3, 2 * HZ - 0.5), _floor_mat)
	# SOLID wall body (0-6 m) under the floor extension on each side, so the link to the
	# flanking curtain reads as a wall with a walk on top -> NOT a floating plank ("deski").
	for sgn in [-1.0, 1.0]:
		_box_into(keep, Vector3(sgn * (HX + 1.5), WALL_H * 0.5, 0), Vector3(3.0, WALL_H, 2 * HZ - 0.5), _brick_tri)
	# internal WOODEN switchback stair (flights + landings), 6 m floor -> 18 m roof, filling
	# the interior; tops out under a hatch in the roof so a character climbs through.
	var kput := func(p: Vector3, s: Vector3, yv: float) -> void: _box_into_y(keep, p, s, yv, _wood)
	var kramp := func(f: Vector3, dr: Vector3, rt: float, ri: float, w: float) -> void: _ramp_into(keep, f, dr, rt, ri, w)
	var kws := _wooden_core(kput, kramp, Vector3(0, 0, 0), WALL_H, 3 * WALL_H, Vector3(1, 0, 0), 7.0, 2.2, 3.0)
	# ROOF at 18 m: full deck minus the stair hatch over the top flight.
	var ry := 3 * WALL_H - 0.15
	var hc: Vector3 = kws["hatch_c"]
	var hd: Vector3 = kws["hatch_d"]
	var hs := hd.cross(Vector3.UP).normalized()
	var hrun: float = kws["hatch_run"]
	var hw: float = kws["hatch_w"]
	var rstep := 1.5
	var rmx: int = int(HX / rstep) + 1
	var rmz: int = int(HZ / rstep) + 1
	for ix in range(-rmx, rmx + 1):
		for iz in range(-rmz, rmz + 1):
			var px := ix * rstep
			var pz := iz * rstep
			if absf(px) > HX or absf(pz) > HZ:
				continue
			var rel := Vector3(px - hc.x, 0.0, pz - hc.z)
			if absf(rel.dot(hd)) < hrun * 0.5 and absf(rel.dot(hs)) < hw * 0.5:
				continue                                   # stair hatch
			_box_into(keep, Vector3(px, ry, pz), Vector3(rstep + 0.05, 0.3, rstep + 0.05), _floor_mat)
	# buttress pilasters framing the gate (x=+-3) and the front corners (x=+-HX), base to crown
	for px in [-HX, -WALL_H * 0.5, WALL_H * 0.5, HX]:
		_box_into(keep, Vector3(px, 3 * WALL_H * 0.5, HZ + 0.35), Vector3(1.2, 3 * WALL_H, 1.1), _brick_tri)
	# crown: machicolation band just under the parapet on the front, then battlements
	# all around (front/back/sides), reaching the corners.
	var top := 3 * WALL_H
	for c in 3:
		var fx := -HX + c * WALL_H + WALL_H * 0.5
		_put_into(keep, "Wall_Machicolation", Vector3(fx, top - 1.0, HZ), 0.0)
		_put_into(keep, "Wall_Battlements", Vector3(fx, top, HZ), 0.0)
		_put_into(keep, "Wall_Battlements", Vector3(HX - c * WALL_H - WALL_H * 0.5, top, -HZ), PI)
	for c in 2:
		_put_into(keep, "Wall_Battlements", Vector3(HX, top, HZ - c * WALL_H - WALL_H * 0.5), PI * 0.5)
		_put_into(keep, "Wall_Battlements", Vector3(-HX, top, -HZ + c * WALL_H + WALL_H * 0.5), PI * 1.5)

# Courtine_Wall facing + solid brick core (thickness) + kit Wall_Floor walk + kit
# Wall_Battlements parapet, seated on the plateau. Gate = Courtine_Door_Arch.
func _wall_run(a: Vector3, b: Vector3, has_gate: bool) -> void:
	var full := (b - a).normalized()
	# no inset: runs meet exactly at the arc nodes so the wall-walk is continuous
	var a2 := a
	var b2 := b
	var span := b2 - a2
	var length := span.length()
	if length < 3.0:
		return
	var dir := span / length
	var yaw := atan2(-dir.z, dir.x)
	var n: int = maxi(1, int(round(length / MODULE)))
	var step := length / n
	var gate_j := n / 2 if has_gate else -1
	var up := Vector3(0, WALL_H, 0)
	for j in n:
		var base_p := a2 + dir * step * j
		var ctr := a2 + dir * step * (float(j) + 0.5)
		var inw := _inward(ctr)
		var back := Vector3(ctr.x + inw.x * (WALL_THICK * 0.5 + 0.2), _base + WALL_H * 0.5, ctr.z + inw.z * (WALL_THICK * 0.5 + 0.2))
		if j == gate_j:
			# gate keep / donjon (ref screenshot): gate passage, arched windows,
			# arrow-slits, machicolation overhang + battlement crown at 18 m.
			_put("Courtine_Door_Arch", base_p, yaw)                                                           # storey 0: gate
			_box(Vector3(back.x, _base + WALL_H + 0.15, back.z), Vector3(step + 0.1, 0.3, WALL_THICK + 0.4), yaw, _floor_mat)  # passage roof
			_put("Courtine_Window_Arch", base_p + up, yaw)                                                    # storey 1: windows
			_box(Vector3(back.x, _base + WALL_H * 1.5, back.z), Vector3(step + 0.1, WALL_H, WALL_THICK), yaw, _brick_tri)
			_put("Courtine_Slits", base_p + up * 2.0, yaw)                                                    # storey 2: slits
			_box(Vector3(back.x, _base + WALL_H * 2.5, back.z), Vector3(step + 0.1, WALL_H, WALL_THICK), yaw, _brick_tri)
			_put("Wall_Machicolation", ctr + up * 3.0, yaw)                                                   # overhang
			_put("Wall_Battlements", ctr + up * 3.0, yaw)                                                     # crown at 18 m
			continue
		_put("Courtine_Wall", base_p, yaw)
		_box(back, Vector3(step + 0.1, WALL_H, WALL_THICK), yaw, _brick_tri)
		# walk floor (top surface at _base+WALL_H, unified with tower deck + walk ring)
		_box(Vector3(back.x, _base + WALL_H - 0.15, back.z), Vector3(step + 0.1, 0.3, WALL_THICK + 0.4), yaw, _floor_mat)
		_put("Wall_Battlements", Vector3(ctr.x, _base + WALL_H, ctr.z), yaw)

const TOWER_COURSES := 2   # 12 m -> taller than the 6 m wall

# One CONTINUOUS wall-walk floor at 6 m following the whole arc, on the courtyard
# side of the parapet. It bridges every junction (wall<->tower<->donjon) so the walk
# is an unbroken path: rampart -> tower platform -> through the donjon -> rampart.
func _build_walk_ring() -> void:
	var a0 := _tower_angle(0)
	var a1 := _tower_angle(RUNS)
	var wr := WALL_R - (WALL_THICK * 0.5 + 1.3)      # walk centre, just inside the wall
	var n := 200
	# break the ribbon over each tower: the tower's own floor disc (r=6.4 at 6 m) bridges the
	# gap, so the walk crosses THROUGH the tower deck instead of piercing the drum walls.
	var tw_angs: Array = []
	for k in _tower_ks():
		tw_angs.append(_tower_angle(k))
	var gap := 0.10
	var prev = null
	for i in range(0, n + 1):
		var ang: float = lerp(a0, a1, float(i) / float(n))
		var in_gap := false
		for ta in tw_angs:
			if _ang_gap(ang, ta) < gap:
				in_gap = true
				break
		if in_gap:
			prev = null
			continue
		var p := Vector3(CX + wr * cos(ang), _base + WALL_H, CZ + wr * sin(ang))
		if prev != null:
			var pv: Vector3 = prev
			var seg := p - pv
			var l := seg.length()
			var mid := (p + pv) * 0.5
			var yaw := atan2(-seg.z, seg.x)
			_box(Vector3(mid.x, mid.y - 0.15, mid.z), Vector3(l + 0.4, 0.3, 3.4), yaw, _floor_mat)
		prev = p

const TOWER_PROJECT := 2.0    # project outward but keep the drum (outer r = WALL_R+2+6 = 52) within R_FLAT

func _proj_pt(a: float) -> Vector3:
	return Vector3(CX + (WALL_R + TOWER_PROJECT) * cos(a), _base, CZ + (WALL_R + TOWER_PROJECT) * sin(a))

func _build_towers() -> void:
	var gate_run := RUNS / 2
	for k in RUNS + 1:
		if k == gate_run or k == gate_run + 1:
			continue                              # the two apex nodes are replaced by the donjon
		if k == 0 or k == RUNS:
			continue                              # no terminal towers: the wall dies into the rock
		_round_tower(_proj_pt(_tower_angle(k)))

# Real round drum from 4x Wall_Corner_Round per course (arc centre local (6,0,-6);
# origin offset so the four quarters share one axis => a closed radius-6 cylinder).
# Gallery deck flush with the wall-walk (6 m) for the wall->tower passage; a full
# battlement ring + deck crown the top (12 m). Uniform kit brick throughout.
func _drum(centre: Vector3, courses: int, base_yaw: float, skip: Array) -> void:
	for course in courses:
		var y := _base + course * WALL_H
		for q in 4:
			if q in skip:
				continue
			var basis := Basis(Vector3.UP, base_yaw + deg_to_rad(q * 90.0))
			_put_b("Wall_Corner_Round", Vector3(centre.x, y, centre.z) - basis * ARC_C, basis)

func _deck(centre: Vector3, y: float, base_yaw: float, skip: Array) -> void:
	for q in 4:
		if q in skip:
			continue
		var basis := Basis(Vector3.UP, base_yaw + deg_to_rad(q * 90.0))
		_put_b("Wall_Floor_Round", Vector3(centre.x, y, centre.z) - basis * ARC_C2, basis)

func _ring(centre: Vector3, y: float, base_yaw: float, skip: Array) -> void:
	for q in 4:
		if q in skip:
			continue
		var basis := Basis(Vector3.UP, base_yaw + deg_to_rad(q * 90.0))
		_put_b("Wall_Battlements_Corner_Round", Vector3(centre.x, y, centre.z) - basis * ARC_C2, basis)

const TOWER_SEG := 22        # facets in the drum (reads round)
const TOWER_RAD := 6.0       # outer radius
const TOWER_WALL := 0.7      # shell thickness

# Angular half-distance between two headings (0..PI).
func _ang_gap(a: float, b: float) -> float:
	var d: float = fmod(absf(a - b), TAU)
	return d if d <= PI else TAU - d

# Spiral stone stair inside a drum: a central newel + treads winding up from y0 to y1.
func _spiral_stairs(centre: Vector3, y0: float, y1: float, tread_r: float, start_ang: float, turns: float) -> void:
	var rise := y1 - y0
	var n := 24
	var dh := rise / float(n)                                   # 0.5 m rise per step
	var dang := turns * TAU / float(n)
	_box(Vector3(centre.x, (y0 + y1) * 0.5, centre.z), Vector3(1.1, rise, 1.1), 0.0, _brick_tri)  # newel
	for i in n:
		var a := start_ang + dang * i
		var h := y0 + dh * (i + 1)                              # tread top
		var c := Vector3(centre.x + tread_r * cos(a), h - 0.25, centre.z + tread_r * sin(a))
		# WIDE treads (2.4 m tangential > the 30-deg chord) so consecutive steps overlap into
		# a continuous, gap-free helical surface a capsule can actually walk up.
		_box(c, Vector3(2.4, 0.5, 4.2), PI * 0.5 - a, _floor_mat)

# Annular roof RING (open centre): the spiral tops out into the open middle with no roof
# crushing the last steps; you step outward onto the ring at 12 m.
func _tower_roof(centre: Vector3, y: float) -> void:
	var r_out := TOWER_RAD - 0.2
	var r_in := 4.5        # wide open centre so the spiral rises to 12 m in clear air, then step out onto the ring
	var step := 1.4
	var m: int = int(r_out / step) + 1
	for ix in range(-m, m + 1):
		for iz in range(-m, m + 1):
			var px := ix * step
			var pz := iz * step
			var rr := sqrt(px * px + pz * pz)
			if rr > r_out or rr < r_in:
				continue
			_box(Vector3(centre.x + px, y - 0.15, centre.z + pz), Vector3(step + 0.05, 0.3, step + 0.05), 0.0, _floor_mat)

# Solid brick-floor disc filling the drum at height y (a floor to stand on). Extends to the
# wall face so there is NO gap at the door threshold to fall through.
func _tower_floor(centre: Vector3, y: float) -> void:
	var rdeck := TOWER_RAD + 0.4
	var step := 1.4
	var m: int = int(rdeck / step) + 1
	for ix in range(-m, m + 1):
		for iz in range(-m, m + 1):
			var px := ix * step
			var pz := iz * step
			if sqrt(px * px + pz * pz) > rdeck:
				continue
			_box(Vector3(centre.x + px, y - 0.15, centre.z + pz), Vector3(step + 0.05, 0.3, step + 0.05), 0.0, _floor_mat)

# HOLLOW faceted brick tower (12 m, taller than the 6 m wall) entered FROM THE WALL-WALK:
# solid base (0-6 m), a floor at 6 m level with the rampart, a doorway on the courtyard
# side at 6-12 m where the walk passes in, an internal SPIRAL winding 6 m -> 12 m roof
# (hatch + merlon crown). Boxes textured with the kit brick (kit round quarters are
# solid-filled and leave no usable interior).
func _round_tower(centre: Vector3) -> void:
	var inw := _inward(centre)
	# the wall meets the tower on TWO sides (tangential to the arc); a door on each so the
	# rampart-walk passes THROUGH the tower (enter one side, exit the other).
	var radial_ang := atan2(centre.z - CZ, centre.x - CX)
	# the walk ring crosses the projecting drum at two points ~+/-0.65 rad off the courtyard
	# direction; put a door at EACH so the rampart passes cleanly THROUGH the tower.
	var door_a := radial_ang + PI + 0.65
	var door_b := radial_ang + PI - 0.65
	var top := _base + TOWER_COURSES * WALL_H                 # 12 m
	var mid := _base + WALL_H                                 # 6 m walk level
	var seg := TAU / float(TOWER_SEG)
	var chord := 2.0 * TOWER_RAD * sin(seg * 0.5) + 0.2       # slight overlap so facets seal
	var rmid := TOWER_RAD - TOWER_WALL * 0.5
	for course in TOWER_COURSES:
		var y0 := _base + course * WALL_H
		for i in TOWER_SEG:
			var a := i * seg
			if course == 1 and (_ang_gap(a, door_a) < seg * 1.9 or _ang_gap(a, door_b) < seg * 1.9):
				continue                                   # two walk-level doorways where the rampart enters/exits
			var px := centre.x + rmid * cos(a)
			var pz := centre.z + rmid * sin(a)
			_box(Vector3(px, y0 + WALL_H * 0.5, pz), Vector3(chord, WALL_H, TOWER_WALL), PI * 0.5 - a, _brick_tri)
	# merlon crown: alternating blocks around the rim at the roof line
	for i in TOWER_SEG:
		if i % 2 == 1:
			continue
		var a := i * seg
		var px := centre.x + TOWER_RAD * cos(a)
		var pz := centre.z + TOWER_RAD * sin(a)
		_box(Vector3(px, top + 0.7, pz), Vector3(chord * 0.9, 1.4, TOWER_WALL + 0.2), PI * 0.5 - a, _brick_tri)
	_tower_floor(centre, mid)                                 # floor at 6 m, flush with the rampart
	# wooden switchback stair (flights + landings) winding up the drum, 6 m -> 12 m roof
	var ro := Vector3(cos(radial_ang), 0.0, sin(radial_ang))  # flights fold across the drum (radial axis)
	var put := func(p: Vector3, s: Vector3, yv: float) -> void: _box(p, s, yv, _wood)
	var ramp := func(f: Vector3, dr: Vector3, rt: float, ri: float, w: float) -> void: _stair_ramp(f, dr, rt, ri, w)
	var ws := _wooden_core(put, ramp, centre, mid, top, ro, 4.0, 1.9, 3.0)
	_tower_roof_hatch(centre, top, ws["hatch_c"], ws["hatch_d"], ws["hatch_run"], ws["hatch_w"])
	# FULL-size arched door in each wall-side opening (like the keep gate) — the 6 m panel
	# fills the opening (no gaps around it), recessed so it sits flush with the round face.
	var doors: Array[float] = [door_a, door_b]
	for da in doors:
		var dyaw: float = PI * 0.5 - da
		var wx := Vector3(cos(dyaw), 0, -sin(dyaw))           # piece local +X after yaw
		var p := Vector3(centre.x + cos(da) * (TOWER_RAD - 0.7), mid, centre.z + sin(da) * (TOWER_RAD - 0.7))
		_put_s("Courtine_Door_Arch", p - wx * (WALL_H * 0.5), dyaw, Vector3(1.0, 1.0, 0.5))
	var wr_f := WALL_R - 2.6                                  # walk-ring radius (fortress)
	nav["towers"].append({
		"centre": centre,
		"entry": Vector3(CX + cos(radial_ang) * wr_f, mid, CZ + sin(radial_ang) * wr_f),  # on the walk at the courtyard door
		"inside": centre + Vector3(0, WALL_H, 0),             # tower centre on the 6 m floor (stair base)
		"roof": (ws["top"] as Vector3) + Vector3(0, 0.3, 0), # top landing of the wooden stair, at the roof hatch
	})

# Round top platform (brick-floor boxes) filling the drum with a central square
# hatch so the internal stair emerges onto the roof. Battlement ring (full) sits at
# the true rim, so the crown stays complete while the deck has a real opening.
func _deck_with_hatch(centre: Vector3, y: float) -> void:
	var rdeck := TOWER_R - 0.4
	var hole := 1.4
	var step := 1.5
	var n: int = int(rdeck / step)
	for ix in range(-n, n + 1):
		for iz in range(-n, n + 1):
			var px := ix * step
			var pz := iz * step
			if sqrt(px * px + pz * pz) > rdeck:
				continue
			if absf(px) < hole and absf(pz) < hole:
				continue                                   # central stair hatch
			_box(Vector3(centre.x + px, y - 0.15, centre.z + pz), Vector3(step + 0.05, 0.3, step + 0.05), 0.0, _floor_mat)

# Compute one wide mural stair per curtain run (ALONG the wall) and its angular span, so
# the walk ring can leave an opening over it (otherwise the walk floor is a ceiling and the
# stair is unclimbable). Runs BEFORE the walk ring.
const STAIR_WIDTH := 4.0
func _prep_stairs() -> void:
	_stair_specs.clear()
	var gate_run := RUNS / 2
	for k in RUNS:
		if k == gate_run:
			continue
		var a := _arc_pt(_tower_angle(k))
		var b := _arc_pt(_tower_angle(k + 1))
		var mid := (a + b) * 0.5
		var dir := (b - a).normalized()                  # ALONG the wall
		var inw := _inward(mid)                           # toward courtyard centre
		var offset := inw * (WALL_THICK * 0.5 + STAIR_WIDTH * 0.5)
		var length := 0.55 * (WALL_H / 0.5)
		var top_xz := Vector3(mid.x + dir.x * length * 0.5, _base, mid.z + dir.z * length * 0.5) + offset
		var foot := top_xz - dir * length
		var af := atan2(foot.z - CZ, foot.x - CX)
		var at := atan2(top_xz.z - CZ, top_xz.x - CX)
		_stair_specs.append({
			"foot": foot, "dir": dir, "top": top_xz, "inw": inw,
			"a0": minf(af, at) - 0.03, "a1": maxf(af, at) + 0.03,
		})

# Build the mural stairs from the specs: wide steps + collision ramp, seated on the
# courtyard floor, climbing along the wall to the rampart (the walk is open above them).
func _build_stairs() -> void:
	for s in _stair_specs:
		var foot: Vector3 = s["foot"]
		var dir: Vector3 = s["dir"]
		var top_xz: Vector3 = s["top"]
		_stone_stairs(foot, dir, _base + WALL_H, STAIR_WIDTH)
		var land := Vector3(top_xz.x + dir.x * 1.5, _base + WALL_H, top_xz.z + dir.z * 1.5)
		_box(Vector3(land.x, _base + WALL_H - 0.15, land.z), Vector3(3.4, 0.3, STAIR_WIDTH + 0.4), atan2(-dir.z, dir.x), _floor_mat)
		nav["stairs"].append({
			"foot": Vector3(foot.x + dir.x * 0.5, _base, foot.z + dir.z * 0.5),
			"top": land,
			"landing": land,
		})

# Give every spawned mesh a static trimesh collider so a CharacterBody can walk/stand
# on the walls, floors, stairs, spiral and roofs (the terrain already has collision).
func _add_collision() -> void:
	var meshes: Array = []
	var stack: Array = [self]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D and n.mesh and not (n.name == "Capsule"):
			meshes.append(n)
		for c in n.get_children():
			stack.append(c)
	for m in meshes:
		m.create_trimesh_collision()

func _place_capsule() -> void:
	var mesh := CapsuleMesh.new(); mesh.radius = 0.3; mesh.height = 1.8
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.name = "Capsule"
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
