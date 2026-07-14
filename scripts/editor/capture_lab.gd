extends Node3D
const OUT := "res://screenshots/module_lab"
var _cam: Camera3D
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var s: Node = load("res://scenes/test/module_lab.tscn").instantiate()
	add_child(s)
	_cam = Camera3D.new(); add_child(_cam); _cam.current = true
	for _i in 25: await RenderingServer.frame_post_draw
	var shots := [
		{"n":"01_junction","pos":Vector3(3,9,-9),"tgt":Vector3(18,6,-2)},
		{"n":"02_walk","pos":Vector3(2,8.5,-2.2),"tgt":Vector3(18,6.5,-2)},
		{"n":"03_stairs","pos":Vector3(1,6,-14),"tgt":Vector3(8,3,-5)},
		{"n":"04_overview","pos":Vector3(-4,12,16),"tgt":Vector3(12,4,-2)},
	]
	for sh in shots:
		_cam.global_position=sh["pos"]; _cam.look_at(sh["tgt"],Vector3.UP)
		for _i in 5: await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		print("cap %s err=%d" % [sh["n"], img.save_png("%s/lab_%s.png" % [OUT, sh["n"]])])
	get_tree().quit()
