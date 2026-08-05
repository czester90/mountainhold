@tool
class_name GateTower
extends CastleModule

## Modular medieval GATE TOWER (wieża bramna). An ENCLOSED four-walled tower straddling the curtain:
##  - Tier 0: solid base ground->walk, pierced only by the central arched passage (no side bypass).
##  - The FIELD wall is FLUSH with the curtain outer face (the tower body projects INWARD, into the
##    bailey, where there is room) — set by D_FIELD (thin front) vs D_COURT (deep court body).
##  - A real OPENABLE double-leaf timber gate stands in the passage (visible, shown open).
##  - Tier 1: an interior firing gallery — field & court walls rise walk->top with real arrow-loop
##    OPENINGS you shoot through; SIDE walls close the tower with a door at walk level so the curtain
##    wall-walk enters through a proper doorway (a tower, not an open tunnel).
##  - Tier 2: an open battlemented roof reached by an interior stair on the COURTYARD side.
## Depths are asymmetric so the front lines up with the wall; the walk snap stays on the centreline
## so the curtain docks unchanged.

@export var definition: GatehouseDefinition = GatehouseDefinition.new():
	set(value):
		definition = value
		if is_inside_tree():
			rebuild()

var _leaf_pivots: Array = []     # the two swinging timber leaves
var _barrier: StaticBody3D = null # solid collision plugging the passage while the gate is shut

func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("gate")     # the WaveSpawner drives set_gate_open() on this

const D_FIELD := 0.45       # depth toward the FIELD (world -X) — thin front, flush with the curtain face
const D_COURT := 6.5        # depth toward the COURTYARD (world +X) — the tower body projects inward
const WALL_T := 0.7         # gallery wall thickness
const DOOR_Z := 1.15        # local-z centre of the side doorway (on the curtain walk lane, offset to court)
const DOOR_HW := 2.3        # side doorway half-width (z) — generous so the rampart crosses cleanly
const DOOR_H := 2.4         # side doorway headroom above the walk

func field_gallery_slot_z() -> float:
	return -D_FIELD + WALL_T + 0.35

func field_roof_slot_z() -> float:
	return -D_FIELD + 1.0

func _construct() -> void:
	var d := definition
	var hx := d.length * 0.5
	var wy := d.height
	var pw := d.passage_width * 0.5
	var z0 := -D_FIELD                          # field face (local z, world -X)
	var z1 := D_COURT                           # court face (local z, world +X)
	var depth := z1 - z0
	var czc := (z0 + z1) * 0.5
	var stone := mat_stone()
	# --- TIER 0: solid base 0..walk, pierced only by the central passage (tunnel along local z) ---
	add_box(Vector3(-(pw + hx) * 0.5, wy * 0.5, czc), Vector3(hx - pw, wy, depth), stone)
	add_box(Vector3((pw + hx) * 0.5, wy * 0.5, czc), Vector3(hx - pw, wy, depth), stone)
	if wy - d.passage_height > 0.1:
		add_box_visual(Vector3(0, (d.passage_height + wy) * 0.5, czc), Vector3(d.passage_width, wy - d.passage_height, depth), stone)
	# proud walk/gallery floor (one clean surface across the whole footprint)
	add_box(Vector3(0, wy, czc), Vector3(2.0 * hx, 0.3, depth), mat_floor())
	# --- TIER 1 + 2: firing gallery + open roof ---
	_build_gallery(hx, wy, z0, z1)
	# --- gate fittings ---
	_gate_leaves(wy, pw, z0)                    # real openable timber doors (shown open)
	_arch_ring(z0 - 0.3)                        # masonry arch framing the OPEN field mouth (see-through)
	_arch_ring(z1 + 0.3)                        # and the courtyard mouth
	# walk snap stays on the centreline (z=0) so the curtain docks unchanged
	set_snap("WallWalkEntry", Vector3(-hx, wy, 0), Vector3.LEFT)
	set_snap("WallWalkExit", Vector3(hx, wy, 0), Vector3.RIGHT)

