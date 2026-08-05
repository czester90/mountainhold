class_name ArcherEnemy
extends Enemy

## Enemy archer: stands off in the field and looses REAL arrows at defenders it can see (player or
## ally). Never shoots the gate. It aims at the target's position AT FIRE TIME (no lead) and the
## arrow takes time to arrive — so a moving defender genuinely dodges (the arrow flies past and deals
## no damage). Hit accuracy is biased by cover via _exposure(): open target = tight aim, a target on
## a rampart or behind a tower window = wider aim (more likely to sail past or strike the masonry).

const SHOOT_RANGE := 55.0
const MAX_DEFENDER_CANDIDATES := 8
const ProjectilePoolScript := preload("res://scripts/core/projectile_pool.gd")
const DEFAULT_STATS := preload("res://data/enemy_archer.tres")

var shoot_range: float = SHOOT_RANGE
var arrow_speed: float = 32.0

func _ready() -> void:
	if stats == null or stats.resource_path == "res://data/enemy_infantry.tres":
		stats = DEFAULT_STATS
	super()

func _tune() -> void:
	if stats != null:
		shoot_range = stats.sight_range
		arrow_speed = stats.arrow_speed
		attack_damage = stats.ranged_attack_damage

func _build_visual() -> Dictionary:
	return Soldier.build(self, Color(0.55, 0.13, 0.12), true)   # dark-red, with a bow

# stand off and shoot at defenders; never damages the gate
func _at_gate(delta: float, dist: float) -> bool:
	if dist <= attack_range:
		_attack(delta, "defenders")
		return true
	return false

func _at_wall_assault(delta: float, dist: float) -> bool:
	if _try_use_active_ladder(delta):
		return true
	if dist <= attack_range:
		_attack(delta, "defenders")
		return true
	return false

func _on_attacked(_damage: float) -> void:
	var tgt := _find_defender()
	if tgt == null:
		return                                 # no one in sight -> hold fire (no invisible gate pinging)
	var accurate := randf() < clampf(0.78 * _exposure(tgt), 0.12, 0.85)
	_fire_arrow(tgt, accurate)

func _fire_arrow(tgt: Node3D, accurate: bool) -> void:
	var muzzle := global_position + Vector3.UP * 1.5
	var aim: Vector3 = tgt.global_position + Vector3.UP * 1.1     # AT current position — no lead, so moving dodges
	if not accurate:
		aim += Vector3(randf_range(-2.2, 2.2), randf_range(-0.8, 2.2), randf_range(-2.2, 2.2))
	var dir := (aim - muzzle)
	if dir.length() < 0.01:
		return
	var a := ProjectilePoolScript.acquire_enemy_arrow(self)
	a.call("setup", muzzle, dir.normalized(), arrow_speed, attack_damage)

# nearest defender (player or ally) within range that the archer has a clear central line of sight to
func _find_defender() -> Node3D:
	var start_us := Time.get_ticks_usec()
	var origin := global_position + Vector3.UP * 1.4
	var space := get_world_3d().direct_space_state
	var best: Node3D = null
	var bestd := shoot_range * shoot_range
	var cands: Array = _nearby_defenders(origin, shoot_range)
	var pl := _active_player()
	if pl:
		cands.append(pl)
	var scored: Array = []
	for c in cands:
		if not (c is Node3D) or not is_instance_valid(c):
			continue
		var tp: Vector3 = (c as Node3D).global_position + Vector3.UP * 1.2
		var d2 := origin.distance_squared_to(tp)
		if d2 > bestd:
			continue
		scored.append([d2, c])
	scored.sort_custom(func(a, b): return a[0] < b[0])
	for i in mini(scored.size(), MAX_DEFENDER_CANDIDATES):
		var c: Node3D = scored[i][1]
		var tp: Vector3 = c.global_position + Vector3.UP * 1.2
		var d2: float = scored[i][0]
		var q := PhysicsRayQueryParameters3D.create(origin, tp)
		q.collision_mask = 1 << 0                       # world only — a wall between us blocks the shot
		var ray_start_us := Time.get_ticks_usec()
		var hit := space.intersect_ray(q)
		_record_perf_us(&"enemy_archer_los_ray", ray_start_us)
		if not hit.is_empty() and origin.distance_squared_to(hit.position) < d2 - 4.0:
			continue                                    # blocked by masonry
		best = c
		bestd = d2
	_record_perf_us(&"enemy_archer_find_defender", start_us)
	return best

func _nearby_defenders(origin: Vector3, radius: float) -> Array:
	var registry := _combat_registry()
	if registry != null and registry.has_method("active_allies_near"):
		return registry.call("active_allies_near", origin, radius)
	return _active_allies()

# fraction of the target the archer can see (0..1): rays to chest/shoulders/legs/head; masonry
# (merlons on a rampart, jambs around a window/loop) blocks some -> harder to hit behind cover
func _exposure(target: Node3D) -> float:
	var start_us := Time.get_ticks_usec()
	var origin := global_position + Vector3.UP * 1.4
	var space := get_world_3d().direct_space_state
	var base := target.global_position
	var flat := base - origin
	flat.y = 0.0
	if flat.length() < 0.01:
		return 1.0
	var right := flat.normalized().cross(Vector3.UP).normalized()
	var offsets := [
		Vector3.UP * 1.2,
		Vector3.UP * 1.2 + right * 0.45,
		Vector3.UP * 1.2 - right * 0.45,
		Vector3.UP * 0.5,
		Vector3.UP * 1.75,
	]
	var clear := 0
	for off in offsets:
		var tp: Vector3 = base + off
		var d2 := origin.distance_squared_to(tp)
		var q := PhysicsRayQueryParameters3D.create(origin, tp)
		q.collision_mask = 1 << 0
		var ray_start_us := Time.get_ticks_usec()
		var hit := space.intersect_ray(q)
		_record_perf_us(&"enemy_archer_exposure_ray", ray_start_us)
		if hit.is_empty() or origin.distance_squared_to(hit.position) >= d2 - 4.0:
			clear += 1
	_record_perf_us(&"enemy_archer_exposure", start_us)
	return float(clear) / float(offsets.size())
