@tool
class_name FortressGenerator
extends Node3D

## Faithful port of the ORIGINAL fortress layout (archive builder), assembled from our modules:
## a D/horseshoe curtain arc centred on CX,CZ at radius WALL_R, apex to the west, RUNS chords;
## the middle run is the keep (stołp/donjon), round towers project outward at the flanking nodes,
## the two ends are open (they die into the rock). Terrain is the original Terrain3D horseshoe
## bowl (Height_Map.exr import + symmetric sculpt + noise stone textures). Modules only.

const WALL_SCENE := preload("res://scenes/castle/wall_segment.tscn")
const TOWER_SCENE := preload("res://scenes/castle/tower.tscn")
const KEEP_SCENE := preload("res://scenes/castle/keep.tscn")
const GATEHOUSE_SCENE := preload("res://scenes/castle/gatehouse.tscn")
const GATE_TOWER_SCENE := preload("res://scenes/castle/gate_tower.tscn")
const CAUSEWAY_SCENE := preload("res://scenes/castle/causeway.tscn")
const CAVE_SCENE := preload("res://scenes/castle/cave.tscn")
const STONE_STAIRS_SCENE := preload("res://scenes/castle/stone_stairs.tscn")
const STAIR_TOWER_SCENE := preload("res://scenes/castle/stair_tower.tscn")
const CASTLE_MODEL_SCRIPT := preload("res://scripts/castle/castle_model.gd")
const GEN_NAME := "GeneratedGeometry"
const OVERLAP := 0.8
const NAV_STRIP_WIDTH := 2.4
const NAV_SURFACE_LIFT := 0.08
const SLOT_GATE := &"gate"
const SLOT_KEEP := &"keep"
const SLOT_LADDER := &"ladder"
const SLOT_ARCHER := &"archer"

# --- original layout constants ---
const CX := 330.0
const CZ := 500.0
const WALL_R := 44.0
const OPEN_HALF := 1.35
const RUNS := 5
const TOWER_PROJECT := 0.5             # corner towers barely project past the curtain (were 2.0, too far out)
const GATE_FORWARD := 3.5              # push the apex gate toward the FIELD so it isn't recessed in a concave pocket
const APEX := PI                       # west (-X): gate + wall face the open field
const KEEP_X := 360.0                  # rear-centre on the flat citadel pad; rear meets the mountain foot
const MOUNTAIN_SALLY_OFF := 0
const MOUNTAIN_SALLY_LEFT := 1
const MOUNTAIN_SALLY_RIGHT := 2
const MOUNTAIN_SALLY_BOTH := 3

@export var wall_mirror: bool = false
@export var wall_def: WallDefinition = WallDefinition.new()
@export var tower_def: TowerDefinition = TowerDefinition.new()
@export var keep_def: KeepDefinition = KeepDefinition.new()
@export var gatehouse_def: GatehouseDefinition = GatehouseDefinition.new()
@export var stair_def: StairDefinition = StairDefinition.new()
@export var stairs_along_walls: bool = true
@export_enum("Off", "Left / South", "Right / North", "Both") var mountain_sally_ports: int = MOUNTAIN_SALLY_LEFT
@export var rebuild_now: bool = false:
	set(value):
		rebuild_now = false
		if is_inside_tree():
			build()

var _base := 0.0
var _nav_vertices := PackedVector3Array()
var _nav_polygons: Array[PackedInt32Array] = []
var _castle_model: Node = null

func _ready() -> void:
	build()

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
	_nav_vertices = PackedVector3Array()
	_nav_polygons.clear()
	_castle_model = null

func _ensure_castle_model() -> Node:
	if _castle_model != null and is_instance_valid(_castle_model):
		return _castle_model
	_castle_model = CASTLE_MODEL_SCRIPT.new()
	_castle_model.name = "CastleModel"
	gen().add_child(_castle_model)
	_castle_model.reset()
	return _castle_model

func _ang(k: int) -> float:
	return lerp(APEX - OPEN_HALF, APEX + OPEN_HALF, float(k) / float(RUNS))

func _arc(k: int) -> Vector3:
	var a := _ang(k)
	return Vector3(CX + WALL_R * cos(a), _base, CZ + WALL_R * sin(a))

func _proj(k: int) -> Vector3:
	var a := _ang(k)
	return Vector3(CX + (WALL_R + TOWER_PROJECT) * cos(a), _base, CZ + (WALL_R + TOWER_PROJECT) * sin(a))

