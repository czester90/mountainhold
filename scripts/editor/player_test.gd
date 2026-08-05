extends Node3D

## Automated physics playtest: spawns a real CharacterBody3D (capsule + collision),
## drops it into the courtyard, and drives it along a waypoint route
##   courtyard -> tower door -> internal spiral -> tower roof
## using gravity + move_and_slide + stair step-up. Logs height progression and whether
## it reaches the roof (or gets stuck / falls through), and shoots milestone screenshots.

const OUT := "res://screenshots/player_test"
const SCENE := "res://scenes/test/fortress_kit_test.tscn"
const SPEED := 3.5
const GRAV := 22.0
const STEP := 0.9        # max stair step-up height (steps rise 0.5)

var _cam: Camera3D
var _player: CharacterBody3D
var _scene: Node
var _terrain: Node
var _b := 0.0
var _tc := Vector3.ZERO
var _route: Array = []
var _wi := 0
var _t := 0.0
var _wp_t := 0.0
var _log: Array = []
var _ymax := -1e9
var _shot := {}
var _active := false
var _last_log_t := 0.0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var scene: Node = load(SCENE).instantiate()
	add_child(scene)
	_scene = scene
	scene.get_node("FlyCamera").current = false
	_terrain = scene.get_node("Terrain")
	_cam = Camera3D.new(); _cam.fov = 70.0; _cam.far = 4000.0
	add_child(_cam); _cam.current = true
	_terrain.call("set_camera", _cam)
	for _i in 100:
		await RenderingServer.frame_post_draw
	_b = _h(330.0 - 12.0, 500.0)
	_build_player()
	_build_route()
	_active = true

func _h(x: float, z: float) -> float:
	var v: float = _terrain.get("data").get_height(Vector3(x, 0.0, z))
	return 0.0 if is_nan(v) else v

func _build_player() -> void:
	_player = CharacterBody3D.new()
	_player.floor_max_angle = deg_to_rad(50.0)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.4; cap.height = 1.8
	col.shape = cap
	_player.add_child(col)
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new(); cm.radius = 0.4; cm.height = 1.8; mi.mesh = cm
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(1.0, 0.4, 0.05); mat.emission_enabled = true; mat.emission = Color(0.6, 0.2, 0.0)
	mi.material_override = mat
	_player.add_child(mi)
	add_child(_player)

const CX := 330.0
const CZ := 500.0
const WALL_R := 44.0
const OPEN_HALF := 1.35

func _t_ang(k: float) -> float:
	return lerp(PI - OPEN_HALF, PI + OPEN_HALF, k / 5.0)

func _arc(a: float) -> Vector3:
	return Vector3(CX + WALL_R * cos(a), _b, CZ + WALL_R * sin(a))

func _inw(p: Vector3) -> Vector3:
	return Vector3(CX - p.x, 0, CZ - p.z).normalized()

func _build_route() -> void:
	var nav: Dictionary = _scene.get("nav")
	var towers: Array = nav["towers"]
	var stairs: Array = nav["stairs"]
	var tw: Dictionary = towers[0]
	_tc = tw["centre"]
	# pick the mural stair whose landing is nearest this tower's door
	var best: Dictionary = stairs[0]
	var bestd := 1e9
	for s in stairs:
		var d: float = (s["landing"] as Vector3).distance_to(tw["entry"] as Vector3)
		if d < bestd:
			bestd = d; best = s
	var sfoot: Vector3 = best["foot"]
	var sinw := _inw(sfoot)
	# TOWER CLIMB TEST: spawn on the rampart at the tower door, go through -> spiral -> roof.
	# (Stairs are confirmed OK by the user; this isolates whether you can get up the tower.)
	_player.global_position = (tw["entry"] as Vector3) + Vector3(0, 1.2, 0)
	_route = [
		{"t": "goto", "p": tw["inside"], "shot": "02_inside_tower"},                      # walk through the door onto the 6 m floor
		{"t": "spiral", "c": _tc, "r": 3.4, "top": _b + 11.7, "shot": "03_spiral_top"},   # wind up 6 -> 12
		{"t": "goto", "p": tw["roof"], "shot": "04_tower_roof"},
	]
	_log.append("spawn %.1f,%.1f,%.1f base=%.1f tower=%.1f,%.1f stairFoot=%.1f,%.1f segs=%d" % [_player.global_position.x, _player.global_position.y, _player.global_position.z, _b, _tc.x, _tc.z, sfoot.x, sfoot.z, _route.size()])

