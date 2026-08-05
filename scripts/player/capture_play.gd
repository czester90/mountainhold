extends Node3D

const OUT := "res://screenshots/play"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var scene: Node = load("res://scenes/play.tscn").instantiate()
	add_child(scene)
	var player: Node = scene.get_node("Player")
	for _i in 140:
		await get_tree().process_frame
	await _shot("01_idle")
	player.call("_begin_draw")
	for _i in 30:
		await get_tree().process_frame
	await _shot("02_draw")
	for _i in 70:
		await get_tree().process_frame
	await _shot("03_held")
	print("PLAY CAPTURE DONE")
	get_tree().quit()

func _shot(name: String) -> void:
	for _i in 4:
		await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT, name])
	print("SHOT ", name)
