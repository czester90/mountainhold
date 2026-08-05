@tool
class_name TowerDefinition
extends Resource

## A round drum tower. The wall-walk enters at y=walk_height through a door on the -X
## side and exits through a door on the +X side, so the rampart passes through the drum.
## The interior stair climbs from walk_height to the roof deck at y=height.

@export var radius: float = 6.0
@export var height: float = 12.0
@export var walk_height: float = 6.0
@export var wall_thickness: float = 0.7
@export var segments: int = 24

@export_group("Doors")
@export var door_width: float = 2.2
@export var door_height: float = 3.4

@export_group("Roof")
@export var hatch: HatchDefinition = HatchDefinition.new()
@export var merlon_height: float = 1.2
@export var merlon_thickness: float = 0.8
