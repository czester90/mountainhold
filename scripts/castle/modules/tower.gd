@tool
class_name Tower
extends CastleModule

## Round drum tower, taller than the wall. Hollow faceted brick shell (triplanar kit brick),
## two doors (-X / +X) so the wall-walk passes THROUGH at walk_height, a floor flush with the
## rampart, a wooden switchback stair up to a roof deck with a hatch, and a merlon crown.
## Ports: WallWalkEntry (-X), WallWalkExit (+X), StairEntry (interior).

@export var definition: TowerDefinition = TowerDefinition.new():
	set(value):
		definition = value
		if is_inside_tree():
			rebuild()
## Bearings (radians) of the two wall-walk doors/ports. Default straight-through (-X / +X);
## the fortress generator sets them to the two chord directions at each arc vertex.
@export var port_a: float = PI:
	set(value):
		port_a = value
		if is_inside_tree():
			rebuild()
@export var port_b: float = 0.0:
	set(value):
		port_b = value
		if is_inside_tree():
			rebuild()
## When true the drum gets a GROUND-level doorway at port_a and the interior stair runs all the way
## from the ground up to the roof (a ring floor at walk_height) — so the tower is enterable from the
## bailey without needing a rampart. Used for the inner towers flanking the keep.
@export var ground_entry: bool = false:
	set(value):
		ground_entry = value
		if is_inside_tree():
			rebuild()
## Bearing (radians) of the GROUND doorway, when ground_entry is on. INF = reuse port_a. The inner
## towers set this toward the bailey/keep so the door opens onto the courtyard, not a cramped slot.
@export var ground_door_bearing: float = INF:
	set(value):
		ground_door_bearing = value
		if is_inside_tree():
			rebuild()

const SKIRT := 8.0   # base extends this far BELOW the seat, buried in the terrain so the drum never floats

func _chord() -> float:
	var seg := TAU / float(definition.segments)
	return 2.0 * definition.radius * sin(seg * 0.5) + 0.2

func _door_hw() -> float:
	return definition.door_width / (2.0 * definition.radius) + (TAU / float(definition.segments)) * 0.5

func _construct() -> void:
	build_shell()
	build_floor()
	build_stair_and_roof()
	place_battlements()
	place_snaps()

func _facet(a: float, y0: float, y1: float) -> void:
	var d := definition
	var rmid := d.radius - d.wall_thickness * 0.5
	add_box(Vector3(rmid * cos(a), (y0 + y1) * 0.5, rmid * sin(a)), Vector3(_chord(), y1 - y0, d.wall_thickness), mat_stone(), PI * 0.5 - a)

func build_shell() -> void:
	var d := definition
	var seg := TAU / float(d.segments)
	var yb0 := d.walk_height
	var yb1 := d.walk_height + d.door_height
	var dhw := _door_hw()
	var gdb := ground_door_bearing if not is_inf(ground_door_bearing) else port_a
	for i in d.segments:
		var a := i * seg
		var at_a := _ang_gap(a, port_a) < dhw
		var at_b := _ang_gap(a, port_b) < dhw
		var at_gd := ground_entry and _ang_gap(a, gdb) < dhw
		if at_gd:
			# a modest GROUND doorway (0..door_height) facing the bailey, with SOLID wall above it —
			# not the old full-height gap. Buried skirt below, wall above the door up to the walk band.
			_facet(a, -SKIRT, 0.0)
			_facet(a, d.door_height, yb0)
		else:
			_facet(a, -SKIRT, yb0)                            # solid base + buried skirt (never floats over dipping terrain)
		if not (at_b or at_a):
			_facet(a, yb0, yb1)                               # door band (skipped at the two doors)
		if yb1 < d.height:
			_facet(a, yb1, d.height)                          # above the doors

