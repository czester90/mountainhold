extends Node3D
const OUT := "res://screenshots/drum_test"
var _cam: Camera3D
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	add_child(load("res://scenes/test/drum_test.tscn").instantiate())
	_cam = Camera3D.new(); add_child(_cam); _cam.current = true
	for _i in 20: await RenderingServer.frame_post_draw
	_cam.global_position = Vector3(20,50,12); _cam.look_at(Vector3(20,0,10), Vector3(0,0,-1))
	for _i in 5: await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	print("cap err=%d" % img.save_png("%s/drum_top.png" % OUT))
	get_tree().quit()