func build() -> void:
	var tm := get_node_or_null("../TerrainModule")
	if tm:
		# DERIVE the keep-pocket carve from the keep's ACTUAL footprint (not hardcoded numbers) so
		# the mountain is cleared exactly under the keep wherever the keep is / whatever size it is.
		# terrain dx = worldX - CX, dz = worldZ - CZ.
		var half_depth: float = keep_def.depth * 0.5
		var half_width: float = keep_def.width * 0.5
		tm.set("keep_pocket", true)
		tm.set("keep_pk_dx_min", (KEEP_X - half_depth - CX) - 5.0)         # keep front - margin
		tm.set("keep_pk_dx_max", (KEEP_X + half_depth - CX) + 10.0)        # keep rear + cave shelf behind
		tm.set("keep_pk_hz", half_width + 4.0)                            # keep width/2 + margin
		tm.rebuild()                                                       # re-sculpt with the derived pocket
	_base = tm.base() if tm else 0.0
	clear_generated()
	_ensure_castle_model()
	var mid := RUNS / 2                                       # =2; gate on run mid..mid+1
	# --- round corner towers project outward at the open-end nodes (mid-1, mid+2) ---
	var towers := {}
	for k in [mid - 1, mid + 2]:
		var p := _proj(k)
		var t: CastleModule = TOWER_SCENE.instantiate()
		gen().add_child(t)
		t.set("definition", tower_def)
		t.set("port_a", atan2(_arc(k - 1).z - p.z, _arc(k - 1).x - p.x))
		t.set("port_b", atan2(_arc(k + 1).z - p.z, _arc(k + 1).x - p.x))
		t.rebuild()
		t.global_position = p
		_register_module_nav_edge(t, "WallWalkEntry", "WallWalkExit")
		_register_vertical_nav_edge(t, Vector3.ZERO, tower_def.walk_height, tower_def.height)
		towers[k] = t
		var to_gate := (Vector3(290.0, 0.0, CZ) - t.global_position)
		to_gate.y = 0.0
		to_gate = to_gate.normalized() if to_gate.length() > 0.01 else Vector3(-1.0, 0.0, 0.0)
		var side := Vector3.UP.cross(to_gate).normalized()
		for offset in [to_gate * 3.0, to_gate * 1.2, side * 2.1, -side * 2.1, Vector3.ZERO]:
			_register_archer_slot(t.global_position + offset + Vector3.UP * tower_def.height, to_gate, 24.5, 30.0, 1.32, 1)
	# --- gatehouse straddling the apex run mid..mid+1, gate facing the field (keep moved to rear) ---
	var pl := _arc(mid)
	var pr := _arc(mid + 1)
	var centre := (pl + pr) * 0.5
	var gdir := pr - pl
	gdir.y = 0.0
	var glen := gdir.length()
	gdir = gdir.normalized()
	var gate: CastleModule = GATE_TOWER_SCENE.instantiate()
	gen().add_child(gate)
	var gd: GatehouseDefinition = gatehouse_def.duplicate()
	gd.length = 14.0                          # compact gate TOWER at the apex (walls bridge to the corners)
	gd.height = wall_def.height              # walk lines up with the curtain
	gd.walk_width = wall_def.walk_width
	gd.thickness = 7.0                        # DEEP enough the walk passes THROUGH between full-height side walls
	gd.tower_height = 6.0                     # tall gate tower with an interior firing gallery + reachable roof
	gd.portcullis = true
	gate.set("definition", gd)
	gate.rebuild()
	# push the gate outward (toward the field) so its deep body isn't recessed behind the curtain line
	var apex_out := Vector3(centre.x - CX, 0.0, centre.z - CZ).normalized()
	var gpos := centre + apex_out * GATE_FORWARD
	gate.global_transform = Transform3D(Basis(Vector3.UP, atan2(-gdir.z, gdir.x)), Vector3(gpos.x, _base, gpos.z))
	_register_module_nav_edge(gate, "WallWalkEntry", "WallWalkExit")
	_register_vertical_nav_edge(gate, Vector3.ZERO, gd.height, gd.height + gd.tower_height)
	var gate_front := apex_out
	var gate_roof_slot_z := float(gate.call("field_roof_slot_z")) if gate.has_method("field_roof_slot_z") else 0.55
	var gate_gallery_slot_z := float(gate.call("field_gallery_slot_z")) if gate.has_method("field_gallery_slot_z") else 0.60
	_register_line_slots(SLOT_GATE, gate.global_transform * Vector3(-gd.length * 0.35, gd.height + gd.tower_height, gate_roof_slot_z), gate.global_transform * Vector3(gd.length * 0.35, gd.height + gd.tower_height, gate_roof_slot_z), gate_front, 5, 0)
	_register_line_slots(SLOT_GATE, gate.global_transform * Vector3(-gd.length * 0.25, gd.height, gate_gallery_slot_z), gate.global_transform * Vector3(gd.length * 0.25, gd.height, gate_gallery_slot_z), gate_front, 3, 1)
	_register_line_slots(SLOT_ARCHER, gate.global_transform * Vector3(-gd.length * 0.35, gd.height + gd.tower_height, gate_roof_slot_z), gate.global_transform * Vector3(gd.length * 0.35, gd.height + gd.tower_height, gate_roof_slot_z), gate_front, 5, 0)
	_register_line_slots(SLOT_ARCHER, gate.global_transform * Vector3(-gd.length * 0.25, gd.height, gate_gallery_slot_z), gate.global_transform * Vector3(gd.length * 0.25, gd.height, gate_gallery_slot_z), gate_front, 3, 1)
	_register_outer_rampart_archer_slots(14)
	var pe: Vector3 = gate.global_transform * gate.snap("WallWalkEntry").transform.origin
	var pex: Vector3 = gate.global_transform * gate.snap("WallWalkExit").transform.origin
	var e_near_l: bool = pe.distance_to(pl) < pex.distance_to(pl)
	var gate_left: Vector3 = pe if e_near_l else pex
	var gate_right: Vector3 = pex if e_near_l else pe
	# --- curtain walls: SNAP-DOCKED to the corner towers' ground ports (no _edge/OVERLAP guessing) ---
	# tower(mid-1): port_b faces the gate (_arc(mid)), port_a faces the arm (_arc(mid-2)).
	# tower(mid+2): port_a faces the gate (_arc(mid+1)), port_b faces the arm (_arc(mid+3)).
	var tS: CastleModule = towers[mid - 1]
	var tN: CastleModule = towers[mid + 2]
	_dock_wall(tS, "WallBaseExit", gate_left, false, true, true)               # tower -> gate left (+ mural stair, no sally by stairs)
	_dock_wall(tN, "WallBaseEntry", gate_right, false, true, true)             # tower -> gate right (+ mural stair)
	# open-end arms: run ~6 m past the last arc vertex so the cut face buries into the rising rock
	var arm_s: Vector3 = _arc(0) + (_arc(0) - _proj(mid - 1)).normalized() * 6.0
	var arm_n: Vector3 = _arc(RUNS) + (_arc(RUNS) - _proj(mid + 2)).normalized() * 6.0
	var mountain_sally_s := mountain_sally_ports == MOUNTAIN_SALLY_LEFT or mountain_sally_ports == MOUNTAIN_SALLY_BOTH
	var mountain_sally_n := mountain_sally_ports == MOUNTAIN_SALLY_RIGHT or mountain_sally_ports == MOUNTAIN_SALLY_BOTH
	_dock_wall(tS, "WallBaseEntry", arm_s, mountain_sally_s, true, false, -0.35)  # tower -> south open end (+ optional hidden mountain sally)
	_dock_wall(tN, "WallBaseExit", arm_n, mountain_sally_n, true, false, -0.35)   # tower -> north open end (+ optional hidden mountain sally)
	_place_inner_ring()
	_place_causeway()
	_place_keep()
	_place_stair_tower()
	_place_cave()
	_rebuild_navigation_region()
	_register_fortress_regions()
	print("fortress: base=%.1f, %d modules" % [_base, gen().get_child_count()])

