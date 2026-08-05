@tool
class_name WallDefinition
extends Resource

## A straight curtain-wall segment running along local +X, seated on the ground (y=0).
## The wall-walk surface is at y=height on the inner (+Z) side; the parapet with merlons
## runs along the outer (-Z) edge.

@export var length: float = 12.0
@export var height: float = 6.0
@export var thickness: float = 2.6
@export var walk_width: float = 3.4

@export_group("Battlements")
@export var merlon_width: float = 1.0
@export var merlon_height: float = 1.2
@export var merlon_depth: float = 0.6
@export var merlon_gap: float = 1.0
