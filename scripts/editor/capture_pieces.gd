extends Node3D
const OUT := "res://screenshots/piece_inspect"
var _cam: Camera3D
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var s: Node = load("res://scenes/test/piece_inspect.tscn").instantiate()
	add_child(s)
	s.get_node("Camera").current = false
	_cam = Camera3D.new(); add_child(_cam); _cam.current = true
	for _i in 25: await RenderingServer.frame_post_draw
	var shots := [
		{"n":"top","pos":Vector3(20,55,10),"tgt":Vector3(20,0,10)},
		{"n":"oblique","pos":Vector3(-6,18,34),"tgt":Vector3(20,3,8)},
	]
	for sh in shots:
		_cam.global_position=sh["pos"]; _cam.look_at(sh["tgt"],Vector3.UP)
		for _i in 5: await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		print("cap %s err=%d" % [sh["n"], img.save_png("%s/pi_%s.png" % [OUT, sh["n"]])])
	get_tree().quit()
