extends Node3D

## Places friendly archers AUTOMATICALLY by raycasting onto the actual wall-walks / tower decks the
## fortress generator built — so defenders always sit on a real surface (never float) and adapt to
## any structural change. No hand-placed positions. Runs after the fortress + terrain are built.

const ALLY := preload("res://scenes/ally/ally_archer.tscn")
const CollisionLayers := preload("res://scripts/core/collision_layers.gd")

# outer D-curtain geometry (mirror of FortressGenerator's constants)
@export var centre := Vector3(330.0, 0.0, 500.0)
@export var wall_r := 44.0
@export var tower_project := 0.5
@export var apex := PI
@export var open_half := 1.35
@export var runs := 5
@export var keep_x := 360.0
@export var avoid := Vector3(294.0, 0.0, 480.0)   # player spawn — keep archers clear of it
@export var avoid_radius := 5.0
@export var desired_count := 20

var _combat_registry: Node

func _ready() -> void:
	# let the fortress @tool generators finish building (terrain sculpt is the slow part)
	for _i in 90:
		await get_tree().process_frame
	_combat_registry = get_tree().get_first_node_in_group("combat_registry")
	var space := get_world_3d().direct_space_state
	var placed := _place_from_castle_model(space)
	if placed >= desired_count:
		print("ally_placer: placed %d archers from CastleModel" % placed)
		return
	var used_model := placed > 0
	# Defenders concentrate on the WESTERN gate-approach kill-zone in an X-shaped crossfire: a frontal
	# line on the apex rampart + the gate gallery/roof directly over it + the two flanking corner
	# towers raking the funnel from the sides. The rear (inner ring / keep roof) barely sees a target
	# before the gate is breached, so it's cut to a single post-breach reserve.
	# --- apex rampart: tight frontal line facing the field (was a wide, half-wasted spread) ---
	for i in 10:
		if placed >= desired_count:
			break
		var t := float(i) / 9.0
		var ang: float = lerp(apex - 0.65, apex + 0.65, t)
		placed += _try_place(space, wall_r - 1.4, ang, 19.0, 23.5, 2.6)   # walk ~21 (exclude merlon tops)
	# --- gate tower: roof-edge firing slots; raycast-verified to see attackers before they tuck under the arch ---
	for gz in [495.0, 498.0, 501.0, 504.0]:
		if placed >= desired_count:
			break
		placed += _try_place_xz(space, 284.0, gz, 25.5, 29.0, 1.32)
	for gz in [497.0, 500.0, 503.0]:
		if placed >= desired_count:
			break
		placed += _try_place_xz(space, 286.8, gz, 25.5, 29.0, 1.32)
	# --- flanking corner towers: THREE each for enfilade crossfire across the approach (the key asset) ---
	var mid := runs / 2
	for k in [mid - 1, mid + 2]:
		var a: float = lerp(apex - open_half, apex + open_half, float(k) / float(runs))
		var tc := centre + Vector3((wall_r + tower_project) * cos(a), 0.0, (wall_r + tower_project) * sin(a))
		var to_gate := (Vector3(290.0, 0.0, 500.0) - tc)
		to_gate.y = 0.0
		to_gate = to_gate.normalized()
		var side := Vector3.UP.cross(to_gate).normalized()
		for offset in [to_gate * 3.0, to_gate * 1.2, side * 2.1, -side * 2.1, Vector3.ZERO]:
			if placed >= desired_count:
				break
			placed += _try_place_xz(space, tc.x + offset.x, tc.z + offset.z, 24.5, 30.0, 1.32)  # deck ~27
	# --- inner ring: a single post-breach reserve (rear archers can't see the approach; keep roof cut) ---
	if placed < desired_count:
		placed += _try_place_xz(space, keep_x - 15.0, centre.z, 28.0, 35.0, 1.32)
	print("ally_placer: placed %d archers%s" % [placed, " from CastleModel + fallback" if used_model else ""])

func _place_from_castle_model(space: PhysicsDirectSpaceState3D) -> int:
	var model := get_tree().get_first_node_in_group("castle_model")
	if model == null or not model.has_method("archer_slots"):
		return 0
	var placed := 0
	for slot in model.call("archer_slots"):
		if not slot is Node3D or not is_instance_valid(slot):
			continue
		var y_lo := float(slot.get_meta("y_lo", -INF))
		var y_hi := float(slot.get_meta("y_hi", INF))
		var muzzle := float(slot.get_meta("muzzle_height", 1.6))
		placed += _try_place_slot(space, slot as Node3D, y_lo, y_hi, muzzle)
	return placed

func _try_place_slot(space: PhysicsDirectSpaceState3D, slot: Node3D, y_lo: float, y_hi: float, muzzle: float) -> int:
	var point := slot.global_position
	var placed := _try_place_xz(space, point.x, point.z, y_lo, y_hi, muzzle)
	if placed <= 0:
		return 0
	var ally := get_child(get_child_count() - 1) as Node3D
	if ally != null and is_instance_valid(ally):
		ally.rotation.y = slot.rotation.y
	return placed

func _try_place(space: PhysicsDirectSpaceState3D, radius: float, ang: float, y_lo: float, y_hi: float, muzzle: float) -> int:
	return _try_place_xz(space, centre.x + radius * cos(ang), centre.z + radius * sin(ang), y_lo, y_hi, muzzle)

# raycast straight down; place an archer only if the surface height is within [y_lo, y_hi]
# (a real rampart/deck, not the ground or a merlon top), seated exactly on it. Returns 1 if placed.
func _try_place_xz(space: PhysicsDirectSpaceState3D, x: float, z: float, y_lo: float, y_hi: float, muzzle: float) -> int:
	var top := Vector3(x, 70.0, z)
	var q := PhysicsRayQueryParameters3D.create(top, top - Vector3(0, 90, 0))
	q.collision_mask = CollisionLayers.WORLD
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return 0
	var y: float = hit.position.y
	if y < y_lo or y > y_hi:
		return 0
	if Vector2(x - avoid.x, z - avoid.z).length() < avoid_radius:   # keep clear of the player spawn
		return 0
	# don't stack two archers almost on top of each other
	for c in get_children():
		if Vector2(c.global_position.x - x, c.global_position.z - z).length() < 2.3:
			return 0
	var ally := ALLY.instantiate()
	add_child(ally)
	ally.set("muzzle_height", muzzle)
	ally.global_position = Vector3(x, y, z)
	var out := (Vector3(x, 0, z) - Vector3(centre.x, 0, centre.z))
	if out.length() > 0.1:
		ally.rotation.y = atan2(out.x, out.z)
	if _combat_registry != null and _combat_registry.has_method("register_ally"):
		_combat_registry.call("register_ally", ally)
	return 1
