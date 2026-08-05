@tool
class_name Stairs
extends CastleModule

## Wooden switchback stair (flights + landings + side stringers + risers, plus a collision
## ramp per flight so a character walks up smoothly). Ports: StairEntry (bottom), StairExit
## (top landing). Geometry is shared with the tower interior via build_wooden_switchback.

@export var definition: StairDefinition = StairDefinition.new():
	set(value):
		definition = value
		if is_inside_tree():
			rebuild()

func _construct() -> void:
	var d := definition
	var ws := build_wooden_switchback(Vector3.ZERO, 0.0, d.total_rise, Vector3.RIGHT, d.flight_run, d.width, d.per_flight_rise, d.step_rise)
	set_snap("StairEntry", ws["entry"], ws["entry_out"])
	set_snap("StairExit", ws["top"], ws["exit_out"])

func validate_geometry() -> void:
	var d := definition
	if d.per_flight_rise > d.flight_run * 1.2:
		push_warning("Stairs: flights too steep, character may stall")
