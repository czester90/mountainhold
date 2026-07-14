extends Node3D
const OUT := "res://screenshots/kit_assembly"
var _cam: Camera3D
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var s: Node = load("res://scenes/test/kit_assembly_test.tscn").instantiate()
	add_child(s)
	s.get_node("Camera").current = false
	_cam = Camera3D.new(); _cam.far = 2000.0; add_child(_cam); _cam.current = true
	for _i in 20: await RenderingServer.frame_post_draw
	var shots := [
		{"n":"01_overview","pos":Vector3(-6,16,26),"tgt":Vector3(16,4,-3)},
		{"n":"02_tower","pos":Vector3(30,10,20),"tgt":Vector3(30,7,-3)},
		{"n":"03_wall_stairs","pos":Vector3(2,7,18),"tgt":Vector3(9,4,-4)},
	]
	for sh in shots:
		_cam.global_position = sh["pos"]; _cam.look_at(sh["tgt"], Vector3.UP)
		for _i in 5: await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		print("cap %s err=%d" % [sh["n"], img.save_png("%s/asm_%s.png" % [OUT, sh["n"]])])
	get_tree().quit()
