extends SceneTree
func _init() -> void:
	_run()
func _run() -> void:
	var t = ClassDB.instantiate("Terrain3D")
	t.set("region_size", 1024)
	t.set("data_directory", "res://assets/processed/terrain/diag_data")
	get_root().add_child(t)
	await process_frame
	await process_frame
	var data = t.get("data")
	var img := Image.new(); img.load(ProjectSettings.globalize_path("res://assets/raw/terrain/motion_forge/Height_Map.exr"))
	img.resize(1024,1024,Image.INTERPOLATE_LANCZOS); img.convert(Image.FORMAT_RF)
	data.import_images([img,null,null], Vector3.ZERO, 0.0, 900.0)
	data.calc_height_range(true)
	print("before flatten: h(330,500)=", data.get_height(Vector3(330,0,500)))
	var base = data.get_height(Vector3(318,0,500))
	print("base=", base)
	for dz in range(-40,41):
		for dx in range(-40,41):
			data.set_height(Vector3(330+dx,0,500+dz), base)
	print("after set_height (no refresh): h(330,500)=", data.get_height(Vector3(330,0,500)), " h(360,500)=", data.get_height(Vector3(360,0,500)))
	print("--- Terrain3DData methods (update/map/dirty/modified) ---")
	for m in ClassDB.class_get_method_list("Terrain3DData", true):
		var n:String=m.name
		if n.contains("update") or n.contains("map") or n.contains("dirty") or n.contains("modified") or n.contains("force"):
			print("  ", n)
	print("--- Terrain3D methods (update/map/dirty) ---")
	for m in ClassDB.class_get_method_list("Terrain3D", true):
		var n:String=m.name
		if n.contains("update") or n.contains("dirt") or n.contains("force"):
			print("  ", n)
	quit()