# Cave hall in the mountain behind the keep — the player walks through the keep's rear gate into
# the Glittering Caves. Seated on the pad/pocket level, mouth facing west (toward the keep back).
func _place_cave() -> void:
	var mx := KEEP_X + keep_def.depth * 0.5 + 1.0            # just behind the keep's rear
	# seat the cave at the KEEP FLOOR level (its seat + the +0.25 floor slab), NOT the carved terrain
	# behind the keep (a low pit) — so the player walks out the keep's rear gate straight into the cave
	# at the same height, and the cave sits UP on the pad, not down a hole ("jaskinia w górze").
	var gy := _ground(KEEP_X - keep_def.depth * 0.5, CZ) + 0.25
	var cave: CastleModule = CAVE_SCENE.instantiate()
	gen().add_child(cave)
	cave.rebuild()
	# mouth (local -Z) faces west/-X (toward the keep); chamber extends +X into the mountain
	cave.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(mx, gy, CZ))

# The causeway: a paved ramp climbing the courtyard from the flat forecourt up to the inner gate,
# tilted to bridge the two ground heights (built flat, tilted here). Deck raised slightly proud of
# the rough terrain so it reads as a built road and the player walks it.
func _place_causeway() -> void:
	var ax := KEEP_X - 34.0                                  # forecourt edge (start of the rise)
	var bx := KEEP_X - 16.0                                  # inner gate foot
	var a := Vector3(ax, _ground(ax, CZ) + 0.3, CZ)
	var b := Vector3(bx, _ground(bx, CZ) + 0.3, CZ)
	var fwd := (b - a).normalized()
	var side := Vector3.UP.cross(fwd).normalized()
	var up := fwd.cross(side).normalized()
	var cw: CastleModule = CAUSEWAY_SCENE.instantiate()
	gen().add_child(cw)
	var cd := CausewayDefinition.new()
	cd.run = a.distance_to(b)
	cw.set("definition", cd)
	cw.rebuild()
	cw.global_transform = Transform3D(Basis(fwd, up, side), (a + b) * 0.5)
	_register_nav_edge(cw, cw.global_transform * cw.snap("StairEntry").transform.origin, cw.global_transform * cw.snap("StairExit").transform.origin)

