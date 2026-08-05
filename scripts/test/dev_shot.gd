extends Node3D
func _ready() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	get_window().position = Vector2i(-4000, -4000)
	DirAccess.make_dir_recursive_absolute("res://screenshots/qa2")
	var scene = load("res://scenes/play.tscn").instantiate()
	add_child(scene)
	for _i in 60: await get_tree().process_frame
	await get_tree().create_timer(5.0).timeout        # build + a wave under way
	scene.get_node("DeveloperPanel").set("_shown", true)
	for _w in 20: await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	for _w in 3: await get_tree().process_frame
	var tex := get_viewport().get_texture()
	if tex: tex.get_image().save_png("res://screenshots/qa2/dev_panel.png"); print("SHOT dev_panel")
	get_tree().quit()
