@tool
class_name CausewayDefinition
extends Resource

## A built approach ramp (Helm's-Deep causeway): a paved deck running along local +X with a low
## stone parapet down each side. Built FLAT (run x width); the generator tilts the whole module to
## climb between two ground points, so the deck itself needs no rise baked in.

@export var run: float = 18.0            # length along local +X (set by the generator to the span)
@export var width: float = 7.0
@export var thickness: float = 0.6       # deck slab thickness (below the walking surface at y=0)
@export var parapet_height: float = 0.95
@export var parapet_thick: float = 0.4
