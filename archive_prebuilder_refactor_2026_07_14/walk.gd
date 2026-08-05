extends Node3D

## Walkable first-person character (CharacterBody3D + capsule collision) dropped into the
## fortress so you can walk it yourself. WASD move, mouse look, Space jump, Shift run,
## Esc release mouse / quit. Includes stair step-up so the mural stairs and spiral are
## climbable. All fortress geometry + terrain already have collision.

const SCENE := "res://scenes/test/fortress_kit_test.tscn"
const SPEED := 6.0
const RUN := 13.0
const GRAV := 24.0
const JUMP := 8.5
const STEP := 0.65

var _player: CharacterBody3D
var _cam: Camera3D
var _terrain: Node
var _yaw := PI
var _pitch := 0.0
var _ready_done := false
var _shotn := 0
const SHOT_DIR := "res://screenshots/ingame"

func _ready() -> void:
	var scene: Node = load(SCENE).instantiate()
	add_child(scene)
	scene.get_node("FlyCamera").current = false
	_terrain = scene.get_node("Terrain")
	for _i in 100:
		await get_tree().process_frame
	_build_player()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_ready_done = true

func _h(x: float, z: float) -> float:
	var v: float = _terrain.get("data").get_height(Vector3(x, 0.0, z))
	return 0.0 if is_nan(v) else v

func _build_player() -> void:
	_player = CharacterBody3D.new()
	_player.floor_max_angle = deg_to_rad(60.0)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.4; cap.height = 1.7
	col.shape = cap
	_player.add_child(col)
	_cam = Camera3D.new(); _cam.fov = 75.0; _cam.far = 4000.0
	_cam.position = Vector3(0, 0.65, 0)
	_player.add_child(_cam); _cam.current = true
	_terrain.call("set_camera", _cam)
	add_child(_player)
	var b := _h(330.0 - 24.0, 500.0)
	_player.global_position = Vector3(330.0 - 30.0, b + 2.0, 500.0)   # courtyard, in front of the gate
	_player.rotation.y = _yaw

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * 0.003
		_pitch = clampf(_pitch - event.relative.y * 0.003, -1.4, 1.4)
		if _player:
			_player.rotation.y = _yaw
			_cam.rotation.x = _pitch
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			get_tree().quit()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_P:
		_screenshot()
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _screenshot() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	var img: Image = get_viewport().get_texture().get_image()
	var path := "%s/ingame_%03d.png" % [SHOT_DIR, _shotn]
	img.save_png(path)
	print("SCREENSHOT saved: ", ProjectSettings.globalize_path(path))
	_shotn += 1

func _physics_process(delta: float) -> void:
	if not _ready_done or _player == null:
		return
	var basis := Basis(Vector3.UP, _yaw)
	var wish := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): wish -= basis.z
	if Input.is_key_pressed(KEY_S): wish += basis.z
	if Input.is_key_pressed(KEY_A): wish -= basis.x
	if Input.is_key_pressed(KEY_D): wish += basis.x
	wish = wish.normalized()
	var spd := RUN if Input.is_key_pressed(KEY_SHIFT) else SPEED
	_player.velocity.x = wish.x * spd
	_player.velocity.z = wish.z * spd
	if _player.is_on_floor():
		if Input.is_key_pressed(KEY_SPACE):
			_player.velocity.y = JUMP
		elif _player.velocity.y < 0.0:
			_player.velocity.y = -1.0
	else:
		_player.velocity.y -= GRAV * delta
	var pre := _player.global_position
	_player.move_and_slide()
	# stair step-up: if blocked while trying to move, lift over a low step
	if wish != Vector3.ZERO and _player.is_on_floor():
		var moved := _player.global_position - pre; moved.y = 0.0
		if moved.length() < spd * delta * 0.5:
			var up_t := _player.global_transform
			up_t.origin += Vector3.UP * STEP
			if not _player.test_move(up_t, wish * 0.4):
				_player.global_position += Vector3.UP * STEP + wish * 0.4
