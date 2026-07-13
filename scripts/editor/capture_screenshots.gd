extends Node3D

## Validation helper (not gameplay). Instances the Stage 00 startup scene,
## drives a dedicated camera through the required review angles, writes PNGs
## to res://screenshots/stage_00/, then quits.
## Run with:  godot --path <project> res://scenes/test/stage_00_capture.tscn

const OUT_DIR: String = "res://screenshots/stage_00"
const STARTUP_SCENE: String = "res://scenes/test/project_startup_test.tscn"

const SHOTS: Array = [
	{"name": "stage_00_front_overview", "pos": Vector3(0.0, 3.0, 12.0), "target": Vector3(0.0, 1.0, 0.0)},
	{"name": "stage_00_elevated_overview", "pos": Vector3(11.0, 10.0, 15.0), "target": Vector3(0.0, 0.6, 0.0)},
	{"name": "stage_00_ground_approach", "pos": Vector3(0.0, 1.65, 8.0), "target": Vector3(0.0, 1.1, 0.0)},
	{"name": "stage_00_scale_reference", "pos": Vector3(2.4, 1.3, 4.2), "target": Vector3(0.0, 0.9, 0.0)},
]

var _camera: Camera3D

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var startup: Node = load(STARTUP_SCENE).instantiate()
	add_child(startup)
	var scene_cam: Camera3D = startup.get_node("Camera")
	scene_cam.current = false
	_camera = Camera3D.new()
	_camera.fov = 60.0
	add_child(_camera)
	_camera.current = true
	await _capture_all()

func _capture_all() -> void:
	for shot in SHOTS:
		_camera.global_position = shot["pos"]
		_camera.look_at(shot["target"], Vector3.UP)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		var path: String = "%s/%s.png" % [OUT_DIR, shot["name"]]
		var err: int = image.save_png(path)
		print("capture %s -> %s (err=%d)" % [shot["name"], path, err])
	get_tree().quit()
