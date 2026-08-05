extends CharacterBody3D

## First-person archer: WASD + mouse look + jump, and a bow driven by the GLTF's animation clips
## (IDLE -> AIM(draw) -> AIM_IDLE(hold) -> FIRE(release)). Hold LMB to draw (power builds with
## draw time), release to loose an arrow. Esc frees the mouse / quits.

const ARROW := preload("res://scenes/player/arrow.tscn")
const ProjectilePoolScript := preload("res://scripts/core/projectile_pool.gd")

signal hit_enemy          # a player arrow struck an enemy (for hitmarker/feedback)
signal killed_enemy       # a player arrow struck the killing blow (for a distinct kill-confirm)
signal shot_fired         # a player arrow was loosed (for sfx)
signal player_hurt(from_pos: Vector3)   # took damage from enemy fire (for a HUD directional flash)
signal player_died        # hp reached 0 (game over)

@export var max_hp: float = 100.0
@export var speed: float = 6.0
@export var run_speed: float = 11.0
@export var jump_velocity: float = 6.5
@export var gravity: float = 20.0
@export var mouse_sens: float = 0.0025
@export var step_height: float = 0.65     # climb steps/ledges up to this tall without jumping
@export var floor_climb_deg: float = 60.0 # walkable slope
@export var start_yaw: float = 0.0        # initial facing (radians about Y)
@export var min_draw: float = 0.12       # below this a release doesn't fire
@export var full_draw: float = 1.0       # draw time for full power
@export var min_arrow_speed: float = 24.0
@export var max_arrow_speed: float = 60.0
@export var spread_min_deg: float = 0.7    # cone at full draw, standing still
@export var spread_max_deg: float = 3.0    # cone at snap-shot / while moving
@export var arrow_damage: float = 55.0
@export var melee_damage: float = 6.0
@export var defense: float = 0.0
@export_range(0.0, 0.85, 0.01) var armor: float = 0.0
@export var stats: UnitStats = preload("res://data/player_hero.tres")
# Viewmodel placement. The GLTF rig is a ~2.5 m arms+bow prop (base near origin, bow centred at
# y~1.42, arrow pointing +Z). We ignore its baked Camera_01 (authored sideways) and pose the rig
# by hand as a first-person viewmodel: scale it down, spin the arrow to point into the screen (-Z),
# then offset it into the lower-centre of the view.
@export var viewmodel_scale: float = 0.5
@export var viewmodel_rot_deg: Vector3 = Vector3(0.0, 180.0, 0.0)
@export var viewmodel_offset: Vector3 = Vector3(0.08, -0.72, -0.5)

@onready var head: Node3D = $Head
@onready var cam: Camera3D = $Head/Camera3D
@onready var spawn: Marker3D = $Head/Camera3D/ArrowSpawn
var anim: AnimationPlayer
var _rig_arrow: Node3D   # the bow's nocked-arrow mesh; hidden once loosed, shown when drawing

enum State { IDLE, DRAW, HELD, FIRE }
var _state: State = State.IDLE
var _draw_t: float = 0.0
var _yaw: float = 0.0
var _pitch: float = 0.0
var _sens_mult: float = 1.0
var hp: float = 100.0
var type_id: StringName = &"hero"
var display_name: String = "Hero"
var faction: int = UnitStats.Faction.PLAYER
var role: int = UnitStats.Role.HERO
var behavior_tags: PackedStringArray = []
var level: int = 1
var xp: int = 0
var kills: int = 0
var armor_type: StringName = &"leather"
var _dead: bool = false
var test_wish: Vector3 = Vector3.ZERO   # set by automated tests to drive the REAL movement code
var _base_level: int = 1
var _base_arrow_damage: float = 55.0
var _base_melee_damage: float = 6.0
var _base_defense: float = 0.0
var _base_armor: float = 0.0
var _base_min_arrow_speed: float = 24.0
var _base_max_arrow_speed: float = 60.0

