extends Node3D

## Validation helper. Instances the heightmap audit scene, drives a capture
## camera through the 7 required review angles, writes PNGs, then quits.

const OUT_DIR := "res://screenshots/heightmap_audit"
const SCENE := "res://scenes/test/heightmap_import_test.tscn"

var _cam: Camera3D
var _terrain: Node
var _scene: Node

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var scene: Node = load(SCENE).instantiate()
	add_child(scene)
	scene.get_node("FlyCamera").current = false
	_scene = scene
	_terrain = scene.get_node("Terrain")
	_cam = Camera3D.new()
	_cam.fov = 65.0
	_cam.far = 4000.0
	add_child(_cam)
	_cam.current = true
	_terrain.call("set_camera", _cam)
	# allow the builder's deferred import + overlay build to finish
	for _i in 30:
		await RenderingServer.frame_post_draw
	await _capture_all()

func _h(x: float, z: float) -> float:
	var v: float = _terrain.get("data").get_height(Vector3(x, 0.0, z))
	return 0.0 if is_nan(v) else v

func _capture_all() -> void:
	var shots := [
		{"n": "01_full_overview", "ov": true, "pos": Vector3(150, 420, 900), "tgt": Vector3(460, 40, 500)},
		{"n": "02_top_down", "ov": true, "pos": Vector3(400, 780, 501), "tgt": Vector3(400, 0, 500)},
		{"n": "03_ground_valley", "ov": false, "pos": Vector3(240, _h(240, 500) + 2.0, 500), "tgt": Vector3(470, _h(470, 500) + 60.0, 520)},
		{"n": "04_scale_reference", "ov": false, "pos": Vector3(338, _h(338, 500) + 2.2, 510), "tgt": Vector3(344, _h(344, 500) + 0.9, 500)},
		{"n": "05_proposed_fortress", "ov": true, "pos": Vector3(298, _h(298, 500) + 46.0, 498), "tgt": Vector3(410, _h(410, 500) + 10.0, 508)},
		{"n": "06_proposed_approach", "ov": true, "pos": Vector3(392, _h(392, 500) + 40.0, 500), "tgt": Vector3(280, _h(280, 500) + 2.0, 500)},
		{"n": "07_proposed_crop", "ov": true, "pos": Vector3(400, 560, 860), "tgt": Vector3(400, 20, 470)},
	]
	var overlays: Node = _scene.get_node("Overlays")
	for s in shots:
		overlays.visible = s["ov"]
		_cam.global_position = s["pos"]
		_cam.look_at(s["tgt"], Vector3.UP)
		for _i in 6:
			await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		var path := "%s/heightmap_audit_%s.png" % [OUT_DIR, s["n"]]
		print("capture %s -> err=%d" % [s["n"], img.save_png(path)])
	get_tree().quit()
