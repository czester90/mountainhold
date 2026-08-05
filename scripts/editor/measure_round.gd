extends SceneTree

const GLTF := "res://assets/raw/loafbrr_castle_wall_kit/gltf/CastleWallsKit.gltf"

func _init() -> void:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_file(ProjectSettings.globalize_path(GLTF), st)
	var root := doc.generate_scene(st)
	for name in ["Wall_Battlements_Corner_Round", "Wall_Floor_Round"]:
		var mi := _find(root, name)
		if mi == null:
			print("MISSING ", name); continue
		_dump(name, mi.mesh)
	quit()

func _find(n: Node, name: String) -> MeshInstance3D:
	if n is MeshInstance3D and String(n.name) == name and n.mesh:
		return n
	for c in n.get_children():
		var r := _find(c, name)
		if r != null: return r
	return null

func _dump(name: String, mesh: Mesh) -> void:
	var arr := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var mn := Vector3(1e9, 1e9, 1e9)
	var mx := -mn
	for v in verts:
		mn = mn.min(v); mx = mx.max(v)
	# test candidate arc centres: which one gives constant distance for the outer ring?
	var cands := [Vector2(3, -3), Vector2(6, -6), Vector2(0, 0)]
	print("\n=== ", name, " AABB min=", mn, " max=", mx)
	for c in cands:
		var rmin := 1e9
		var rmax := -1e9
		for v in verts:
			# only outer-ring verts: those far from centre
			var d: float = Vector2(v.x, v.z).distance_to(c)
			rmin = minf(rmin, d); rmax = maxf(rmax, d)
		print("  centre(%.0f,%.0f): r range [%.2f .. %.2f]" % [c.x, c.y, rmin, rmax])