func _register_nav_edge(node: Node, a: Vector3, b: Vector3) -> void:
	node.add_to_group("castle_navigation_edge")
	node.set_meta("nav_a", a)
	node.set_meta("nav_b", b)
	_ensure_castle_model().register_navigation_edge(node)
	_register_navigation_link(node, a, b)
	_register_navigation_strip(a, b)

func _register_navigation_link(owner: Node, a: Vector3, b: Vector3) -> void:
	var link := NavigationLink3D.new()
	link.name = "NavigationLink3D"
	gen().add_child(link)
	link.global_position = (a + b) * 0.5
	link.start_position = link.to_local(a)
	link.end_position = link.to_local(b)
	link.bidirectional = true
	link.add_to_group("castle_navigation_link")
	link.set_meta("nav_owner", owner.get_path() if owner.is_inside_tree() else NodePath(""))
	link.set_meta("nav_a", a)
	link.set_meta("nav_b", b)
	_ensure_castle_model().register_navigation_link(link)

func _register_tactical_slot(slot_kind: StringName, point: Vector3, facing: Vector3, priority: int = 0) -> Marker3D:
	var slot := Marker3D.new()
	slot.name = "%sSlot" % str(slot_kind).capitalize()
	gen().add_child(slot)
	slot.global_position = point
	if facing.length() > 0.01:
		slot.look_at(point + facing.normalized(), Vector3.UP)
	slot.add_to_group("castle_tactical_slot")
	slot.add_to_group("castle_tactical_slot_%s" % str(slot_kind))
	slot.set_meta("slot_kind", slot_kind)
	slot.set_meta("priority", priority)
	slot.set_meta("reserved_by", 0)
	_ensure_castle_model().register_tactical_slot(slot)
	return slot

func _register_archer_slot(point: Vector3, facing: Vector3, y_lo: float, y_hi: float, muzzle_height: float, priority: int = 0) -> void:
	var slot := _register_tactical_slot(SLOT_ARCHER, point, facing, priority)
	slot.set_meta("y_lo", y_lo)
	slot.set_meta("y_hi", y_hi)
	slot.set_meta("muzzle_height", muzzle_height)

func _register_outer_rampart_archer_slots(count: int) -> void:
	if count <= 0:
		return
	for i in count:
		var t := 0.5 if count == 1 else float(i) / float(count - 1)
		var ang: float = lerp(APEX - 0.65, APEX + 0.65, t)
		var point := Vector3(CX + (WALL_R - 1.4) * cos(ang), _base + wall_def.height, CZ + (WALL_R - 1.4) * sin(ang))
		var facing := Vector3(point.x - CX, 0.0, point.z - CZ)
		_register_archer_slot(point, facing, 19.0, 23.5, 2.6, 0)

func _register_line_slots(slot_kind: StringName, a: Vector3, b: Vector3, facing: Vector3, count: int, priority: int = 0) -> void:
	if count <= 0:
		return
	for i in count:
		var t := 0.5 if count == 1 else float(i) / float(count - 1)
		_register_tactical_slot(slot_kind, a.lerp(b, t), facing, priority)

func _register_ladder_slot(module: Node, foot: Vector3, top: Vector3, normal: Vector3, priority: int = 0) -> void:
	if top.y <= foot.y + 1.0:
		return
	var slot := Marker3D.new()
	slot.name = "LadderSlot"
	gen().add_child(slot)
	slot.global_position = top
	if normal.length() > 0.01:
		slot.look_at(top + normal.normalized(), Vector3.UP)
	slot.add_to_group("castle_ladder_slot")
	slot.add_to_group("castle_tactical_slot")
	slot.add_to_group("castle_tactical_slot_%s" % str(SLOT_LADDER))
	slot.set_meta("slot_kind", SLOT_LADDER)
	slot.set_meta("priority", priority)
	slot.set_meta("reserved_by", 0)
	slot.set_meta("active_ladder", NodePath(""))
	slot.set_meta("foot", foot)
	slot.set_meta("top", top)
	slot.set_meta("normal", normal.normalized() if normal.length() > 0.01 else Vector3.FORWARD)
	slot.set_meta("nav_owner", module.get_path() if module.is_inside_tree() else NodePath(""))
	slot.set_meta("ladder_surface", &"wall")
	_ensure_castle_model().register_ladder_slot(slot)

