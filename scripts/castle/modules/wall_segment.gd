@tool
class_name WallSegment
extends CastleModule

## Straight curtain wall along local +X. Courtine_Wall facing + triplanar brick core on the
## OUTER side, a walk reaching the outer edge, and a crenellation parapet on the outer edge.
## `mirror` puts the outer side on +Z instead of -Z, so around a corner both arms can face the
## same convex (outer) side. Ports: SnapLeft/SnapRight (ground), WallWalkEntry/Exit (walk).

const MODULE := 6.0
const FACE_D := 0.77   # Courtine_Wall panel depth (measured): occupies z in [-FACE_D, 0]
const CORE_FRONT := -0.55
const SKIRT := 8.0   # wall body extends this far below y0, buried, so segments never float over dipping terrain

@export var definition: WallDefinition = WallDefinition.new():
	set(value):
		definition = value
		if is_inside_tree():
			rebuild()
@export var mirror: bool = false:
	set(value):
		mirror = value
		if is_inside_tree():
			rebuild()
## A hidden SALLY PORT: a small ground doorway carved through the middle of this segment (core split
## + lintel, one facing piece left open, a timber door). Lets the player who fell OUTSIDE slip back
## in; besiegers never path through it (it's not on their route).
@export var sally_port: bool = false:
	set(value):
		sally_port = value
		if is_inside_tree():
			rebuild()
@export_range(-0.45, 0.45, 0.01) var sally_port_offset: float = 0.0:
	set(value):
		sally_port_offset = value
		if is_inside_tree():
			rebuild()

const SALLY_W := 1.8
const SALLY_H := 2.6

func _m() -> float:
	return -1.0 if mirror else 1.0

# z of the walk centreline (outer edge at CORE_FRONT, inner beyond), on the active side
func _walk_z() -> float:
	return _m() * (CORE_FRONT + definition.walk_width * 0.5)

func _construct() -> void:
	place_wall_segments()
	place_snaps()

func place_wall_segments() -> void:
	var d := definition
	var m := _m()
	var hx := d.length * 0.5
	var n: int = maxi(1, int(round(d.length / MODULE)))
	var step := d.length / float(n)
	var cz := m * (d.thickness + CORE_FRONT) * 0.5
	var cd := d.thickness - CORE_FRONT
	var ch := d.height - 0.3
	var sally := sally_port and d.length > SALLY_W + 3.0
	var sally_x := clampf(sally_port_offset, -0.45, 0.45) * maxf(0.0, hx - SALLY_W * 0.5 - 0.8)
	# solid core (top below the walk) + walk slab reaching the outer face, both on side `m`
	if sally:
		# carve a ground doorway: left + right cores and a lintel above it. Offset lets generators
		# push the hidden mountain passage toward the tower so it does not land inside a steep rock face.
		var left_w := sally_x - SALLY_W * 0.5 + hx
		var right_w := hx - (sally_x + SALLY_W * 0.5)
		if left_w > 0.05:
			add_box(Vector3(-hx + left_w * 0.5, ch * 0.5, cz), Vector3(left_w, ch, cd), mat_stone())
		if right_w > 0.05:
			add_box(Vector3(sally_x + SALLY_W * 0.5 + right_w * 0.5, ch * 0.5, cz), Vector3(right_w, ch, cd), mat_stone())
		if ch > SALLY_H:
			add_box(Vector3(sally_x, (SALLY_H + ch) * 0.5, cz), Vector3(SALLY_W, ch - SALLY_H, cd), mat_stone())
		_sally_leaf(sally_x, cz, cd)
	else:
		add_box(Vector3(0, ch * 0.5, cz), Vector3(d.length, ch, cd), mat_stone())
	# buried plinth: the wall body continues straight DOWN below y0 so a segment over dipping terrain
	# (the arms running back to the mountain foot) never floats. Buried, well below the walk.
	add_box(Vector3(0, -SKIRT * 0.5 + 0.05, m * (d.thickness + CORE_FRONT) * 0.5), Vector3(d.length, SKIRT + 0.1, d.thickness - CORE_FRONT), mat_stone())
	add_box(Vector3(0, d.height - 0.15, m * (CORE_FRONT + d.walk_width * 0.5)), Vector3(d.length, 0.3, d.walk_width), mat_floor())
	for j in n:
		var x0 := -hx + step * j
		if sally and absf((x0 + step * 0.5) - sally_x) < SALLY_W * 0.5 + step * 0.5:
			continue                                          # leave the facing open over the secret door
		# facing on the active side. Mirror by ROTATING 180 deg (not negative scale, which would
		# flip normals and light the wall differently) -> a 180-yaw corner-origin piece spans the
		# same x range on the +Z side. SCALE each panel's X to the real per-panel width `step` so the
		# native 6 m kit exactly fills a short/abutting segment instead of OVERHANGING past the body
		# (a 6 m facing on a 3.8 m wall jutted ~2.2 m into the adjoining tower — the "wall in the tower").
		var sx := step / MODULE
		if mirror:
			add_kit("Courtine_Wall", Vector3(x0 + step, 0, 0), PI, Vector3(sx, 1, 1))
		else:
			add_kit("Courtine_Wall", Vector3(x0, 0, 0), 0.0, Vector3(sx, 1, 1))
	var edge := m * CORE_FRONT
	merlon_line(Vector3(-hx, d.height, edge), Vector3(hx, d.height, edge), Vector3(0, 0, -m))

# a plain timber door leaf filling the sally-port opening on the outer face (visual only, so the
# player passes straight through — it reads as a discreet little door, not a gate)
func _sally_leaf(x: float, cz: float, cd: float) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.27, 0.17, 0.09)
	wood.roughness = 0.95
	var leaf := MeshInstance3D.new()
	var bm := BoxMesh.new()
	# OVERLAP the opening (bigger than SALLY_W x SALLY_H) so it laps onto the jambs/lintel — a leaf cut
	# smaller than the hole left a lit gap all around it (the "prześwit w drzwiach" bug)
	bm.size = Vector3(SALLY_W + 0.5, SALLY_H + 0.4, 0.16)
	leaf.mesh = bm
	leaf.material_override = wood
	leaf.position = Vector3(x, SALLY_H * 0.5, cz - _m() * (cd * 0.5 - 0.05))   # flush on the outer (field) face
	gen_visual().add_child(leaf)

func place_snaps() -> void:
	var d := definition
	var hx := d.length * 0.5
	var wz := _walk_z()
	set_snap("SnapLeft", Vector3(-hx, 0, 0), Vector3.LEFT)
	set_snap("SnapRight", Vector3(hx, 0, 0), Vector3.RIGHT)
	set_snap("WallWalkEntry", Vector3(-hx, d.height, wz), Vector3.LEFT)
	set_snap("WallWalkExit", Vector3(hx, d.height, wz), Vector3.RIGHT)

func validate_geometry() -> void:
	if definition.walk_width < 1.0:
		push_warning("WallSegment: walk_width < 1 m, character may not fit")
