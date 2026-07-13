extends Node3D

## Validation helper (not gameplay). Instances the MCSTEEG asset catalog,
## overrides its orbit camera with a scripted capture camera, writes review
## PNGs to res://screenshots/stage_01/, then quits.

const OUT_DIR: String = "res://screenshots/stage_01"
const CATALOG_SCENE: String = "res://scenes/catalog/mcsteeg_asset_catalog.tscn"

const SHOTS: Array = [
	{"name": "stage_01_catalog_overview", "pos": Vector3(0.0, 24.0, 42.0), "target": Vector3(0.0, 0.0, 12.0)},
	{"name": "stage_01_catalog_overview_angled", "pos": Vector3(26.0, 18.0, 36.0), "target": Vector3(-2.0, 1.0, 12.0)},
	{"name": "stage_01_catalog_front_rows", "pos": Vector3(0.0, 5.5, 26.0), "target": Vector3(0.0, 1.6, 7.0)},
	{"name": "stage_01_scale_reference", "pos": Vector3(-15.5, 3.2, 9.0), "target": Vector3(-15.0, 1.0, 0.5)},
	{"name": "stage_01_detail_pieces", "pos": Vector3(-7.0, 4.0, 17.5), "target": Vector3(-4.5, 1.4, 11.0)},
]

var _camera: Camera3D

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var catalog: Node = load(CATALOG_SCENE).instantiate()
	add_child(catalog)
	var orbit_cam: Camera3D = catalog.get_node("CameraPivot/Camera")
	orbit_cam.current = false
	_camera = Camera3D.new()
	_camera.fov = 62.0
	add_child(_camera)
	_camera.current = true
	await _capture_all()

func _capture_all() -> void:
	for shot in SHOTS:
		_camera.global_position = shot["pos"]
		_camera.look_at(shot["target"], Vector3.UP)
		for _i in 4:
			await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		var path: String = "%s/%s.png" % [OUT_DIR, shot["name"]]
		var err: int = image.save_png(path)
		print("capture %s -> %s (err=%d)" % [shot["name"], path, err])
	get_tree().quit()