func _ready() -> void:
	add_to_group("player")            # so enemy archers can find + target the player
	_apply_stats()
	hp = max_hp
	_yaw = start_yaw    # honour the spawn facing so mouse-look starts from it, no snap
	rotation.y = start_yaw
	var gs := get_node_or_null("/root/GameSettings")
	if gs:
		_sens_mult = gs.mouse_sensitivity
	var bow: Node3D = get_node_or_null("Head/Camera3D/Bow")
	if bow:
		for c in bow.find_children("*", "AnimationPlayer", true, false):
			anim = c
			break
		# kill the rig's own camera so it never becomes current
		var rig_cam := bow.find_child("Camera_01", true, false)
		if rig_cam and rig_cam is Camera3D:
			(rig_cam as Camera3D).current = false
		# the rig's nocked arrow; hidden while idle (no arrow), nocked on draw, loosed on fire
		_rig_arrow = bow.find_child("fleche", true, false)
		if _rig_arrow:
			_rig_arrow.visible = false
		_pose_viewmodel(bow)
	floor_max_angle = deg_to_rad(floor_climb_deg)
	floor_snap_length = 0.6        # stick to stair ramps so climbing is smooth, not bouncy
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if anim:
		anim.animation_finished.connect(_on_anim_finished)
		_play("Bow_IDLE", true)

func _pose_viewmodel(bow: Node3D) -> void:
	var b := Basis.from_euler(Vector3(
		deg_to_rad(viewmodel_rot_deg.x),
		deg_to_rad(viewmodel_rot_deg.y),
		deg_to_rad(viewmodel_rot_deg.z))).scaled(Vector3.ONE * viewmodel_scale)
	bow.transform = Transform3D(b, viewmodel_offset)

func _apply_stats() -> void:
	if stats == null:
		return
	type_id = stats.type_id
	display_name = stats.display_name
	faction = stats.faction
	role = stats.role
	level = stats.level
	_base_level = stats.level
	xp = stats.xp
	kills = stats.kills
	max_hp = stats.max_hp
	armor_type = stats.armor_type
	_base_arrow_damage = stats.ranged_attack_damage
	_base_melee_damage = stats.melee_attack_damage
	_base_defense = stats.defense
	_base_armor = stats.armor
	_base_max_arrow_speed = stats.arrow_speed
	_base_min_arrow_speed = min_arrow_speed
	spread_min_deg = stats.spread_deg
	behavior_tags = stats.behavior_tags
	_apply_progression()

func _apply_progression() -> void:
	level = UnitStats.level_for_kills(_base_level, kills)
	var mult := UnitStats.stat_multiplier(_base_level, level)
	arrow_damage = _base_arrow_damage * mult
	melee_damage = _base_melee_damage * mult
	defense = _base_defense * mult
	armor = clampf(_base_armor * mult, 0.0, 0.85)
	min_arrow_speed = _base_min_arrow_speed * mult
	max_arrow_speed = _base_max_arrow_speed * mult

# Climb a low obstacle ahead by the smallest lift that clears it (<= step_height), then advance.
# Robust vs the old fixed-teleport: no jitter on tiny seams, never launches the player off a wall.
func _step_up(wish: Vector3, reach: float) -> void:
	var fwd := Vector3(wish.x, 0.0, wish.z).normalized() * reach
	for h in [0.12, 0.22, 0.35, 0.5, step_height]:
		if h > step_height:
			break
		var lifted := global_transform.translated(Vector3.UP * h)
		if not test_move(lifted, fwd):
			# there's clear space a step up and forward -> take it, then gravity re-settles us
			global_position += Vector3.UP * h
			if not test_move(global_transform, fwd):
				global_position += fwd
			return

func _play(clip: String, loop: bool) -> void:
	if anim == null or not anim.has_animation(clip):
		return
	var a := anim.get_animation(clip)
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	anim.play(clip)

func _on_anim_finished(clip: String) -> void:
	if clip == "Bow_AIM" and _state == State.DRAW:
		_state = State.HELD
		_play("Bow_AIM_IDLE", true)
	elif clip == "Bow_FIRE":
		_state = State.IDLE
		_play("Bow_IDLE", true)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var gs := get_node_or_null("/root/GameSettings")
		var mult: float = gs.mouse_sensitivity if gs else _sens_mult
		var sens := mouse_sens * mult
		_yaw -= event.relative.x * sens
		_pitch = clampf(_pitch - event.relative.y * sens, -1.45, 1.45)
		rotation.y = _yaw
		head.rotation.x = _pitch
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_begin_draw()
		else:
			_release()

func _begin_draw() -> void:
	if _state == State.IDLE:
		_state = State.DRAW
		_draw_t = 0.0
		if _rig_arrow:
			_rig_arrow.visible = true   # nock a fresh arrow
		_play("Bow_AIM", false)

func _release() -> void:
	if _state == State.DRAW or _state == State.HELD:
		if _draw_t >= min_draw:
			_fire()
			if _rig_arrow:
				_rig_arrow.visible = false   # arrow is loosed — the bow is now empty
			_state = State.FIRE
			_play("Bow_FIRE", false)
		else:
			_state = State.IDLE              # sub-min tap: relax the string, no phantom loose
			_play("Bow_IDLE", true)