func _register_wall_ladder_slots(wall: CastleModule, wall_defn: WallDefinition, outward: Vector3, count: int = 2, priority: int = 0) -> void:
	if count <= 0 or outward.length() < 0.01:
		return
	var normal := outward.normalized()
	var side_sign := 1.0 if bool(wall.get("mirror")) else -1.0
	var top_z := side_sign * (wall_defn.walk_width * 0.5 - 0.55)
	var face_z := side_sign * (wall_defn.thickness * 0.5 + 0.45)
	var foot_z := side_sign * (wall_defn.thickness * 0.5 + 4.4)
	var usable := wall_defn.length * 0.5 - 8.0
	if usable <= 2.0:
		return
	for i in count:
		var t := 0.5 if count == 1 else float(i + 1) / float(count + 1)
		var x := lerpf(-usable, usable, t)
		var top := wall.global_transform * Vector3(x, wall_defn.height, top_z)
		var foot_hint := wall.global_transform * Vector3(x, 0.0, foot_z)
		var foot := Vector3(foot_hint.x, _ground(foot_hint.x, foot_hint.z) + 0.15, foot_hint.z)
		var face := wall.global_transform * Vector3(x, wall_defn.height * 0.45, face_z)
		_register_ladder_slot(wall, foot, top, normal, priority)
		_register_navigation_strip(foot, face)

func _register_fortress_regions() -> void:
	var model := _ensure_castle_model()
	var ladder_slots: Array = model.call("wall_ladder_slots") if model.has_method("wall_ladder_slots") else []
	var min_z := CZ - WALL_R
	var max_z := CZ + WALL_R
	var min_x := CX - WALL_R
	for slot in ladder_slots:
		if not slot is Node3D or not is_instance_valid(slot):
			continue
		var foot: Vector3 = slot.get_meta("foot", (slot as Node3D).global_position)
		min_z = minf(min_z, foot.z)
		max_z = maxf(max_z, foot.z)
		min_x = minf(min_x, foot.x)
	var wall_width := maxf(10.0, max_z - min_z)
	var wall_front := Vector3(min_x, _base, CZ)
	model.call("register_region", &"wall_front", wall_front, wall_width * 0.5, Vector3.LEFT, {"z_min": min_z, "z_max": max_z})
	model.call("register_region", &"staging_horizon", wall_front + Vector3.LEFT * 42.0, wall_width * 0.65, Vector3.RIGHT, {"z_min": min_z - 8.0, "z_max": max_z + 8.0})
	model.call("register_region", &"ladder_zone", wall_front, wall_width * 0.55, Vector3.LEFT, {"slots": ladder_slots.size()})
	model.call("register_region", &"archer_band", Vector3(CX - WALL_R + 2.0, _base + wall_def.height, CZ), wall_width * 0.5, Vector3.LEFT, {"height": wall_def.height})
	model.call("register_region", &"gate", Vector3(CX - WALL_R, _base, CZ), 10.0, Vector3.LEFT)
	model.call("register_region", &"keep", Vector3(KEEP_X, _base + keep_def.height, CZ), maxf(keep_def.width, keep_def.depth) * 0.5, Vector3.LEFT)

func _register_navigation_strip(a: Vector3, b: Vector3) -> void:
	var flat := b - a
	flat.y = 0.0
	if flat.length() < 0.35:
		return
	var side := Vector3.UP.cross(flat.normalized()).normalized() * (NAV_STRIP_WIDTH * 0.5)
	var start_index := _nav_vertices.size()
	_nav_vertices.append(a + side + Vector3.UP * NAV_SURFACE_LIFT)
	_nav_vertices.append(a - side + Vector3.UP * NAV_SURFACE_LIFT)
	_nav_vertices.append(b - side + Vector3.UP * NAV_SURFACE_LIFT)
	_nav_vertices.append(b + side + Vector3.UP * NAV_SURFACE_LIFT)
	_nav_polygons.append(PackedInt32Array([start_index, start_index + 1, start_index + 2, start_index + 3]))

func _rebuild_navigation_region() -> void:
	if _nav_polygons.is_empty():
		return
	var region := NavigationRegion3D.new()
	region.name = "CastleNavigationRegion"
	region.top_level = true
	region.add_to_group("castle_navigation_region")
	gen().add_child(region)
	region.global_position = Vector3.ZERO
	var nav_mesh := NavigationMesh.new()
	nav_mesh.set_vertices(_nav_vertices)
	for polygon in _nav_polygons:
		nav_mesh.add_polygon(polygon)
	nav_mesh.agent_radius = 0.45
	nav_mesh.agent_height = 1.7
	region.navigation_mesh = nav_mesh
	_ensure_castle_model().register_navigation_region(region)

