extends Node3D

const OUT_DIR := "res://screenshots/fortress_structure"
const SCENE := "res://scenes/test/fortress_structure_test.tscn"

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
	var r := 42.0
	var b := _h(cx - 12.0, cz)          # plateau base elevation after flatten
	var shots := [
		{"n": "01_hero_aerial", "pos": Vector3(cx - 78, b + 48, cz + 78), "tgt": Vector3(cx, b + 3, cz)},
		{"n": "02_front_gate", "pos": Vector3(cx - r - 24, b + 2.0, cz), "tgt": Vector3(cx - r + 6, b + 4, cz)},
		{"n": "03_wall_side", "pos": Vector3(cx - 8, b + 20, cz + 74), "tgt": Vector3(cx - 22, b + 4, cz + 6)},
		{"n": "04_courtyard", "pos": Vector3(cx + 20, b + 2.5, cz), "tgt": Vector3(cx - r, b + 5, cz)},
		{"n": "05_tower", "pos": Vector3(cx - 26, b + 9, cz + 40), "tgt": Vector3(cx, b + 6, cz + r)},
		{"n": "06_scale", "pos": Vector3(cx - r - 9, b + 2.0, cz + 4), "tgt": Vector3(cx - r - 4, b + 0.9, cz)},
		{"n": "07_top_down", "pos": Vector3(cx, b + 150, cz), "tgt": Vector3(cx, 0, cz)},
		{"n": "08_battlement_close", "pos": Vector3(cx - 16, b + 8.5, cz + 20), "tgt": Vector3(cx - 40, b + 6.0, cz + 16)},
		{"n": "09_tower_close", "pos": Vector3(cx - 20, b + 10, cz + 36), "tgt": Vector3(cx - 39, b + 7.0, cz + 21)},
		{"n": "10_stair_close", "pos": Vector3(cx - 4, b + 3.0, cz + 44), "tgt": Vector3(cx - 29, b + 3.0, cz + 33)},
	]
	for s in shots:
		_cam.global_position = s["pos"]
		_cam.look_at(s["tgt"], Vector3.UP)
		for _i in 6:
			await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		print("capture %s -> err=%d" % [s["n"], img.save_png("%s/fortress_%s.png" % [OUT_DIR, s["n"]])])
	get_tree().quit()
