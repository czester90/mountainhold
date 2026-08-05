@tool
class_name CastleModule
extends Node3D

## Base for every reusable castle piece. Each module builds its geometry under a single
## `GeneratedGeometry` child that can be safely cleared and rebuilt (@tool, editor-live).
## Snap points are persistent Marker3D children whose local -Z is the port's OUTWARD normal;
## the generator docks pieces by matching one port to another (see `compute_dock`).

const GEN_NAME := "GeneratedGeometry"

@export var rebuild_now: bool = false:
	set(value):
		rebuild_now = false
		if is_inside_tree():
			rebuild()

var _mat_stone: StandardMaterial3D
var _mat_floor: StandardMaterial3D
var _mat_wood: StandardMaterial3D

func _ready() -> void:
	rebuild()

# --- generated-geometry lifecycle ----------------------------------------

func gen() -> Node3D:
	var n := get_node_or_null(GEN_NAME)
	if n == null:
		n = Node3D.new()
		n.name = GEN_NAME
		add_child(n)
	return n

func clear_generated() -> void:
	var n := get_node_or_null(GEN_NAME)
	if n:
		for c in n.get_children():
			n.remove_child(c)
			c.free()

func rebuild() -> void:
	clear_generated()
	_construct()
	build_collision()
	validate_geometry()

# subclasses override these
func _construct() -> void:
	pass

func build_collision() -> void:
	trimesh_generated()

func validate_geometry() -> void:
	pass

# --- snap points ----------------------------------------------------------

func _face(outward: Vector3) -> Basis:
	var o := outward
	o.y = 0.0
	if o.length() < 0.001:
		return Basis.IDENTITY
	o = o.normalized()
	return Basis(Vector3.UP, atan2(-o.x, -o.z))       # local -Z -> outward

func set_snap(snap_name: String, pos: Vector3, outward: Vector3) -> void:
	var m := get_node_or_null(snap_name) as Marker3D
	if m == null:
		m = Marker3D.new()
		m.name = snap_name
		add_child(m)
	m.transform = Transform3D(_face(outward), pos)

func snap(snap_name: String) -> Marker3D:
	return get_node_or_null(snap_name) as Marker3D

# Global transform for `mover` so that its `mover_port` mates face-to-face with
# `anchor`'s `anchor_port` (positions coincide, outward normals oppose).
static func compute_dock(anchor_global: Transform3D, anchor_port_local: Transform3D, mover_port_local: Transform3D) -> Transform3D:
	var flip := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	return anchor_global * anchor_port_local * flip * mover_port_local.affine_inverse()

# --- shared building blocks ----------------------------------------------

func mat_stone() -> StandardMaterial3D:
	return CastleKit.brick_tri()

func mat_floor() -> StandardMaterial3D:
	return CastleKit.floor_mat()

func mat_wood() -> StandardMaterial3D:
	return CastleKit.wood()

func mat_wood_dark() -> StandardMaterial3D:
	return CastleKit.wood_dark()

# Instance a kit mesh (real Loafbrr geometry) with its proper per-surface materials.
func add_kit(mesh_name: String, pos: Vector3, yaw: float = 0.0, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var m := CastleKit.mesh(mesh_name)
	if m == null:
		push_warning("kit mesh missing: " + mesh_name)
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = m
	for i in m.get_surface_count():
		var sm = m.surface_get_material(i)
		mi.set_surface_override_material(i, CastleKit.mat(sm.resource_name if sm else ""))
	mi.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(scale), pos)
	gen().add_child(mi)
	return mi

# Visual-only sub-node: meshes placed here render but are SKIPPED by trimesh_generated (which
# only collides direct MeshInstance children of gen()). Used for stair treads/risers/stringers so
# their vertical faces don't catch the player capsule — the walkable surface is the ramp instead.
func gen_visual() -> Node3D:
	var g := gen()
	var v := g.get_node_or_null("Visual")
	if v == null:
		v = Node3D.new()
		v.name = "Visual"
		g.add_child(v)
	return v

