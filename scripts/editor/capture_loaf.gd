extends Node3D

const OUT_DIR := "res://screenshots/loafbrr_catalog"
const SCENE := "res://scenes/catalog/loafbrr_catalog.tscn"

var _cam: Camera3D

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var scene: Node = load(SCENE).instantiate()
	add_child(scene)
	scene.get_node("CameraPivot/Camera").current = false
	_cam = Camera3D.new()
	_cam.fov = 60.0
	_cam.far = 4000.0
	add_child(_cam)
	_cam.current = true
	for _i in 30:
		await RenderingServer.frame_post_draw
	await _shoot()

func _shoot() -> void:
	var shots := [
		{"n": "01_overview", "pos": Vector3(0, 78, 135), "tgt": Vector3(0, 0, 52)},
		{"n": "02_overview_angled", "pos": Vector3(64, 58, 120), "tgt": Vector3(-8, 2, 50)},
		{"n": "03_detail_front", "pos": Vector3(-8, 9, 6), "tgt": Vector3(-8, 3.5, 28)},
		{"n": "04_detail_mid", "pos": Vector3(-24, 8, 44), "tgt": Vector3(-8, 3.5, 58)},
	]
	for s in shots:
		_cam.global_position = s["pos"]
		_cam.look_at(s["tgt"], Vector3.UP)
		for _i in 6:
			await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		print("capture %s -> err=%d" % [s["n"], img.save_png("%s/loaf_%s.png" % [OUT_DIR, s["n"]])])
	get_tree().quit()
