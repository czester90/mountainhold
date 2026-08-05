extends Node3D

const OUT := "res://screenshots/castle_proto"
const SCENE := "res://scenes/castle/prototype.tscn"

var _cam: Camera3D

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var scene: Node = load(SCENE).instantiate()
	add_child(scene)
	var scene_cam := scene.get_node_or_null("Camera3D")
	if scene_cam:
		scene_cam.current = false
	_cam = Camera3D.new()
	_cam.fov = 60.0
	_cam.far = 4000.0
	add_child(_cam)
	_cam.current = true
	for _i in 30:
		await get_tree().process_frame
	# auto-frame: union AABB of all generated meshes
	var aabb := AABB()
	var first := true
	var count := 0
	var stack: Array = [scene]
	while not stack.is_empty():
		var nn = stack.pop_back()
		if nn is MeshInstance3D and (nn as MeshInstance3D).mesh and nn.name != "GroundMesh":
			var mi := nn as MeshInstance3D
			count += 1
			var wa: AABB = mi.global_transform * mi.get_aabb()
			if first:
				aabb = wa
				first = false
			else:
				aabb = aabb.merge(wa)
		for c in nn.get_children():
			stack.append(c)
	var ctr := aabb.get_center()
	var rad: float = maxf(aabb.size.length() * 0.6, 8.0)
	print("MESHES=", count, " AABB_center=", ctr, " size=", aabb.size)
	var dirs := {
		"01_overview": Vector3(1, 0.9, 1),
		"02_side": Vector3(1, 0.3, 0.2),
		"03_front": Vector3(0.2, 0.3, 1),
		"04_low": Vector3(-1, 0.25, -1),
		"05_top": Vector3(0.01, 1, 0.01),
	}
	for s in dirs:
		_cam.global_position = ctr + (dirs[s] as Vector3).normalized() * rad
		_cam.look_at(ctr, Vector3.UP)
		for _j in 6:
			await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("%s/%s.png" % [OUT, s])
		print("SHOT ", s)
	print("CAPTURE DONE")
	get_tree().quit()