func add_box_visual(centre: Vector3, size: Vector3, mat: StandardMaterial3D, yaw: float = 0.0) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = mat
	mi.transform = Transform3D(Basis(Vector3.UP, yaw), centre)
	gen_visual().add_child(mi)
	return mi

func add_box(centre: Vector3, size: Vector3, mat: StandardMaterial3D, yaw: float = 0.0) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = mat
	mi.transform = Transform3D(Basis(Vector3.UP, yaw), centre)
	gen().add_child(mi)
	return mi

# One MultiMeshInstance3D of identical boxes at the given transforms (repeatable detail).
func add_box_multimesh(size: Vector3, mat: StandardMaterial3D, xforms: Array) -> MultiMeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	gen().add_child(mmi)
	return mmi

# Collision-only inclined slab (for smooth character movement up a flight of steps).
func add_ramp(foot: Vector3, dir: Vector3, run_total: float, rise: float, width: float) -> void:
	var fwd := (dir * run_total + Vector3.UP * rise).normalized()
	var side := dir.cross(Vector3.UP).normalized()
	var upn := side.cross(fwd).normalized()
	if upn.y < 0.0:
		upn = -upn
		side = -side
	var hyp := sqrt(run_total * run_total + rise * rise)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(width, 0.5, hyp)
	cs.shape = bs
	body.add_child(cs)
	body.transform = Transform3D(Basis(side, upn, fwd), foot + dir * (run_total * 0.5) + Vector3.UP * (rise * 0.5) - upn * 0.22)
	gen().add_child(body)

func trimesh_generated() -> void:
	for c in gen().get_children():
		if c is MeshInstance3D and c.mesh:
			c.create_trimesh_collision()

# A row of crenellations (merlons + gaps) along the OUTER-EDGE segment a->b at walk top a.y,
# facing `outward`. Merlons are pushed inward by half their depth so their outer face sits ON
# the edge (never cantilevered past it), and their base overlaps the walk (no floating). Inset
# from both ends so rows never collide at module junctions. One MultiMesh.
func merlon_line(a: Vector3, b: Vector3, outward: Vector3, inset: float = 1.0) -> void:
	var seg := b - a
	var length := seg.length()
	if length < 1.5:
		return
	var dir := seg / length
	var yaw := atan2(-dir.z, dir.x)
	var inward := -outward.normalized()
	var mw := 0.9
	var mg := 0.9
	var mh := 1.0
	var md := 0.6
	var period := mw + mg
	var usable := length - 2.0 * inset
	if usable < mw:
		return
	var count: int = maxi(1, int(floor((usable + mg) / period)))
	var span := count * period - mg
	var start := inset + (usable - span) * 0.5 + mw * 0.5
	var xf: Array = []
	for i in count:
		var c := a + dir * (start + i * period) + inward * (md * 0.5)
		xf.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, a.y + mh * 0.5 - 0.15, c.z)))
	add_box_multimesh(Vector3(mw, mh, md), mat_stone(), xf)

func _ang_gap(a: float, b: float) -> float:
	var d: float = fmod(absf(a - b), TAU)
	return d if d <= PI else TAU - d

