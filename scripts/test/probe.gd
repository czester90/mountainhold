extends Node3D

## Prints real world positions of key structures so the mechanics test can be calibrated after
## geometry changes. Also samples the walk surface via raycasts.

func _ready() -> void:
	var scene = load("res://scenes/play.tscn").instantiate()
	add_child(scene)
	for _i in 60: await get_tree().process_frame
	await get_tree().create_timer(3.0).timeout
	var fort: Node = scene.get_node("Fortress")
	# find the GateTower + Gatehouse instances
	for child in _all(fort):
		var s = child.get_script()
		if s and (s.resource_path.ends_with("gate_tower.gd") or s.resource_path.ends_with("gatehouse.gd")):
			var e = child.global_transform * child.call("snap", "WallWalkEntry").transform.origin
			var x = child.global_transform * child.call("snap", "WallWalkExit").transform.origin
			print("%s @ %.1f,%.1f,%.1f  entry=%.1f,%.1f,%.1f  exit=%.1f,%.1f,%.1f" % [s.resource_path.get_file(), child.global_position.x, child.global_position.y, child.global_position.z, e.x, e.y, e.z, x.x, x.y, x.z])
	var space := get_world_3d().direct_space_state
	# FIELD-FACE profile: shoot +X rays from the field (x255) at base height; first hit = the west
	# (field) face. Compare gate (z~500) vs flanking curtain (z 490/492/508/510) to measure protrusion.
	print("--- FIELD FACE X (ray +X @ y18) ---")
	for zc in [488, 490, 492, 494, 496, 498, 500, 502, 504, 506, 508, 510, 512]:
		var qf := PhysicsRayQueryParameters3D.create(Vector3(255, 18, zc), Vector3(320, 18, zc))
		qf.collision_mask = 1
		var hf := space.intersect_ray(qf)
		print("  z%d -> %s" % [zc, ("x=%.2f" % hf.position.x) if hf else "MISS"])
	# causeway -> inner-gate height profile at z500 (enemy stalls ~x339.8): look for a step > 0.6 m
	print("--- INNER TOWER (south ~345,487) + pad heights (topmost from y60) ---")
	for zc in [487, 490, 493, 496, 500]:
		var row := "z%d: " % zc
		for xc in [340, 343, 345, 347, 350]:
			var qc := PhysicsRayQueryParameters3D.create(Vector3(xc, 60, zc), Vector3(xc, -30, zc))
			qc.collision_mask = 1
			var hc := space.intersect_ray(qc)
			row += ("%d=%.1f " % [xc, hc.position.y]) if hc else ("%d=-- " % xc)
		print(row)
	# inner tower ground entry: interior stair heights (topmost from y44) should climb pad(26)->roof(38)
	print("--- INNER TOWER interior stair (from y44) ---")
	for zc in [482, 484, 486, 488, 490, 492]:
		var row := "z%d: " % zc
		for xc in [342, 344, 345, 346, 348]:
			var qc := PhysicsRayQueryParameters3D.create(Vector3(xc, 44, zc), Vector3(xc, -30, zc))
			qc.collision_mask = 1
			var hc := space.intersect_ray(qc)
			row += ("%d=%.0f " % [xc, hc.position.y]) if hc else ("%d=- " % xc)
		print(row)
	# +Z ground door open? horizontal ray from the bailey (z498) into the tower at pad height y28
	print("--- +Z DOOR (ray -Z @ y28, x345) ---")
	var qd := PhysicsRayQueryParameters3D.create(Vector3(345, 28, 499), Vector3(345, 28, 483))
	qd.collision_mask = 1
	var hd2 := space.intersect_ray(qd)
	print("  first hit z = %s (door open if ~493 is passable / hits deep)" % [("%.1f" % hd2.position.z) if hd2 else "NONE (clear through)"])
	# EXIT-side (south) walk continuity: floor height just below the roof, across the exit junction
	print("--- SOUTH walk junction (floor from y26) ---")
	for zc in range(484, 497, 1):
		var row := "z%d: " % zc
		for xc in [286, 287, 288, 289, 290, 291]:
			var qw := PhysicsRayQueryParameters3D.create(Vector3(xc, 26, zc), Vector3(xc, -20, zc))
			qw.collision_mask = 1
			var hw := space.intersect_ray(qw)
			row += ("%d=%.1f " % [xc, hw.position.y]) if hw else ("%d=-- " % xc)
		print(row)
	# gallery floor scan (walk level ~21): topmost hit from y31 across the whole gate footprint
	print("--- gate GALLERY floor (from y31) ---")
	for zc in range(496, 506, 1):
		var row := "z%d: " % zc
		for xc in range(280, 296, 1):
			var qg := PhysicsRayQueryParameters3D.create(Vector3(xc, 31, zc), Vector3(xc, -30, zc))
			qg.collision_mask = 1
			var hitg := space.intersect_ray(qg)
			row += ("%d=%.1f " % [xc, hitg.position.y]) if hitg else ("%d=-- " % xc)
		print(row)
	# roof + stair scan: topmost hit from high above (roof deck ~27, stair treads 21..27)
	print("--- gate ROOF/STAIR (from y40) ---")
	for zc in range(496, 506, 1):
		var row := "z%d: " % zc
		for xc in range(280, 296, 1):
			var q2 := PhysicsRayQueryParameters3D.create(Vector3(xc, 40, zc), Vector3(xc, -30, zc))
			q2.collision_mask = 1
			var r2 := space.intersect_ray(q2)
			row += ("%d=%.1f " % [xc, r2.position.y]) if r2 else ("%d=-- " % xc)
		print(row)
	# keep interior: roof (ray from high) + first floor / stairs (ray from just under the roof)
	print("--- keep roof (from y70) ---")
	for zc in [497, 500, 503]:
		var row := "z%d: " % zc
		for xc in range(354, 367, 2):
			var qk := PhysicsRayQueryParameters3D.create(Vector3(xc, 70, zc), Vector3(xc, -80, zc))
			qk.collision_mask = 1
			var rk := space.intersect_ray(qk)
			row += ("x%d=%.1f " % [xc, rk.position.y]) if rk else ("x%d=-- " % xc)
		print(row)
	print("--- keep access stair (0->6, from y33) ---")
	for zc in range(503, 510, 1):
		var row := "z%d: " % zc
		for xc in range(354, 366, 1):
			var qk := PhysicsRayQueryParameters3D.create(Vector3(xc, 33, zc), Vector3(xc, -80, zc))
			qk.collision_mask = 1
			var rk := space.intersect_ray(qk)
			row += ("x%d=%.0f " % [xc, rk.position.y]) if rk else ("x%d=- " % xc)
		print(row)
	# ally count
	var allies := 0
	for c in _all(scene):
		if c.is_in_group("ally") or (c.get_script() and c.get_script().resource_path.ends_with("ally_archer.gd")): allies += 1
	print("allies=%d" % allies)
	get_tree().quit()

func _all(n: Node) -> Array:
	var out := [n]
	for c in n.get_children(): out += _all(c)
	return out
