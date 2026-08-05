@tool
class_name Gatehouse
extends CastleModule

## Fortified gate spanning the curtain along local +X: two brick piers flank a central passage,
## a lintel bridges above it, the wall-walk runs over the top, merlons crown it, and a kit arch
## faces the passage on both sides. Ports: WallWalkEntry (-X), WallWalkExit (+X).

const MODULE := 6.0

@export var definition: GatehouseDefinition = GatehouseDefinition.new():
	set(value):
		definition = value
		if is_inside_tree():
			rebuild()
@export var mirror: bool = false:
	set(value):
		mirror = value
		if is_inside_tree():
			rebuild()

func _m() -> float:
	return -1.0 if mirror else 1.0

func _outer_z() -> float:
	return _m() * (-definition.thickness * 0.5)

func _walk_z() -> float:
	return _outer_z() + _m() * definition.walk_width * 0.5

func _construct() -> void:
	build_piers()
	build_walk()
	place_battlements()
	build_machicolation()
	place_snaps()
	# NOTE: the DoorSticker_Portcullis is intentionally NOT built — the kit sticker renders as a
	# floating orange quad above the passage (same reason it was dropped from the main GateTower).

# A machicolation: a corbelled overhang along the FRONT (field) edge at walk level — defenders drop
# fire on attackers below the gate (the Hornburg's defensive signature). SOLID, no floating mass.
func build_machicolation() -> void:
	var d := definition
	var hx := d.length * 0.5
	var out := -_m()                                          # +1 toward the field face
	var of := d.thickness * 0.5                               # front face z
	# corbel band jutting ~0.5 m proud of the wall, just under the parapet
	add_box(Vector3(0, d.height - 0.55, out * (of + 0.25)), Vector3(2.0 * hx - 0.4, 0.5, 0.5), mat_stone())
	# supporting corbels (small brackets) at intervals
	var n := int(round(d.length / 1.6))
	var step := (2.0 * hx - 0.6) / float(n)
	for i in n + 1:
		var x := -hx + 0.3 + step * float(i)
		add_box(Vector3(x, d.height - 1.0, out * (of + 0.12)), Vector3(0.28, 0.5, 0.35), mat_stone())

# portcullis grille in the passage mouth (kit sticker), on the outer face
func build_portcullis() -> void:
	var d := definition
	if not d.portcullis:
		return
	# native sticker spans ~5 wide x ~5.6 tall; scale it to the passage opening. VISUAL ONLY —
	# move it out of gen() so trimesh_generated doesn't give it collision (must not block the gate).
	var z_off := _outer_z() + _m() * 0.1                     # in the passage mouth, just inside the outer face
	var mi := add_kit("DoorSticker_Portcullis", Vector3(0, 0, z_off), 0.0, Vector3(d.passage_width / 5.0, d.passage_height / 5.0, 1.0))
	if mi:
		gen().remove_child(mi)
		gen_visual().add_child(mi)

func build_piers() -> void:
	var d := definition
	var hx := d.length * 0.5
	var pw := d.passage_width * 0.5
	var top := d.height - 0.3                                 # core top below the walk
	# side piers
	var left_w := hx - pw
	add_box(Vector3(-(pw + hx) * 0.5, top * 0.5, 0), Vector3(left_w, top, d.thickness), mat_stone())
	add_box(Vector3((pw + hx) * 0.5, top * 0.5, 0), Vector3(left_w, top, d.thickness), mat_stone())
	# lintel over the passage
	var lintel_h := top - d.passage_height
	if lintel_h > 0.1:
		add_box(Vector3(0, d.passage_height + lintel_h * 0.5, 0), Vector3(d.passage_width, lintel_h, d.thickness), mat_stone())

func build_walk() -> void:
	var d := definition
	add_box(Vector3(0, d.height - 0.15, _walk_z()), Vector3(d.length, 0.3, d.walk_width), mat_floor())

func place_battlements() -> void:
	var d := definition
	var hx := d.length * 0.5
	merlon_line(Vector3(-hx, d.height, _outer_z()), Vector3(hx, d.height, _outer_z()), Vector3(0, 0, -_m()))

func place_snaps() -> void:
	var d := definition
	var hx := d.length * 0.5
	set_snap("WallWalkEntry", Vector3(-hx, d.height, _walk_z()), Vector3.LEFT)
	set_snap("WallWalkExit", Vector3(hx, d.height, _walk_z()), Vector3.RIGHT)

func validate_geometry() -> void:
	if definition.passage_height >= definition.height - 0.3:
		push_warning("Gatehouse: passage_height too tall, no lintel above the gate")
