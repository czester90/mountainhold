extends Node3D

## Lineup of the enemy kinds (infantry spearman, archer, battering ram) + a friendly archer, on a
## flat floor, shot OFF-SCREEN + NO_FOCUS so it never steals the mouse. -> screenshots/qa2/soldiers.png

func _ready() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	get_window().position = Vector2i(-4000, -4000)
	get_window().size = Vector2i(1100, 520)
	DirAccess.make_dir_recursive_absolute("res://screenshots/qa2")
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.5, 0.55, 0.62)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.7)
	e.ambient_light_energy = 1.0
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, -0.6, 0)
	add_child(sun)
	# flat floor (world layer 1) so the bodies settle
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(40, 1, 40)
	cs.shape = bs
	floor_body.add_child(cs)
	floor_body.position = Vector3(0, -0.5, 0)
	add_child(floor_body)
	var lineup := [["infantry", -5.0], ["archer", -2.0], ["ram", 2.0]]
	for item in lineup:
		var en = load("res://scenes/enemy/enemy_%s.tscn" % item[0]).instantiate()
		add_child(en)
		en.global_position = Vector3(item[1], 0.2, 0)
		en.rotation.y = PI
	var ally = load("res://scenes/ally/ally_archer.tscn").instantiate()
	add_child(ally)
	ally.global_position = Vector3(5.5, 0.2, 0)
	ally.rotation.y = PI
	var cam := Camera3D.new()
	cam.fov = 50
	add_child(cam)
	cam.global_position = Vector3(0, 2.2, 9.0)
	cam.look_at(Vector3(0, 1.1, 0), Vector3.UP)
	cam.current = true
	for _i in 30: await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	for _w in 3: await get_tree().process_frame
	var tex := get_viewport().get_texture()
	if tex:
		tex.get_image().save_png("res://screenshots/qa2/soldiers.png")
		print("SHOT soldiers")
	get_tree().quit()
