extends Node3D

## Loads play.tscn (forced unpaused, off-screen, no-focus), lets waves reach the gate, then reports
## every live enemy (kind, pos, waypoint, attacking, visible-mesh) AND screenshots the field from
## behind the gate — to diagnose "invisible" besiegers hammering the gate.

func _ready() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	get_window().position = Vector2i(-4000, -4000)
	get_window().size = Vector2i(960, 540)
	DirAccess.make_dir_recursive_absolute("res://screenshots/sweep")
	var scene = load("res://scenes/play.tscn").instantiate()
	add_child(scene)
	for _i in 60: await get_tree().process_frame
	var announced := false
	for _s in 50:
		get_tree().paused = false
		await get_tree().create_timer(0.4).timeout
		var es: Array = []
		_collect_enemies(get_tree().root, es)
		var low: Node = null
		for e in es:
			if low == null or e.global_position.y < low.global_position.y:
				low = e
		if low != null and low.global_position.y < 13.0 and not announced:
			announced = true
			var lp: Vector3 = low.global_position
			print(">>> FIRST FALLER %s at %.1f,%.1f,%.1f  (vy=%.1f)" % [low.get_script().resource_path.get_file(), lp.x, lp.y, lp.z, low.velocity.y])
			# keep printing its descent
			for _k in 8:
				await get_tree().create_timer(0.2).timeout
				if is_instance_valid(low):
					print("    -> %.1f,%.1f,%.1f" % [low.global_position.x, low.global_position.y, low.global_position.z])
			break
	var all_enemies: Array = []
	_collect_enemies(get_tree().root, all_enemies)
	var grouped := get_tree().get_nodes_in_group("enemy")
	print("--- ENEMY REPORT: %d Enemy nodes, %d in group 'enemy' ---" % [all_enemies.size(), grouped.size()])
	for e in all_enemies:
		var p: Vector3 = e.global_position
		print("  %s pos=%.1f,%.1f,%.1f ingroup=%s vis=%s hp=%.0f atk=%s" % [e.get_script().resource_path.get_file(), p.x, p.y, p.z, str(e.is_in_group("enemy")), str(_any_visible(e)), float(e.get("hp")) if e.get("hp") != null else -1.0, str(e.get("_attacking"))])
	var sp = scene.get_node_or_null("WaveSpawner")
	if sp:
		print("gate_hp=%.0f keep_hp=%.0f alive=%d wave=%d" % [sp.call("gate_hp"), sp.call("keep_hp"), sp.call("alive_count"), sp.call("wave")])
	var cam := Camera3D.new()
	cam.fov = 62
	cam.far = 4000
	add_child(cam)
	cam.current = true
	cam.global_position = Vector3(250, 19, 500)         # field side, looking east at the gate
	cam.look_at(Vector3(287, 17, 500), Vector3.UP)
	get_tree().paused = false
	for _w in 4: await get_tree().process_frame
	var tex := get_viewport().get_texture()
	if tex:
		tex.get_image().save_png("res://screenshots/sweep/assault.png")
		print("SHOT assault")
	get_tree().quit()

func _collect_enemies(n: Node, out: Array) -> void:
	var s = n.get_script()
	if s != null and s.resource_path.ends_with("_enemy.gd"):   # infantry/archer/ram_enemy.gd (avoid class_name refs)
		out.append(n)
	for c in n.get_children():
		_collect_enemies(c, out)

func _any_visible(n: Node) -> bool:
	if n is MeshInstance3D and (n as MeshInstance3D).visible:
		return true
	for c in n.get_children():
		if _any_visible(c):
			return true
	return false