# Wooden switchback: flights zig-zagging up y0->y1 along +/- d in two lanes offset in `side`,
# joined by landings; a collision ramp under each flight. Returns {top, hatch_c, hatch_d,
# hatch_run, hatch_w} so a roof deck can leave a hatch over the top flight.
func build_wooden_switchback(centre: Vector3, y0: float, y1: float, d: Vector3, run: float, width: float, per_flight: float, step_rise: float = 0.42) -> Dictionary:
	var rise := y1 - y0
	var side := d.cross(Vector3.UP).normalized()
	var nf: int = maxi(1, int(round(rise / per_flight)))
	var per := rise / float(nf)
	var steps: int = maxi(3, int(round(per / step_rise)))
	var r := per / float(steps)
	var tread := run / float(steps)
	var lane := width * 0.5 + 0.2
	# hatch = a SLOT over the top flight: long enough (run) for the climber to clear the deck edge,
	# but only a little wider than the flight (a snug slot, not a gaping square hole in the floor)
	var out := {"top": centre, "entry": centre, "entry_out": -d, "exit_out": d, "hatch_c": centre, "hatch_d": d, "hatch_run": run + 2.4, "hatch_w": width + 1.1}
	var wood := mat_wood()
	var wood_d := mat_wood_dark()
	var run_len := tread * float(steps)
	for f in nf:
		var up_dir: Vector3 = d if (f % 2 == 0) else -d
		var lo: Vector3 = side * (lane if (f % 2 == 0) else -lane)
		var fy := y0 + f * per
		var bottom := centre + lo - up_dir * (run * 0.5)
		var yaw := atan2(-up_dir.z, up_dir.x)
		for i in steps:
			var c := bottom + up_dir * (tread * (float(i) + 0.5))
			var top_y := fy + r * (float(i) + 1.0)
			# dark riser (vertical face of the step) first, then a lighter tread with a nosing
			# that overhangs it -> a clear shadow line per step, so steps never merge into a ramp
			var riser_c := bottom + up_dir * (tread * float(i))
			# treads/risers are VISUAL ONLY — the ramp below carries the collision, so nothing
			# vertical can catch the capsule on the flight or at the switchback turn.
			add_box_visual(Vector3(riser_c.x, top_y - r * 0.5, riser_c.z), Vector3(0.12, r, width), wood_d, yaw)
			add_box_visual(Vector3(c.x + (up_dir.x * 0.06), top_y - 0.05, c.z + (up_dir.z * 0.06)), Vector3(tread + 0.18, 0.1, width + 0.06), wood, yaw)
		add_ramp(Vector3(bottom.x, fy, bottom.z), up_dir, run_len, per, width)
		_stringers(Vector3(bottom.x, fy, bottom.z), up_dir, run_len, per, width, wood_d)
		# roomy landing (collision) pushed OUT past the flight top (not overhanging it) so the
		# climber never bumps their head on it near the top of the lower flight
		var land_c := centre + up_dir * (run * 0.5 + 1.2)
		var ly := fy + per
		add_box(Vector3(land_c.x, ly - 0.08, land_c.z), Vector3(2.4, 0.16, 2.0 * lane + width + 0.4), wood, yaw)
		if f == 0:
			out["entry"] = Vector3(bottom.x, fy, bottom.z)
			out["entry_out"] = -up_dir
		if f == nf - 1:
			out["top"] = Vector3(land_c.x, ly, land_c.z)
			out["exit_out"] = up_dir
			out["hatch_c"] = centre + lo
			out["hatch_d"] = up_dir
	return out

# Two sloped wooden side-beams (stringers) tying the treads of one flight into a solid run.
func _stringers(foot: Vector3, dir: Vector3, run_total: float, rise: float, width: float, wood: StandardMaterial3D) -> void:
	var fwd := (dir * run_total + Vector3.UP * rise).normalized()
	var side := dir.cross(Vector3.UP).normalized()
	var upn := side.cross(fwd).normalized()
	if upn.y < 0.0:
		upn = -upn
		side = -side
	var hyp := sqrt(run_total * run_total + rise * rise)
	var mid := foot + dir * (run_total * 0.5) + Vector3.UP * (rise * 0.5)
	for s in [-1.0, 1.0]:
		var b := BoxMesh.new()
		b.size = Vector3(0.16, 0.34, hyp)
		var mi := MeshInstance3D.new()
		mi.mesh = b
		mi.material_override = wood
		mi.transform = Transform3D(Basis(side, upn, fwd), mid + side * (width * 0.5 * s) - upn * 0.12)
		gen_visual().add_child(mi)

