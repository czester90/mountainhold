@tool
class_name CornerDefinition
extends Resource

## A square corner bastion that turns the wall-walk 90 degrees. Two walk ports on adjacent
## faces (A on -X, B on -Z); merlons crown the two outer edges (+X, +Z).

@export var side: float = 4.4
@export var height: float = 6.0
@export var walk_width: float = 3.4

@export_group("Battlements")
@export var merlon_sink: float = 0.05
