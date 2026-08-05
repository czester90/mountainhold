@tool
class_name StairDefinition
extends Resource

## A wooden switchback stair: straight flights zig-zagging up, joined by landings.
## Climbs total_rise metres. The first flight runs along local +X from StairEntry (bottom)
## and the top lands at StairExit. Flights alternate direction in two lanes offset in Z.

@export var total_rise: float = 6.0
@export var width: float = 2.0
@export var per_flight_rise: float = 3.0
@export var flight_run: float = 4.0
@export var step_rise: float = 0.42

@export_group("Look")
@export var tread_thickness: float = 0.12
@export var landing_thickness: float = 0.16
