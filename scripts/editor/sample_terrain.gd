extends SceneTree
var _t
func _init() -> void:
	_run()
func _run() -> void:
	var scene = load("res://scenes/test/heightmap_import_test.tscn").instantiate()
	get_root().add_child(scene)
	scene.get_node("FlyCamera").set("current", false)
	_t = scene.get_node("Terrain")
	for _i in 20:
		await process_frame
	var data = _t.get("data")
	print("regions=", data.get_region_count(), " hrange=", data.get_height_range())
	# height grid over candidate area, coarse
	print("--- HEIGHT grid (x cols 150..600 step 50; z rows 300..700 step 50) ---")
	var header := "z\\x  "
	for x in range(150, 601, 50): header += "%5d" % x
	print(header)
	for z in range(300, 701, 50):
		var line := "%4d " % z
		for x in range(150, 601, 50):
			var h = data.get_height(Vector3(x,0,z))
			line += "%5.0f" % (0.0 if is_nan(h) else h)
		print(line)
	# local slope (max height diff to 4 neighbors at 20m) => flatness
	print("--- LOCAL RELIEF over +-25m (low = flat bench) ---")
	print(header)
	for z in range(300, 701, 50):
		var line := "%4d " % z
		for x in range(150, 601, 50):
			var c = data.get_height(Vector3(x,0,z))
			var mx = -1e9; var mn = 1e9
			for dx in [-25,25]:
				for dz in [-25,25]:
					var v = data.get_height(Vector3(x+dx,0,z+dz))
					if not is_nan(v): mx=max(mx,v); mn=min(mn,v)
			line += "%5.0f" % (mx-mn)
		print(line)
	quit()
