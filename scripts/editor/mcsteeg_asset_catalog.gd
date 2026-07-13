extends Node3D

## Stage 01 asset catalog / inspection scene (not gameplay).
## Loads the imported MCSTEEG GLB, lays every mesh piece out on a spaced grid
## over a 1 m reference floor, labels each with its source name and metric
## bounding size, and provides an orbit + free-fly inspection camera.
##
## Controls:
##   Right mouse drag : orbit   |  Mouse wheel : zoom
##   WASD + Q/E       : free-fly (hold to move the pivot)
##   R                : reset camera   |  Esc : quit

const GLB_SCENE: String = "res://assets/raw/mcsteeg_castle/Castles_and_Forts.glb"

const COLUMNS: int = 6
const CELL: float = 4.5

@onready var _pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera

var _yaw: float = -0.6
var _pitch: float = 0.5
var _distance: float = 26.0
var _pivot_home: Vector3

func _ready() -> void:
	_build_catalog()
	_pivot_home = _pivot.position
	_update_camera()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _build_catalog() -> void:
	var packed: PackedScene = load(GLB_SCENE)
	var glb: Node = packed.instantiate()
	var pieces: Array[MeshInstance3D] = []
	_collect_meshes(glb, pieces)
	pieces.sort_custom(func(a: MeshInstance3D, b: MeshInstance3D) -> bool: return a.name < b.name)

	var grid: Node3D = Node3D.new()
	grid.name = "AssetGrid"
	add_child(grid)

	var count: int = pieces.size()
	var rows: int = int(ceil(float(count) / float(COLUMNS)))
	var origin_x: float = -(float(COLUMNS) - 1.0) * CELL * 0.5
	var origin_z: float = 4.0

	for i in count:
		var src: MeshInstance3D = pieces[i]
		var col: int = i % COLUMNS
		var row: int = i / COLUMNS
		var cell_pos := Vector3(origin_x + float(col) * CELL, 0.0, origin_z + float(row) * CELL)
		_place_piece(grid, src, cell_pos)

	glb.queue_free()

func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node)
	for child in node.get_children():
		_collect_meshes(child, out)

func _place_piece(parent: Node3D, src: MeshInstance3D, cell_pos: Vector3) -> void:
	var holder: Node3D = Node3D.new()
	holder.name = str(src.name)
	holder.position = cell_pos
	parent.add_child(holder)

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = src.mesh
	holder.add_child(mi)

	# Recenter the piece over its cell and seat it on the floor.
	var aabb: AABB = src.mesh.get_aabb()
	var centre: Vector3 = aabb.position + aabb.size * 0.5
	mi.position = Vector3(-centre.x, -aabb.position.y, -centre.z)

	var label: Label3D = Label3D.new()
	label.text = "%s\n%.2f x %.2f x %.2f m" % [src.name, aabb.size.x, aabb.size.y, aabb.size.z]
	label.font_size = 48
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.95, 0.95, 0.88)
	label.outline_size = 16
	label.position = Vector3(0.0, aabb.size.y + 0.6, 0.0)
	holder.add_child(label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * 0.005
		_pitch = clamp(_pitch - mm.relative.y * 0.005, -1.4, 1.4)
		_update_camera()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_distance = max(3.0, _distance - 1.5)
			_update_camera()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_distance = min(80.0, _distance + 1.5)
			_update_camera()
	elif event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		if key.keycode == KEY_ESCAPE:
			get_tree().quit()
		elif key.keycode == KEY_R:
			_yaw = -0.6
			_pitch = 0.5
			_distance = 26.0
			_pivot.position = _pivot_home
			_update_camera()

func _process(delta: float) -> void:
	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): move.z -= 1.0
	if Input.is_key_pressed(KEY_S): move.z += 1.0
	if Input.is_key_pressed(KEY_A): move.x -= 1.0
	if Input.is_key_pressed(KEY_D): move.x += 1.0
	if Input.is_key_pressed(KEY_E): move.y += 1.0
	if Input.is_key_pressed(KEY_Q): move.y -= 1.0
	if move != Vector3.ZERO:
		var flat := Basis(Vector3.UP, _yaw)
		_pivot.position += flat * move.normalized() * 12.0 * delta

func _update_camera() -> void:
	var offset := Vector3(
		cos(_pitch) * sin(_yaw),
		sin(_pitch),
		cos(_pitch) * cos(_yaw)
	) * _distance
	_camera.position = offset
	_camera.look_at(_pivot.global_position, Vector3.UP)
