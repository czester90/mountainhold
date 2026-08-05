extends Node3D
const C := "res://Assets/LoafbrrAssets/CastleWallKit/scenes/Walls/Corner/wall_corner_round.tscn"
func _ready() -> void:
	# arrangement A: 4 at same centre, yaw 0/90/180/270  (centre marker at origin)
	_mk(Vector3(0,0,0))
	for q in 4: _inst(Vector3(0,0,0), q*90)
	# arrangement B: rotate about cell centre (offset piece by (-3,+3) then rotate about origin)
	_mk(Vector3(20,0,0))
	for q in 4: _inst_about(Vector3(20,0,0), q*90, Vector3(-3,0,3))
	# arrangement C: rotate about cell centre offset (-3,-3)
	_mk(Vector3(40,0,0))
	for q in 4: _inst_about(Vector3(40,0,0), q*90, Vector3(-3,0,-3))
	# arrangement D: rotate about (+3,-3)
	_mk(Vector3(0,0,20))
	for q in 4: _inst_about(Vector3(0,0,20), q*90, Vector3(3,0,-3))
func _inst(centre: Vector3, yaw_deg: float) -> void:
	var s: Node3D = load(C).instantiate()
	s.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), centre)
	add_child(s)
func _inst_about(centre: Vector3, yaw_deg: float, off: Vector3) -> void:
	var s: Node3D = load(C).instantiate()
	var b := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	s.transform = Transform3D(b, centre + b * off)
	add_child(s)
func _mk(p: Vector3) -> void:
	var m := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.5,0.5,0.5)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(1,0.2,0.1)
	m.mesh = bm; m.material_override = mat; m.position = p + Vector3(0,0.25,0); add_child(m)
