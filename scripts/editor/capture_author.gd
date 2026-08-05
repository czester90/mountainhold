extends Node3D
const OUT := "res://screenshots/author_ref"
var _cam: Camera3D
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var s: Node = load("res://Assets/LoafbrrAssets/CastleWallKit/scenes/CastleWallsKit.tscn").instantiate()
	add_child(s)
	for c in _all(s):
		if c is Camera3D: c.current = false
	# strong light + bright ambient so nothing renders black
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(35), 0)
	sun.light_energy = 1.3
	add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.65, 0.72)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.76)
	env.ambient_light_energy = 0.7
	we.environment = env
	add_child(we)
	_cam = Camera3D.new(); _cam.far = 4000.0; add_child(_cam); _cam.current = true
	for _i in 30: await RenderingServer.frame_post_draw
	var shots := [
		{"n":"01_all","pos":Vector3(30,150,150),"tgt":Vector3(25,8,-10)},
		{"n":"02_demo","pos":Vector3(25,50,50),"tgt":Vector3(20,10,-35)},
		{"n":"03_walls_group","pos":Vector3(60,45,95),"tgt":Vector3(55,10,20)},
	]
	for sh in shots:
		_cam.global_position=sh["pos"]; _cam.look_at(sh["tgt"],Vector3.UP)
		for _i in 6: await RenderingServer.frame_post_draw
		print("cap %s err=%d" % [sh["n"], get_viewport().get_texture().get_image().save_png("%s/auth_%s.png" % [OUT, sh["n"]])])
	get_tree().quit()
func _all(n: Node) -> Array:
	var r := [n]
	for c in n.get_children(): r += _all(c)
	return r