func _fire() -> void:
	for spawner in get_tree().get_nodes_in_group("wave_spawner"):
		if spawner.has_method("start_assault"):
			spawner.call("start_assault")
	var t := clampf((_draw_t - min_draw) / maxf(0.01, full_draw - min_draw), 0.0, 1.0)
	var sp: float = lerpf(min_arrow_speed, max_arrow_speed, t)
	# accuracy cone: tight at full draw, wider on snap-shots and while moving, so repeated
	# shots scatter naturally instead of stacking into one perfect line.
	var moving := 1.0 if Vector3(velocity.x, 0.0, velocity.z).length() > 1.0 else 0.0
	var spread := deg_to_rad(lerpf(spread_max_deg, spread_min_deg, t) + moving * 1.5)
	var xf := spawn.global_transform
	xf.basis = xf.basis.rotated(xf.basis.y.normalized(), randf_range(-spread, spread)) \
		.rotated(xf.basis.x.normalized(), randf_range(-spread, spread))
	var a := ProjectilePoolScript.acquire_player_arrow(self)
	a.damage = arrow_damage
	a.launch(xf, sp, self)
	a.hit.connect(_on_arrow_hit)
	shot_fired.emit()
	var au := get_node_or_null("/root/Audio")
	if au:
		au.play_2d("bow_release", "Combat")

func _on_arrow_hit(body: Node) -> void:
	if body and (body.is_in_group("enemy") or body.is_in_group("siege_ladder") or body.get("xp_value") != null):
		hit_enemy.emit()
		if body.get("hp") != null and float(body.get("hp")) <= 0.0:
			kills += 1
			if body.get("xp_value") != null:
				xp += int(body.get("xp_value"))
			_apply_progression()
			killed_enemy.emit()

# enemy archers call this; at 0 hp the game is lost. from_pos = roughly where the shot came from
# (for the HUD directional-damage indicator)
func take_damage(amount: float, from_pos: Vector3 = Vector3.INF) -> void:
	if _dead:
		return
	var dealt := maxf(0.0, amount - defense) * (1.0 - clampf(armor, 0.0, 0.85))
	hp = maxf(0.0, hp - dealt)
	player_hurt.emit(from_pos)
	var au := get_node_or_null("/root/Audio")
	if au:
		au.play_2d("impact_body", "UI")
	if hp <= 0.0:
		_dead = true
		player_died.emit()

func is_dead() -> bool:
	return _dead

func health_fraction() -> float:
	return clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 0.0

## HUD reads these for the draw-power indicator
func draw_fraction() -> float:
	return clampf(_draw_t / full_draw, 0.0, 1.0)

func is_drawing() -> bool:
	return _state == State.DRAW or _state == State.HELD

func _physics_process(delta: float) -> void:
	if _state == State.DRAW or _state == State.HELD:
		_draw_t += delta
	var basis := Basis(Vector3.UP, _yaw)
	var wish := Vector3.ZERO
	if test_wish != Vector3.ZERO:
		wish = test_wish                                     # automated test drives real movement
	else:
		if Input.is_key_pressed(KEY_W): wish -= basis.z
		if Input.is_key_pressed(KEY_S): wish += basis.z
		if Input.is_key_pressed(KEY_A): wish -= basis.x
		if Input.is_key_pressed(KEY_D): wish += basis.x
	wish = wish.normalized()
	var spd: float = run_speed if Input.is_key_pressed(KEY_SHIFT) else speed
	velocity.x = wish.x * spd
	velocity.z = wish.z * spd
	if is_on_floor():
		if Input.is_key_pressed(KEY_SPACE):
			velocity.y = jump_velocity
		elif velocity.y < 0.0:
			velocity.y = -1.0
	else:
		velocity.y -= gravity * delta
	var pre := global_position
	move_and_slide()
	# stair step-up: if a low step/lip/seam blocked us, climb it by the MINIMAL height that clears
	# (not a fixed 0.65 teleport) so climbing is smooth and we never get shoved off a ledge.
	if wish != Vector3.ZERO and (is_on_floor() or is_on_wall()):
		var moved := global_position - pre
		moved.y = 0.0
		var wanted := spd * delta
		if moved.length() < wanted * 0.7:
			_step_up(wish, maxf(0.4, wanted * 1.5))
