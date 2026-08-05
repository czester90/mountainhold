extends Node3D

## Free-fly viewer for the modular prototype: loads prototype.tscn and lets you look around.
## Mouse = look, WASD = move, Q/E = down/up, Shift = fast, Esc = release mouse / quit.

const SCENE := "res://scenes/castle/fortress.tscn"
const SPEED := 14.0
const FAST := 40.0

var _cam: Camera3D
var _yaw := PI * 0.85
var _pitch := -0.35

func _ready() -> void:
	var scene: Node = load(SCENE).instantiate()
	add_child(scene)
	var sc := scene.get_node_or_null("Camera3D")
	if sc:
		sc.current = false
	_cam = Camera3D.new()
	_cam.fov = 65.0
	_cam.far = 4000.0
	_cam.global_position = Vector3(320, 32, 500)
	add_child(_cam)
	_cam.current = true
	_cam.look_at(Vector3(295, 20, 500), Vector3.UP)
	_yaw = _cam.rotation.y
	_pitch = _cam.rotation.x
	_apply_look()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _apply_look() -> void:
	_cam.rotation = Vector3(_pitch, _yaw, 0)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * 0.004
		_pitch = clampf(_pitch - event.relative.y * 0.004, -1.5, 1.5)
		_apply_look()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			get_tree().quit()
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var dir := Vector3.ZERO
	var b := _cam.global_transform.basis
	if Input.is_key_pressed(KEY_W): dir -= b.z
	if Input.is_key_pressed(KEY_S): dir += b.z
	if Input.is_key_pressed(KEY_A): dir -= b.x
	if Input.is_key_pressed(KEY_D): dir += b.x
	if Input.is_key_pressed(KEY_E): dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q): dir += Vector3.DOWN
	if dir != Vector3.ZERO:
		var spd := FAST if Input.is_key_pressed(KEY_SHIFT) else SPEED
		_cam.global_position += dir.normalized() * spd * delta