func _build_gallery(hx: float, wy: float, z0: float, z1: float) -> void:
	var d := definition
	var top := wy + maxf(d.tower_height, 4.0)   # gallery/roof deck level
	var sill := wy + 1.1                         # firing-loop sill
	var head := wy + 2.7                         # loop head
	# FIELD + COURT gallery walls (walk->top) with REAL arrow-loop openings you shoot through
	_gallery_wall(hx, z0 + WALL_T * 0.5, wy, top, sill, head, 3)
	_gallery_wall(hx, z1 - WALL_T * 0.5, wy, top, sill, head, 3)
	# SIDE walls close the tower; each has a doorway at walk level for the curtain wall-walk
	_side_wall(-hx + WALL_T * 0.5, wy, top, z0, z1)
	_side_wall(hx - WALL_T * 0.5, wy, top, z0, z1)
	# interior stair on the COURTYARD side (near the court wall) -> open roof
	var ws := build_wooden_switchback(Vector3(-hx + 3.5, 0.0, z1 - 2.2), wy, top, Vector3(1, 0, 0), 4.0, 1.9, 3.0)
	_roof_deck(top - 0.15, hx, z0, z1, ws["hatch_c"], ws["hatch_d"], ws["hatch_run"], ws["hatch_w"])
	merlon_line(Vector3(-hx, top, z0), Vector3(hx, top, z0), Vector3(0, 0, -1))
	merlon_line(Vector3(-hx, top, z1), Vector3(hx, top, z1), Vector3(0, 0, 1))
	_machicolation(hx, wy, z0)
	_banner(top, z0)

# a gallery wall along local X at depth `zc`, y0..y1, with `n` firing openings (gap gy0..gy1)
func _gallery_wall(hx: float, zc: float, y0: float, y1: float, gy0: float, gy1: float, n: int) -> void:
	var stone := mat_stone()
	add_box(Vector3(0, (y0 + gy0) * 0.5, zc), Vector3(2.0 * hx, gy0 - y0, WALL_T), stone)          # sill band
	add_box(Vector3(0, (gy1 + y1) * 0.5, zc), Vector3(2.0 * hx, y1 - gy1, WALL_T), stone)          # head band to the deck
	var ow := 0.55                                                                                 # arrow-loop width
	var edges: Array = [-hx]
	for i in n:
		var x: float = lerpf(-hx + 1.8, hx - 1.8, float(i) / float(maxi(1, n - 1)))
		edges.append(x - ow); edges.append(x + ow)
	edges.append(hx)
	for j in range(0, edges.size(), 2):                                                            # piers between the openings
		var a: float = edges[j]
		var b: float = edges[j + 1]
		if b - a > 0.05:
			add_box(Vector3((a + b) * 0.5, (gy0 + gy1) * 0.5, zc), Vector3(b - a, gy1 - gy0, WALL_T), stone)

# side wall (Y-Z plane at local x=`sx`) closing the tower, with a doorway at the walk for the curtain
func _side_wall(sx: float, wy: float, top: float, z0: float, z1: float) -> void:
	var stone := mat_stone()
	var za := DOOR_Z - DOOR_HW
	var zb := DOOR_Z + DOOR_HW
	var mid_y := (wy + top) * 0.5
	if za - z0 > 0.05:                                                                             # field-side of the door
		add_box(Vector3(sx, mid_y, (z0 + za) * 0.5), Vector3(WALL_T, top - wy, za - z0), stone)
	if z1 - zb > 0.05:                                                                             # court-side of the door
		add_box(Vector3(sx, mid_y, (zb + z1) * 0.5), Vector3(WALL_T, top - wy, z1 - zb), stone)
	var dh := wy + DOOR_H                                                                          # lintel over the doorway
	if top - dh > 0.05:
		add_box(Vector3(sx, (dh + top) * 0.5, DOOR_Z), Vector3(WALL_T, top - dh, zb - za), stone)

# rectangular roof deck = tiles framing a hatch slot over the stair top
func _roof_deck(y: float, hx: float, z0: float, z1: float, hc: Vector3, hd: Vector3, hrun: float, hw: float) -> void:
	var mat := mat_floor()
	var hs := hd.cross(Vector3.UP).normalized()
	var step := 1.5
	var mx: int = int(hx / step) + 1
	var mz: int = int((z1 - z0) / step) + 2
	var czc := (z0 + z1) * 0.5
	for ix in range(-mx, mx + 1):
		for iz in range(-mz, mz + 1):
			var px := float(ix) * step
			var pz := czc + float(iz) * step
			if absf(px) > hx or pz < z0 or pz > z1:
				continue
			var rel := Vector3(px - hc.x, 0.0, pz - hc.z)
			if absf(rel.dot(hd)) < hrun * 0.5 and absf(rel.dot(hs)) < hw * 0.5:
				continue                                                                           # leave the hatch open
			add_box(Vector3(px, y, pz), Vector3(step + 0.05, 0.3, step + 0.05), mat)

# machicolation band on the field face (below the gallery)
func _machicolation(hx: float, level: float, zf: float) -> void:
	var stone := mat_stone()
	add_box(Vector3(0, level - 0.55, zf - 0.25), Vector3(2.0 * hx - 0.4, 0.5, 0.5), stone)
	var n := int(round((2.0 * hx) / 1.6))
	var span := (2.0 * hx - 0.6) / float(maxi(1, n))
	for i in n + 1:
		add_box(Vector3(-hx + 0.3 + span * float(i), level - 1.0, zf - 0.12), Vector3(0.28, 0.5, 0.35), stone)

