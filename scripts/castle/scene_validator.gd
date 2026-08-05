class_name SceneValidator
extends RefCounted

## Formalises the ad-hoc probe/qa raycast checks into a reusable fortress-integrity validator.
## Each walk check casts a ray straight down at a point that MUST have a walkable surface at (or
## above) a minimum height — if the ray misses or hits low (bare ground / void), the structure has
## a gap or a floating/detached piece there. This directly guards the gate<->wall seam bug we hit.
## Ground checks assert terrain is present. Returns a list of human-readable issues (empty = OK).

## [label, x, z, min_y]  — a walk surface must exist at >= min_y here
const WALK_CHECKS := [
	["gate walk (courtyard junction)", 289.0, 492.0, 19.0],
	["gate walk (over passage, roofed)", 289.0, 500.0, 19.0],
	["gate walk (north junction)", 289.0, 508.0, 19.0],
	["rampart at mural-stair top", 293.0, 481.0, 19.0],
	["curtain rampart (mid run)", 290.0, 486.0, 19.0],
]

## [label, x, z]  — terrain/ground must exist here (not a hole in the world)
const GROUND_CHECKS := [
	["courtyard floor", 310.0, 500.0],
	["western field", 250.0, 500.0],
]

func validate(space: PhysicsDirectSpaceState3D) -> Array:
	var issues: Array = []
	for c in WALK_CHECKS:
		var y: Variant = _walk_y_near(space, c[1], c[2])
		if y == null:
			issues.append("%s: NO surface (void/gap)" % c[0])
		elif float(y) < float(c[3]):
			issues.append("%s: surface y=%.1f below expected %.1f (gap/floating)" % [c[0], y, c[3]])
	for c in GROUND_CHECKS:
		if _ray(space, c[1], c[2]) == null:
			issues.append("%s: NO ground (hole in world)" % c[0])
	return issues

func _walk_y_near(space: PhysicsDirectSpaceState3D, x: float, z: float) -> Variant:
	var best: Variant = null
	for off in [Vector2.ZERO, Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(0.0, -1.0)]:
		var y: Variant = _ray(space, x + off.x, z + off.y)
		if y == null:
			continue
		if best == null or float(y) > float(best):
			best = y
	return best

func _ray(space: PhysicsDirectSpaceState3D, x: float, z: float) -> Variant:
	var from := Vector3(x, 60.0, z)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -90, 0))
	q.collision_mask = 1
	var r := space.intersect_ray(q)
	return r.position.y if r else null
