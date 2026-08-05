extends Node3D

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://screenshots/bow")
	var bow: Node3D = load("res://assets/raw/bow/scene.gltf").instantiate()
	add_child(bow)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.3, 0.35, 0.4)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.8)
	e.ambient_light_energy = 1.0
	env.environment = e
	add_child(env)
	var cam := Camera3D.new()
	cam.fov = 60.0
	add_child(cam)
	cam.current = true
	for _i in 30:
		await RenderingServer.frame_post_draw
	var shots := {
		"front": Vector3(0, 0.2, 1.2),   # looking -Z
		"side": Vector3(1.2, 0.2, 0.1),
		"top": Vector3(0.01, 1.5, 0.2),
		"back": Vector3(0, 0.2, -1.2),
	}
	for n in shots:
		cam.global_position = shots[n]
		cam.look_at(Vector3(0, 0.1, 0), Vector3.UP)
		for _j in 4:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://screenshots/bow/%s.png" % n)
		print("SHOT ", n)
	print("BOW INSPECT DONE")
	get_tree().quit()