func _register_module_nav_edge(module: CastleModule, a_snap: String, b_snap: String) -> void:
	var a_marker := module.snap(a_snap)
	var b_marker := module.snap(b_snap)
	if a_marker == null or b_marker == null:
		return
	_register_nav_edge(module, module.global_transform * a_marker.transform.origin, module.global_transform * b_marker.transform.origin)

func _register_vertical_nav_edge(module: CastleModule, local_xz: Vector3, from_y: float, to_y: float) -> void:
	var a := module.global_transform * Vector3(local_xz.x, from_y, local_xz.z)
	var b := module.global_transform * Vector3(local_xz.x, to_y, local_xz.z)
	var edge := Node3D.new()
	edge.name = "NavigationEdge"
	gen().add_child(edge)
	_register_nav_edge(edge, a, b)

# terrain height at a world point (falls back to flat base if no terrain)
func _ground(x: float, z: float) -> float:
	var tm := get_node_or_null("../TerrainModule")
	return tm.height(x, z) if tm else _base

# The keep (stołp) sits at the REAR on the risen courtyard, tucked against the mountain, facing
# west over the approach. Seated at its FRONT-edge ground height so the front doesn't float; the
# rear buries into the rising slope (adjoins the mountain).
# Free-standing switchback in the N bailey: bailey ground -> N inner-ring rampart (y+6).
# Rotated so its local +X climb points world +Z, landing on the N side-wall walk (z~511).
func _place_stair_tower() -> void:
	# straight stone stair, SEATED on the bailey floor, climbing along world +X up the keep's N flank
	# (z~511, just past the keep's north face z509) directly onto the keep first-floor slab (y~32).
	# No floating bridge: the stair foot sits on the pad, the top lands on the keep floor overhang.
	var sd: StairDefinition = stair_def.duplicate()
	sd.total_rise = wall_def.height
	sd.width = 3.0
	var s: CastleModule = STONE_STAIRS_SCENE.instantiate()
	gen().add_child(s)
	s.set("definition", sd)
	s.rebuild()
	var run_len: float = s.call("run_length")
	var top_x := 361.0                                       # land on the keep floor (x355-365)
	var foot_x := top_x - run_len
	var z := 511.0
	s.global_transform = Transform3D(Basis.IDENTITY, Vector3(foot_x, _ground(foot_x, z), z))
	_register_module_nav_edge(s, "StairEntry", "StairExit")

func _place_keep() -> void:
	var kc := Vector3(KEEP_X, 0.0, CZ)
	var keep: CastleModule = KEEP_SCENE.instantiate()
	gen().add_child(keep)
	keep.set("definition", keep_def)
	keep.rebuild()
	var front_x := kc.x - keep_def.depth * 0.5          # local +Z (front) -> world -X when facing west
	var gy := _ground(front_x, kc.z)
	var outward := Vector3(-1.0, 0.0, 0.0)              # face the field/approach (west)
	keep.global_transform = Transform3D(Basis(Vector3.UP, atan2(outward.x, outward.z)), Vector3(kc.x, gy, kc.z))
	_register_module_nav_edge(keep, "WallWalkEntry", "WallWalkExit")
	_register_vertical_nav_edge(keep, Vector3(0.0, 0.0, 0.0), 0.0, keep_def.walk_height)
	_register_vertical_nav_edge(keep, Vector3(0.0, 0.0, 0.0), keep_def.walk_height, keep_def.height)
	_register_line_slots(SLOT_KEEP, keep.global_transform * Vector3(-keep_def.width * 0.32, keep_def.height, -keep_def.depth * 0.2), keep.global_transform * Vector3(keep_def.width * 0.32, keep_def.height, -keep_def.depth * 0.2), outward, 5, 0)
	_register_line_slots(SLOT_KEEP, keep.global_transform * Vector3(-keep_def.width * 0.25, keep_def.walk_height, 0.0), keep.global_transform * Vector3(keep_def.width * 0.25, keep_def.walk_height, 0.0), outward, 4, 1)

