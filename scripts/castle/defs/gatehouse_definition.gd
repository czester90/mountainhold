@tool
class_name GatehouseDefinition
extends Resource

## A gate block spanning the curtain along local +X: two piers flanking a central arched
## passage (ground -> passage_height), solid above, with the wall-walk running over the top.
## Ports: WallWalkEntry (-X), WallWalkExit (+X) at walk level.

@export var length: float = 8.0
@export var height: float = 6.0
@export var thickness: float = 3.0
@export var walk_width: float = 3.4
@export var passage_width: float = 3.2
@export var passage_height: float = 4.5
@export var merlon_sink: float = 0.05
## When > 0 the gatehouse becomes a GATE TOWER: side piers rise this far above the wall-walk and a
## battlemented block spans over the gate (with headroom so the walk still passes through).
@export var tower_height: float = 0.0
## Show a portcullis grille in the passage mouth (kit DoorSticker_Portcullis).
@export var portcullis: bool = false
