@tool
class_name KeepDefinition
extends Resource

## Square great-keep (stołp) straddling the apex of the curtain. Local X = curtain (side) axis
## where walls connect; local Z = gate axis (front faces the field). A gate tunnel pierces it at
## ground (front-back); the wall-walk passes through at walk_height (side-to-side); it rises to
## `height` with a merlon crown and roof deck.

@export var width: float = 18.0        # X: side to side (curtain direction), 3 kit cells
@export var depth: float = 12.0        # Z: front to back (gate direction), 2 kit cells
@export var height: float = 18.0       # 3 storeys
@export var walk_height: float = 6.0
@export var wall_thick: float = 1.3

@export_group("Gate")
@export var gate_width: float = 4.0
@export var gate_height: float = 5.0

@export_group("Wall-walk pass")
@export var pass_height: float = 4.2   # side opening height above walk_height

@export_group("Roof")
@export var merlon_height: float = 1.0