# Thick solid brick disc, TOP surface at y, `thick` deep, radius r, clean round rim. Optional
# CLEAN RECTANGULAR hatch: the deck is the ring between the exact rectangle and the exact
# circle, so the opening is a precise rectangle (no ragged cell-removal). One merged ArrayMesh.
func build_disc(centre: Vector3, y: float, r: float, thick: float, want_hatch: bool, hc: Vector3, hd: Vector3, hrun: float, hw: float) -> void:
	var hs := hd.cross(Vector3.UP).normalized()
	var p0 := hc - centre                                     # ray origin (hatch centre) in local space
	var hr := hrun * 0.5
	var hw2 := hw * 0.5
	var seg := 96
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# sample inner (rectangle) and outer (circle) boundary points along rays from the hatch centre
	var inner: Array = []
	var outer: Array = []
	for i in seg + 1:
		var t := float(i) * TAU / float(seg)
		var dir := Vector3(cos(t), 0.0, sin(t))
		# rectangle boundary distance from p0 (box ray from its own centre)
		var dxd := dir.dot(hd)
		var dyd := dir.dot(hs)
		var r_rect := 1e9
		if absf(dxd) > 1e-5:
			r_rect = minf(r_rect, hr / absf(dxd))
		if absf(dyd) > 1e-5:
			r_rect = minf(r_rect, hw2 / absf(dyd))
		# circle boundary distance from p0 (circle centred at local origin, radius r)
		var b := p0.dot(dir)
		var c := p0.dot(p0) - r * r
		var disc := maxf(0.0, b * b - c)
		var r_circ := -b + sqrt(disc)
		if not want_hatch:
			r_rect = 0.0                                      # solid disc: inner ring collapses to centre
		r_rect = minf(r_rect, r_circ - 0.2)
		inner.append(centre + p0 + dir * r_rect)
		outer.append(centre + p0 + dir * r_circ)
	# top + bottom caps
	for surf in [[y, false], [y - thick, true]]:
		var yy: float = surf[0]
		var flip: bool = surf[1]
		var nrm := Vector3.DOWN if flip else Vector3.UP
		for i in seg:
			var oi: Vector3 = outer[i]; oi.y = yy
			var oj: Vector3 = outer[i + 1]; oj.y = yy
			var ii: Vector3 = inner[i]; ii.y = yy
			var ij: Vector3 = inner[i + 1]; ij.y = yy
			var order := [ii, oi, oj, ii, oj, ij]
			if flip:
				order.reverse()
			for v in order:
				st.set_normal(nrm)
				st.add_vertex(v)
	# outer rim + inner hatch walls (visible thickness)
	for i in seg:
		for pair in [[outer, true], [inner, false]]:
			var arr: Array = pair[0]
			var outward: bool = pair[1]
			if arr == inner and not want_hatch:
				continue
			var a0: Vector3 = arr[i]
			var a1: Vector3 = arr[i + 1]
			var t0 := Vector3(a0.x, y, a0.z)
			var t1 := Vector3(a1.x, y, a1.z)
			var b0 := Vector3(a0.x, y - thick, a0.z)
			var b1 := Vector3(a1.x, y - thick, a1.z)
			var quad := [t0, t1, b1, t0, b1, b0]
			if not outward:
				quad.reverse()
			var nrm := (Vector3((a0.x + a1.x) * 0.5 - centre.x, 0, (a0.z + a1.z) * 0.5 - centre.z)).normalized()
			for v in quad:
				st.set_normal(nrm if outward else -nrm)
				st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat_floor()
	gen().add_child(mi)

# Thick solid brick floor disc (top at y).
func disc_floor(centre: Vector3, y: float, r: float) -> void:
	build_disc(centre, y, r, 0.7, false, centre, Vector3.RIGHT, 0.0, 0.0)

# Thick solid brick deck (top at y) with a rectangular hatch over the top flight.
func deck_with_hatch(centre: Vector3, y: float, r: float, hc: Vector3, hd: Vector3, hrun: float, hw: float) -> void:
	build_disc(centre, y, r, 0.9, true, hc, hd, hrun, hw)