func _banner(level: float, zf: float) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.22, 0.12)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.18, 0.32, 0.62)
	var base_y := level                                  # stand the pole ON the roof deck (was floating 1.9 m up)
	var pole_h := 4.2
	add_box_visual(Vector3(0, base_y + pole_h * 0.5, zf + 0.6), Vector3(0.12, pole_h, 0.12), wood)
	add_box_visual(Vector3(0.6, base_y + pole_h - 1.1, zf + 0.6), Vector3(1.1, 1.6, 0.06), cloth)

# real double-leaf timber gate in the passage. Starts SHUT (leaves meet across the mouth + a solid
# collision barrier plugs the passage, blocking player AND besiegers). set_gate_open(true) — called
# once the gate is breached — swings the leaves back and removes the barrier so the horde floods in.
func _gate_leaves(wy: float, pw: float, zf: float) -> void:
	_leaf_pivots = []
	var plank := StandardMaterial3D.new()
	plank.albedo_color = Color(0.30, 0.19, 0.10)
	plank.roughness = 0.95
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.10, 0.10, 0.12)
	iron.metallic = 0.5
	iron.roughness = 0.6
	var lh: float = minf(definition.passage_height, wy) - 0.2
	var lw := pw + 0.12                         # each leaf spans its full half + a small overlap so the two MEET (no centre gap)
	for s in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "GateLeaf_%s" % ("L" if s < 0.0 else "R")
		pivot.position = Vector3(s * pw, 0.15, zf + 0.08)                 # hinge at the jamb, field face
		pivot.rotation.y = 0.0                                           # SHUT: leaf lies across the mouth
		gen_visual().add_child(pivot)
		var leaf := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(lw, lh, 0.16)
		leaf.mesh = bm
		leaf.material_override = plank
		leaf.position = Vector3(-s * lw * 0.5, lh * 0.5, 0)              # extends from the jamb to the centre
		pivot.add_child(leaf)
		for by in [lh * 0.22, lh * 0.78]:
			var band := MeshInstance3D.new()
			var bb := BoxMesh.new()
			bb.size = Vector3(lw * 1.02, 0.13, 0.2)
			band.mesh = bb
			band.material_override = iron
			band.position = Vector3(-s * lw * 0.5, by, 0)
			pivot.add_child(band)
		_leaf_pivots.append(pivot)
	# solid barrier plugging the passage while shut (world layer 1 -> stops player + enemies)
	_barrier = StaticBody3D.new()
	_barrier.collision_layer = 1 << 0
	_barrier.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(definition.passage_width, definition.passage_height, 0.5)
	cs.shape = box
	cs.position = Vector3(0, definition.passage_height * 0.5, zf + 0.1)
	_barrier.add_child(cs)
	gen().add_child(_barrier)

# open/shut the gate: swing the leaves + toggle the passage barrier. Driven by the WaveSpawner from
# the gate's HP (shut while it stands; opens the moment it's breached).
func set_gate_open(open: bool) -> void:
	for i in _leaf_pivots.size():
		if not is_instance_valid(_leaf_pivots[i]):
			continue
		var s := -1.0 if i == 0 else 1.0
		(_leaf_pivots[i] as Node3D).rotation.y = (-s * deg_to_rad(100.0)) if open else 0.0
	if is_instance_valid(_barrier):
		_barrier.collision_layer = 0 if open else (1 << 0)

# a real masonry arch (stone jambs + voussoir ring) framing the OPEN passage mouth at local z=`zf`.
# Built from visual blocks that sit BESIDE and ABOVE the opening — the hole itself stays clear, so
# you see straight through the gate (no more bricked-up look).
func _arch_ring(zf: float) -> void:
	var stone := mat_stone()
	var d := definition
	var pw := d.passage_width * 0.5
	var spring := d.passage_height - pw                                 # semicircle springs here
	for s in [-1.0, 1.0]:                                              # jamb pilasters flanking the opening
		add_box_visual(Vector3(s * (pw + 0.3), spring * 0.5, zf), Vector3(0.6, spring, 0.7), stone)
	var n := 9                                                         # voussoir blocks over the top
	for i in n + 1:
		var a := lerpf(0.0, PI, float(i) / float(n))
		var vx := cos(a) * (pw + 0.05)
		var vy := spring + sin(a) * (pw + 0.05)
		add_box_visual(Vector3(vx, vy, zf), Vector3(0.5, 0.55, 0.7), stone, 0.0)

func validate_geometry() -> void:
	pass
