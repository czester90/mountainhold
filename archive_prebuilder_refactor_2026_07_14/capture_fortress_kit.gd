extends Node3D

const OUT_DIR := "res://screenshots/fortress_kit"
const SCENE := "res://scenes/test/fortress_kit_test.tscn"

var _cam: Camera3D
var _terrain: Node

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var scene: Node = load(SCENE).instantiate()
	add_child(scene)
	scene.get_node("FlyCamera").current = false
	_terrain = scene.get_node("Terrain")
	_cam = Camera3D.new()
	_cam.fov = 65.0
	_cam.far = 4000.0
	add_child(_cam)
	_cam.current = true
	_terrain.call("set_camera", _cam)
	for _i in 40:
		await RenderingServer.frame_post_draw
	await _shoot()

func _h(x: float, z: float) -> float:
	var v: float = _terrain.get("data").get_height(Vector3(x, 0.0, z))
	return 0.0 if is_nan(v) else v

func _shoot() -> void:
	var cx := 330.0
	var cz := 500.0
	var b := _h(cx - 12.0, cz)          # plateau base elevation after flatten
	var wall_r := 44.0
	var open_half := 1.35
	# tower_angle(1) matches the builder (RUNS=5, OPEN_HALF)
	var a_t1: float = lerp(PI - open_half, PI + open_half, 1.0 / 5.0)
	var wr := wall_r - (2.6 * 0.5 + 1.3)
	var walk_t := Vector3(cx + wr * cos(a_t1), b + 6.0, cz + wr * sin(a_t1))
	# tower centre (projected outward WALL_R+2), roof at b+12
	var tc := Vector3(cx + (wall_r + 2.0) * cos(a_t1), b, cz + (wall_r + 2.0) * sin(a_t1))
	var inw_t := Vector3(cx - tc.x, 0, cz - tc.z).normalized()   # tower -> courtyard
	# the two tower doors face tangentially (radial +/- 90 deg), toward each wall neighbour
	var radial_ang := atan2(tc.z - cz, tc.x - cx)
	var da := radial_ang + PI * 0.5
	var db := radial_ang - PI * 0.5
	var da_dir := Vector3(cos(da), 0, sin(da))
	var db_dir := Vector3(cos(db), 0, sin(db))
	# keep centre = gate-run midpoint on the apex (west), interior floor b+6, roof b+18
	var kc := Vector3(cx - wall_r, b, cz)
	var shots := [
		{"n": "01_top_down", "pos": Vector3(cx - 20, b + 130, cz), "tgt": Vector3(cx - 20, 0, cz)},
		{"n": "02_hero_field", "pos": Vector3(cx - 86, b + 42, cz + 60), "tgt": Vector3(cx - 22, b + 6, cz)},
		{"n": "03_courtyard", "pos": Vector3(cx + 26, b + 7, cz + 8), "tgt": Vector3(cx - wall_r, b + 8, cz)},
		# --- tower, exterior all sides ---
		{"n": "04_tower_field", "pos": tc - inw_t * 22 + Vector3(0, 6, 0), "tgt": tc + Vector3(0, 8, 0)},
		{"n": "05_tower_doorA", "pos": tc + da_dir * 16 + Vector3(0, 8, 0), "tgt": tc + Vector3(0, 8, 0)},
		{"n": "06_tower_doorB", "pos": tc + db_dir * 16 + Vector3(0, 8, 0), "tgt": tc + Vector3(0, 8, 0)},
		{"n": "07_tower_top", "pos": tc + Vector3(0.1, 24, 0.1), "tgt": tc},
		# --- tower, interior: stand on the 6 m floor, look at each door ---
		{"n": "08_tower_in_doorA", "pos": tc + Vector3(0, 7.6, 0), "tgt": tc + da_dir * 6 + Vector3(0, 7.6, 0)},
		{"n": "09_tower_in_doorB", "pos": tc + Vector3(0, 7.6, 0), "tgt": tc + db_dir * 6 + Vector3(0, 7.6, 0)},
		# --- keep ---
		{"n": "10_keep_field", "pos": Vector3(cx - wall_r - 30, b + 10, cz), "tgt": Vector3(cx - wall_r + 6, b + 10, cz)},
		{"n": "11_keep_in_stair", "pos": kc + Vector3(-7, 7.6, 4.5), "tgt": kc + Vector3(5, 14, -4)},
		{"n": "12_keep_in_front", "pos": kc + Vector3(0, 9.0, 4.5), "tgt": kc + Vector3(0, 10, -6)},
		{"n": "13_keep_top", "pos": kc + Vector3(2, 40, 0.1), "tgt": kc + Vector3(2, 18, 0)},
		# --- route / walk ---
		{"n": "14_walk_at_tower", "pos": walk_t + Vector3(0, 1.7, 7), "tgt": tc + Vector3(0, 8, 0)},
	]
	for s in shots:
		_cam.global_position = s["pos"]
		_cam.look_at(s["tgt"], Vector3.UP)
		for _i in 6:
			await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		print("capture %s -> err=%d" % [s["n"], img.save_png("%s/fortress_%s.png" % [OUT_DIR, s["n"]])])
	get_tree().quit()