func _physics_process(delta: float) -> void:
	if not _active:
		return
	_t += delta; _wp_t += delta
	var p := _player.global_position
	_ymax = maxf(_ymax, p.y)
	if _t - _last_log_t > 0.4:
		_last_log_t = _t
		var rt := Vector2(p.x - _tc.x, p.z - _tc.z).length()
		_log.append("t=%.1f seg=%d pos=%.1f,%.1f,%.1f h=%.1f rTower=%.1f floor=%s" % [_t, _wi, p.x, p.y, p.z, p.y - _b, rt, str(_player.is_on_floor())])
	if _wi >= _route.size():
		_shoot("05_final")
		return _finish("REACHED END OF ROUTE")
	var seg: Dictionary = _route[_wi]
	var dir := Vector3.ZERO
	var advance := false
	if seg["t"] == "goto":
		var to: Vector3 = (seg["p"] as Vector3) - p; to.y = 0
		if to.length() < 1.3:
			advance = true
		else:
			dir = to.normalized()
	elif seg["t"] == "spiral":
		var rel: Vector3 = p - (seg["c"] as Vector3); rel.y = 0
		var r: float = rel.length()
		var ang: float = atan2(rel.z, rel.x)
		var tang := Vector3(-sin(ang), 0, cos(ang))                      # counterclockwise = ascending
		var radial := Vector3(cos(ang), 0, sin(ang))
		var r_err: float = float(seg["r"]) - r
		dir = (tang + radial * clampf(r_err * 0.8, -0.7, 0.7)).normalized()
		if p.y >= float(seg["top"]):
			advance = true
	if advance:
		if seg.has("shot"):
			_shoot(seg["shot"])
		_wi += 1; _wp_t = 0.0
		return
	_player.velocity.x = dir.x * SPEED
	_player.velocity.z = dir.z * SPEED
	if _player.is_on_floor():
		if _player.velocity.y < 0.0:
			_player.velocity.y = 0.0
	else:
		_player.velocity.y -= GRAV * delta
	var pre := _player.global_position
	_player.move_and_slide()
	var moved := _player.global_position - pre; moved.y = 0.0
	if moved.length() < SPEED * delta * 0.5:                             # blocked -> stair step-up
		var up_t := _player.global_transform
		up_t.origin += Vector3.UP * STEP
		if not _player.test_move(up_t, dir * 0.5):
			_player.global_position += Vector3.UP * STEP + dir * 0.45
	_update_cam()
	if _wp_t > 12.0:
		_shoot("stuck_seg_%d" % _wi)
		_finish("STUCK in seg %d (%s) h=%.1f (fell-through=%s)" % [_wi, seg["t"], _player.global_position.y - _b, str(_player.global_position.y < _b - 3.0)])

func _update_cam() -> void:
	# fixed vantage in the courtyard, elevated, looking at the tower's courtyard face,
	# so every shot shows the orange capsule against the tower + door.
	var inw := (Vector3(330, _tc.y, 500) - _tc).normalized()
	_cam.global_position = _tc + inw * 24.0 + Vector3(0, 12.0, 0)
	_cam.look_at(_player.global_position + Vector3(0, 1.0, 0), Vector3.UP)

func _shoot(name: String) -> void:
	_update_cam()
	for _i in 3:
		await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("%s/pt_%s.png" % [OUT, name])
	_log.append("SHOT %s at h=%.1f" % [name, _player.global_position.y - _b])

func _finish(msg: String) -> void:
	_active = false
	_log.append("RESULT: %s" % msg)
	_log.append("MAX HEIGHT above base: %.2f m (tower roof = 12 m)" % (_ymax - _b))
	print("\n===== PLAYER TEST =====")
	for line in _log:
		print(line)
	print("===== END =====\n")
	await _shoot("06_end")
	get_tree().quit()
