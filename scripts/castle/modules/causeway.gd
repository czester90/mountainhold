@tool
class_name Causeway
extends CastleModule

## Paved approach ramp with side parapets. Built FLAT along local +X (walking surface at y=0);
## the generator tilts the whole module to bridge two ground heights. Collision on the deck so the
## player/enemies walk the causeway rather than the rough terrain beside it. Ports: StairEntry
## (foot, -X) and StairExit (top, +X).

@export var definition: CausewayDefinition = CausewayDefinition.new():
	set(value):
		definition = value
		if is_inside_tree():
			rebuild()

func _construct() -> void:
	var d := definition
	var hl := d.run * 0.5
	# paved deck (top surface at y=0)
	add_box(Vector3(0, -d.thickness * 0.5, 0), Vector3(d.run, d.thickness, d.width), mat_floor())
	# a low stone parapet down each long edge
	var pz := d.width * 0.5 - d.parapet_thick * 0.5
	for s in [-1.0, 1.0]:
		add_box(Vector3(0, d.parapet_height * 0.5, s * pz), Vector3(d.run, d.parapet_height, d.parapet_thick), mat_stone())
	set_snap("StairEntry", Vector3(-hl, 0, 0), Vector3.LEFT)
	set_snap("StairExit", Vector3(hl, 0, 0), Vector3.RIGHT)

func validate_geometry() -> void:
	pass
