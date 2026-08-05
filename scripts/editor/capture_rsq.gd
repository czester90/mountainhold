extends Node3D
const OUT := "res://screenshots/rsq_test"
var _cam: Camera3D
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	add_child(load("res://scenes/test/rsq_test.tscn").instantiate())
	_cam = Camera3D.new(); add_child(_cam); _cam.current = true
	for _i in 20: await RenderingServer.frame_post_draw
	for sh in [{"n":"top","pos":Vector3(12,55,12),"tgt":Vector3(12,0,12)},{"n":"obl","pos":Vector3(-8,14,-10),"tgt":Vector3(6,3,3)}]:
		_cam.global_position=sh["pos"]; _cam.look_at(sh["tgt"], (Vector3(0,0,-1) if sh["n"]=="top" else Vector3.UP))
		for _i in 5: await RenderingServer.frame_post_draw
		print("cap %s err=%d"%[sh["n"], get_viewport().get_texture().get_image().save_png("%s/rsq_%s.png"%[OUT,sh["n"]])])
	get_tree().quit()
