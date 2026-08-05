extends Node3D
const OUT := "res://screenshots/module_lab"
var _cam: Camera3D

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)

	# ground plane so pieces sit on something readable
	var gp := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(140, 140)
	gp.mesh = pm
	var gmat := StandardMaterial3D.new(); gmat.albedo_color = Color(0.30, 0.29, 0.26)
	gp.material_override = gmat
	gp.position = Vector3(15, 0, -18)
	add_child(gp)

	# lighting: key sun + sky ambient
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -125, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new(); sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)

	var s: Node = load("res://scenes/test/module_lab.tscn").instantiate()
	add_child(s)
	_cam = Camera3D.new(); add_child(_cam); _cam.current = true
	_cam.fov = 60
	for _i in 25: await RenderingServer.frame_post_draw

	var shots := [
		{"n":"01_tower_courtyard","pos":Vector3(24,8,-26),"tgt":Vector3(24,7,-3)},   # look into the open gorge from courtyard
		{"n":"02_tower_field","pos":Vector3(44,10,14),"tgt":Vector3(24,7,-3)},       # closed field side
		{"n":"03_tower_top","pos":Vector3(20,26,-20),"tgt":Vector3(24,10,-4)},       # down into gorge + stair
		{"n":"04_walk_entry","pos":Vector3(2,9,-3),"tgt":Vector3(24,7,-3)},          # wall-walk entering tower
		{"n":"05_donjon_front","pos":Vector3(10,10,-16),"tgt":Vector3(10,9,-40)},    # 4 windows + gate
		{"n":"06_donjon_side","pos":Vector3(-10,8,-40),"tgt":Vector3(10,7,-40)},     # side door (wall entry)
		{"n":"07_overview","pos":Vector3(-14,28,10),"tgt":Vector3(14,6,-24)},
	]
	for sh in shots:
		_cam.global_position = sh["pos"]; _cam.look_at(sh["tgt"], Vector3.UP)
		for _i in 6: await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		print("cap %s err=%d" % [sh["n"], img.save_png("%s/lab_%s.png" % [OUT, sh["n"]])])
	get_tree().quit()
