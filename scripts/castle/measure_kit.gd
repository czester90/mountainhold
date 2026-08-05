extends SceneTree

func _init() -> void:
	for n in ["Courtine_Wall", "Wall_Battlements", "Wall_Floor", "Courtine_Door_Arch"]:
		var m := CastleKit.mesh(n)
		if m == null:
			print(n, " = MISSING")
			continue
		var aabb := m.get_aabb()
		print(n, " pos=", aabb.position, " size=", aabb.size, " end=", aabb.end)
	quit()
