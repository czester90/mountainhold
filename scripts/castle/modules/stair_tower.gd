@tool
class_name StairTower
extends CastleModule

## Free-standing switchback stair from ground (StairFoot) to a top landing (StairTop) at `rise`
## metres. Climbs along local +X. Treads are VISUAL-ONLY; a collision ramp under each flight
## carries the capsule (same pattern as Tower/Keep) so nothing vertical catches the player. The
## top landing is raised 4 cm PROUD so it never shares a coincident face with an abutting rampart.

@export var rise: float = 6.0
@export var width: float = 2.4
@export var per_flight: float = 2.2
@export var flight_run: float = 3.0:
	set(v): flight_run = v; if is_inside_tree(): rebuild()

func _construct() -> void:
	var ws := build_wooden_switchback(Vector3.ZERO, 0.0, rise, Vector3(1, 0, 0), flight_run, width, per_flight, 3.0)
	var top: Vector3 = ws["top"]
	# extra landing pushed +X onto the abutting rampart, 4 cm proud (capsule-catch fix)
	add_box(Vector3(top.x + 1.2, rise + 0.04, top.z), Vector3(3.0, 0.3, width + 1.6), mat_floor())
	set_snap("StairFoot", ws["entry"], Vector3.LEFT)
	set_snap("StairTop", Vector3(top.x + 1.2, rise, top.z), Vector3.RIGHT)

func validate_geometry() -> void:
	pass