# Inner enclosure (obramowanie): a small bailey framing the keep on its FRONT + sides. A front
# line at INNER_X (N-S, constant height) = two flanking towers + an inner gatehouse, plus two
# short side walls running back to the keep's front corners. Rear closed by the keep + mountain.
func _place_inner_ring() -> void:
	var ix := KEEP_X - 15.0                                  # front line, in front of the keep
	var hz := keep_def.width * 0.5 + 4.0                     # WIDER than the keep -> a surrounding bailey
	var gy := _ground(ix, CZ)
	var south := _inner_tower(ix, CZ - hz)
	var north := _inner_tower(ix, CZ + hz)
	# inner gatehouse in the middle, gate facing west (spans along Z, the wall line)
	var gate: CastleModule = GATEHOUSE_SCENE.instantiate()
	gen().add_child(gate)
	var gd: GatehouseDefinition = gatehouse_def.duplicate()
	gd.length = 8.0
	gd.height = wall_def.height
	gd.walk_width = wall_def.walk_width
	gd.thickness = wall_def.thickness
	gate.set("definition", gd)
	gate.rebuild()
	var dir := Vector3(0.0, 0.0, -1.0)                       # flipped 180: gatehouse front (machicolation/arch) now faces the field/west, not the bailey
	gate.global_transform = Transform3D(Basis(Vector3.UP, atan2(-dir.z, dir.x)), Vector3(ix, gy, CZ))
	_register_module_nav_edge(gate, "WallWalkEntry", "WallWalkExit")
	var pe: Vector3 = gate.global_transform * gate.snap("WallWalkEntry").transform.origin
	var pex: Vector3 = gate.global_transform * gate.snap("WallWalkExit").transform.origin
	var g_south: Vector3 = pe if pe.z < pex.z else pex
	var g_north: Vector3 = pex if pe.z < pex.z else pe
	# front line: tower -> gate on each side (mural stairs here collide with the causeway/gate approach;
	# citadel upper access needs a dedicated layout rework, tracked separately)
	# SNAP-DOCKED: front walls dock to each tower's gate-facing ground port (WallBaseEntry=port_a) and
	# span to the gate; side walls dock to the keep-facing port (WallBaseExit=port_b) and span to the
	# keep rear. No _edge radius guessing, no OVERLAP — the wall meets the drum exactly at its surface.
	var keep_rear_x := KEEP_X + keep_def.depth * 0.5
	_dock_wall(south, "WallBaseEntry", g_south, true)   # front-S (+ hidden sally port)
	_dock_wall(north, "WallBaseEntry", g_north, false)  # front-N
	_dock_wall(south, "WallBaseExit", Vector3(keep_rear_x, _ground(keep_rear_x, CZ - hz), CZ - hz), false)  # side-S
	_dock_wall(north, "WallBaseExit", Vector3(keep_rear_x, _ground(keep_rear_x, CZ + hz), CZ + hz), false)  # side-N

func _inner_tower(x: float, z: float) -> CastleModule:
	var t: CastleModule = TOWER_SCENE.instantiate()
	gen().add_child(t)
	t.set("definition", tower_def)
	# ports AIMED AT THE REAL NEIGHBOURS (like the outer towers), not hardcoded ±90°: the front wall
	# runs toward the gate at (ix, CZ) [+Z for the south tower, -Z for the north], the side wall runs
	# toward the keep at +X. Previously port_b=-Z opened a door into empty air and the +X side wall hit
	# a solid shell (dead-end walk).
	t.set("port_a", atan2(CZ - z, 0.0))                      # walk door toward the GATE (front wall)
	t.set("port_b", 0.0)                                     # walk door toward the KEEP (side wall, +X)
	t.set("ground_entry", true)                              # clean ground doorway + ground->roof stair
	t.set("ground_door_bearing", atan2(CZ - z, KEEP_X - x))  # door opens toward the keep/courtyard, not the cramped gate slot
	t.rebuild()
	t.global_position = Vector3(x, _ground(x, z), z)
	_register_module_nav_edge(t, "WallWalkEntry", "WallWalkExit")
	_register_vertical_nav_edge(t, Vector3.ZERO, 0.0, tower_def.walk_height)
	_register_vertical_nav_edge(t, Vector3.ZERO, tower_def.walk_height, tower_def.height)
	return t

func _edge(from: Vector3, toward: Vector3, r: float) -> Vector3:
	var u := toward - from
	u.y = 0.0
	return from + u.normalized() * r

func _wall(a: Vector3, b: Vector3, with_stairs: bool = true, sally: bool = false, inner: bool = false) -> void:
	var seg := b - a
	seg.y = 0.0
	var length := seg.length()
	if length < 2.0:
		return
	var dir := seg / length
	var wd: WallDefinition = wall_def.duplicate()
	wd.length = length + 2.0 * OVERLAP
	var w: CastleModule = WALL_SCENE.instantiate()
	gen().add_child(w)
	w.set("definition", wd)
	# The wall's OUTER side (Courtine facing + merlon parapet) sits on local -Z when mirror=false and
	# +Z when mirror=true (the walk + body are on the opposite, inner side). The outer curtain curves
	# one way so a single tuned global mirror works. The inner ring is a rectangle whose walls run in
	# different directions, so mirror must be chosen PER WALL to keep the facing/merlons pointing AWAY
	# from the keep — otherwise a wall shows its plain back + walk-deck underside to the field (the
	# "mury nie w tą stronę" bug). Outer side world-normal = -m * localZ; want it along `outward`, so
	# mirror when localZ already points outward.
	var use_mirror := wall_mirror
	if inner:
		var mid := (a + b) * 0.5
		var local_plus_z := Vector3(-dir.z, 0.0, dir.x)          # world direction of the wall's local +Z
		var outward := Vector3(mid.x - KEEP_X, 0.0, mid.z - CZ)  # away from the keep centre
		if outward.length() > 0.01:
			use_mirror = local_plus_z.dot(outward.normalized()) > 0.0
	w.set("mirror", use_mirror)
	if sally:
		w.set("sally_port", true)
	w.rebuild()
	var m := (a + b) * 0.5
	w.global_transform = Transform3D(Basis(Vector3.UP, atan2(-dir.z, dir.x)), Vector3(m.x, _ground(m.x, m.z), m.z))
	_register_module_nav_edge(w, "WallWalkEntry", "WallWalkExit")
	if not inner:
		var outer_normal := Vector3(m.x - CX, 0.0, m.z - CZ)
		_register_wall_ladder_slots(w, wd, outer_normal, 4, 1)
	if with_stairs and stairs_along_walls:
		_stone_stair(a, b, dir)