func build_floor() -> void:
	var d := definition
	var r := d.radius - d.wall_thickness * 0.5
	if ground_entry:
		# paved GROUND floor at the seat, so the stairwell hatch above shows a stone floor below — not
		# the bare brown terrain the hollow drum otherwise sits on (the "gap in the floor" the player saw).
		disc_floor(Vector3.ZERO, 0.0, r)
		# the wall-level floor for ground_entry is built in build_stair_and_roof (it needs the LOWER
		# stair's top-flight footprint to cut a matching hatch)
		return
	# rim embedded in the drum wall (not coplanar with either shell face) and 4 cm below the
	# wall-walk so the two 6 m floors aren't coplanar where they overlap -> no z-fight flicker
	disc_floor(Vector3.ZERO, d.walk_height - 0.04, r)

func build_stair_and_roof() -> void:
	var d := definition
	var r := d.radius - d.wall_thickness * 0.5
	if ground_entry:
		# TWO stair segments so the wall-level floor STAYS (somewhere to stand + the wall-walk lands on
		# it) while each floor keeps a MODEST hatch aligned to its own stair. A single through-going
		# switchback can't do this: at the wall level it's mid-climb, so the hatch either mis-fits the
		# passing flight (the "złe wycięcie") or must open most of the floor (a gaping hole).
		# LOWER: ground -> wall level, lands ON the walk floor (runs along Z).
		var lo := build_wooden_switchback(Vector3.ZERO, -0.12, d.walk_height, Vector3(0, 0, 1), 3.2, 1.9, 3.0)
		# solid wall-level floor with a snug hatch over the lower stair's TOP flight (aligned to it)
		deck_with_hatch(Vector3.ZERO, d.walk_height - 0.04, r, lo["hatch_c"], lo["hatch_d"], lo["hatch_run"], lo["hatch_w"])
		# UPPER: wall level -> roof, run along X so it doesn't stack on the lower stair's hatch
		var up := build_wooden_switchback(Vector3.ZERO, d.walk_height - 0.12, d.height, Vector3(1, 0, 0), 3.2, 1.9, 3.0)
		deck_with_hatch(Vector3.ZERO, d.height + 0.03, r, up["hatch_c"], up["hatch_d"], up["hatch_run"], up["hatch_w"])
		return
	# single switchback from the wall-level floor up to the roof; treads are visual-only (ramp carries
	# collision) so the capsule climbs the flights and turns on the roomy landing without jamming
	var ws := build_wooden_switchback(Vector3.ZERO, d.walk_height - 0.12, d.height, Vector3(0, 0, 1), 3.8, 1.9, 3.0)
	# deck rim embedded in the wall + top 3 cm proud of the shell top course -> no coplanar faces
	deck_with_hatch(Vector3.ZERO, d.height + 0.03, r, ws["hatch_c"], ws["hatch_d"], ws["hatch_run"], ws["hatch_w"])

func place_battlements() -> void:
	var d := definition
	var seg := TAU / float(d.segments)
	for i in d.segments:
		if i % 2 == 1:
			continue
		var a := i * seg
		# sunk 0.1 into the shell top so the merlon base isn't coplanar with it (no z-fight)
		add_box(Vector3(d.radius * cos(a), d.height - 0.1 + d.merlon_height * 0.5, d.radius * sin(a)), Vector3(_chord() * 0.9, d.merlon_height, d.merlon_thickness), mat_stone(), PI * 0.5 - a)

func place_snaps() -> void:
	var d := definition
	var da := Vector3(cos(port_a), 0, sin(port_a))
	var db := Vector3(cos(port_b), 0, sin(port_b))
	set_snap("WallWalkEntry", da * d.radius + Vector3(0, d.walk_height, 0), da)
	set_snap("WallWalkExit", db * d.radius + Vector3(0, d.walk_height, 0), db)
	set_snap("StairEntry", Vector3(0, d.walk_height, 0), Vector3.LEFT)
	# GROUND-level wall docking ports on the drum surface at each door bearing — a curtain wall docks
	# its SnapLeft/Right here so it kisses the shell exactly (no radius guessing, no OVERLAP stub).
	set_snap("WallBaseEntry", da * d.radius, da)
	set_snap("WallBaseExit", db * d.radius, db)

func validate_geometry() -> void:
	var d := definition
	if d.height <= d.walk_height:
		push_warning("Tower: height <= walk_height, no drum above the rampart")
