extends SceneTree
func _init() -> void:
	var exists := ClassDB.class_exists("Terrain3D")
	print("TERRAIN3D_CLASS_EXISTS=", exists)
	if exists:
		var t: Object = ClassDB.instantiate("Terrain3D")
		print("TERRAIN3D_INSTANTIATED=", t != null, " type=", t.get_class() if t else "null")
		print("HAS_DATA_METHOD=", t.has_method("set_data_directory") or ("data" in t))
	quit()
