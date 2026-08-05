@tool
class_name StoneStairs
extends CastleModule

## Straight stone mural stair (a faithful port of the original `_stone_stairs`): solid step
## columns rising from the courtyard floor to the rampart, seated (never floating), climbing
## along local +X with a collision ramp for smooth character movement. Ports: StairEntry
## (bottom, ground) and StairExit (top, rampart).

const TREAD_RUN := 0.55
const SKIRT := 8.0   # buried base below the run so a slope-seated stair never floats

@export var definition: StairDefinition = StairDefinition.new():
	set(value):
		definition = value
		if is_inside_tree():
			rebuild()

func _construct() -> void:
	var d := definition
	var rise := d.total_rise
	var w := d.width
	var n: int = maxi(1, int(round(rise / d.step_rise)))
	var r := rise / float(n)
	var floor_mat := mat_floor()
	for i in n:
		var h := r * float(i + 1)                              # column from ground to this tread top
		var x := TREAD_RUN * (float(i) + 0.5)
		# visual only — the ramp below carries collision so the player walks up smoothly instead of
		# hitching (jumping) over each solid step edge
		add_box_visual(Vector3(x, h * 0.5, 0), Vector3(TREAD_RUN + 0.02, h, w), floor_mat)
	var run_total := TREAD_RUN * float(n)
	add_ramp(Vector3.ZERO, Vector3.RIGHT, run_total, rise, w)  # collision-only incline
	# buried skirt under the run so a stair seated on a slope never shows a floating base
	add_box_visual(Vector3(run_total * 0.5, -SKIRT * 0.5 + 0.05, 0), Vector3(run_total + TREAD_RUN, SKIRT + 0.1, w), floor_mat)
	# landing at the top, flush with the wall-walk
	add_box(Vector3(run_total + 0.75, rise - 0.15, 0), Vector3(1.5, 0.3, w + 0.4), floor_mat)
	set_snap("StairEntry", Vector3.ZERO, Vector3.LEFT)
	set_snap("StairExit", Vector3(run_total + 0.75, rise, 0), Vector3.RIGHT)

func run_length() -> float:
	var n: int = maxi(1, int(round(definition.total_rise / definition.step_rise)))
	return TREAD_RUN * float(n) + 1.5

func validate_geometry() -> void:
	pass
