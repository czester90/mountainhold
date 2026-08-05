extends Node3D

## Render ONLY the author's assembled "Demo" group (well framed + lit) so we can
## read exactly how the kit is meant to build a tower + gatehouse.

const AUTH := "res://assets/LoafbrrAssets/CastleWallKit/scenes/CastleWallsKit.tscn"
const OUT := "res://screenshots/author_ref"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var scene: Node = load(AUTH).instantiate()
	add_child(scene)
	# hide every top-level group except Demo
	for c in scene.get_children():
		if c is Node3D and String(c.name) != "Demo":
			(c as Node3D).visible = false
	var demo := scene.get_node("Demo") as Node3D

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -120, 0); sun.light_energy = 1.2; sun.shadow_enabled = true
	add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new(); sky.sky_material = ProceduralSkyMaterial.new(); env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; env.ambient_light_energy = 0.7
	we.environment = env; add_child(we)

	var cam := Camera3D.new(); cam.fov = 60; cam.far = 5000.0; add_child(cam); cam.current = true
	for _i in 30: await RenderingServer.frame_post_draw

	# hide the big ground plane so it doesn't dominate the AABB
	var ground := demo.get_node_or_null("MeshInstance3D")
	if ground: (ground as Node3D).visible = false
	# AABB of the assembled walls only
	var aabb := _aabb(demo.get_node("Walls2"))
	var c := aabb.get_center()
	var r: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	print("DEMO center=", c, " size=", aabb.size)
	var shots := [
		{"n":"demo_A","pos":c + Vector3(r, r * 0.7, r)},
		{"n":"demo_B","pos":c + Vector3(-r, r * 0.6, r * 0.9)},
		{"n":"demo_C","pos":c + Vector3(r * 0.9, r * 0.5, -r)},
		{"n":"demo_top","pos":c + Vector3(0.1, r * 1.6, 0.1)},
	]
	for s in shots:
		cam.global_position = s["pos"]; cam.look_at(c, Vector3.UP)
		for _i in 6: await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		print("cap %s err=%d" % [s["n"], img.save_png("%s/%s.png" % [OUT, s["n"]])])
	get_tree().quit()

func _aabb(n: Node) -> AABB:
	var box := AABB()
	var have := false
	var stack: Array = [n]
	while not stack.is_empty():
		var m = stack.pop_back()
		if m is VisualInstance3D:
			var b: AABB = (m as VisualInstance3D).get_aabb()
			b = (m as Node3D).global_transform * b
			if not have: box = b; have = true
			else: box = box.merge(b)
		for ch in m.get_children(): stack.append(ch)
	return box