# SNAP-DOCKED curtain wall: instead of guessing an endpoint radius + adding OVERLAP, dock the wall's
# SnapLeft onto a tower's ground port (which already sits on the drum surface at the door bearing) and
# size the wall to the measured gap to `far`. The wall then meets the drum EXACTLY — no radius guess,
# no 0.8 stub poking into the hollow, and it's seated at the tower's Y so the walk stays continuous.
func _dock_wall(tower: CastleModule, port_name: String, far: Vector3, sally: bool, outer: bool = false, stairs: bool = false, sally_offset: float = 0.0) -> void:
	var ap: Marker3D = tower.snap(port_name)
	if ap == null:
		push_warning("dock: tower missing port " + port_name)
		return
	var port_w: Vector3 = tower.global_transform * ap.transform.origin
	var gap: float = Vector2(far.x - port_w.x, far.z - port_w.z).length()
	if gap < 2.0:
		return
	var seam: float = 0.3                                     # bury SnapLeft this far into the 0.7 m shell (no hairline, no hollow poke)
	var dir: Vector3 = far - port_w
	dir.y = 0.0
	dir = dir.normalized()
	var mid: Vector3 = (port_w + far) * 0.5
	var local_plus_z: Vector3 = Vector3(-dir.z, 0.0, dir.x)
	# facing/merlons point AWAY from the enclosure centre — the fortress centre for the outer curtain,
	# the keep for the inner ring. Computed per wall so it's correct regardless of dock direction.
	var ctr_x: float = CX if outer else KEEP_X
	var outward: Vector3 = Vector3(mid.x - ctr_x, 0.0, mid.z - CZ)
	var use_mirror: bool = false
	if outward.length() > 0.01:
		use_mirror = local_plus_z.dot(outward.normalized()) > 0.0
	var wd: WallDefinition = wall_def.duplicate()
	wd.length = gap + seam
	var w: CastleModule = WALL_SCENE.instantiate()
	gen().add_child(w)
	w.set("definition", wd)
	w.set("mirror", use_mirror)
	if sally:
		w.set("sally_port", true)
		w.set("sally_port_offset", sally_offset)
	w.rebuild()
	w.global_transform = CastleModule.compute_dock(tower.global_transform, ap.transform, w.snap("SnapLeft").transform)
	var out_w: Vector3 = (tower.global_transform.basis * (ap.transform.basis * Vector3.FORWARD)).normalized()
	w.global_position -= out_w * seam
	_register_module_nav_edge(w, "WallWalkEntry", "WallWalkExit")
	if outer:
		_register_wall_ladder_slots(w, wd, outward, 4, 0)
	if stairs and stairs_along_walls:
		_stone_stair(port_w, far, dir)                       # wide mural stair on the courtyard side -> rampart access

# stone mural stair running ALONG the wall on the courtyard (inner) side, ground -> rampart
func _stone_stair(a: Vector3, b: Vector3, dir: Vector3) -> void:
	var m := (a + b) * 0.5
	var inner := Vector3(CX - m.x, 0, CZ - m.z).normalized()
	var sd: StairDefinition = stair_def.duplicate()
	sd.total_rise = wall_def.height
	sd.width = 6.0                                            # WIDE mural stair — an obvious, easy target from the bailey (defender route up)
	var s: CastleModule = STONE_STAIRS_SCENE.instantiate()
	gen().add_child(s)
	s.set("definition", sd)
	s.rebuild()
	var run_len: float = s.call("run_length")
	var yaw := atan2(-dir.z, dir.x)
	var offset := wall_def.thickness * 0.5 + sd.width * 0.5
	var foot := m + inner * offset - dir * (run_len * 0.5)
	s.global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(foot.x, _ground(foot.x, foot.z), foot.z))
	_register_nav_edge(s, s.global_transform * s.snap("StairEntry").transform.origin, s.global_transform * s.snap("StairExit").transform.origin)
