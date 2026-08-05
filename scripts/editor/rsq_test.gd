extends Node3D
const WALL := "res://Assets/LoafbrrAssets/CastleWallKit/scenes/Courtines/Wall/courtine_wall.tscn"
const CORNER := "res://Assets/LoafbrrAssets/CastleWallKit/scenes/Walls/Corner/wall_corner_round.tscn"
# tunable connection points of the corner piece (local)
const IN := Vector3(6, 0, 0)
const OUT := Vector3(0, 0, -6)
func _ready() -> void:
	_ring(Vector3(0,0,0), IN, OUT)                       # guess A
	_ring(Vector3(24,0,0), Vector3(0,0,0), Vector3(6,0,-6))  # guess B (in=origin,out=far)
	_ring(Vector3(0,0,24), Vector3(6,0,-6), Vector3(0,0,0))  # guess C swapped
func _ring(c: Vector3, in_p: Vector3, out_p: Vector3) -> void:
	_mk(c)
	var pos := c + Vector3(-9,0,3)
	var dir := Vector3(1,0,0)
	for side in 4:
		var yaw := atan2(-dir.z, dir.x)
		_inst(WALL, pos, yaw)
		pos += dir*6.0
		var b := Basis(Vector3.UP, yaw)
		var origin_c := pos - b*in_p
		_inst(CORNER, origin_c, yaw)
		pos = origin_c + b*out_p
		dir = dir.rotated(Vector3.UP, -PI/2.0)
func _inst(path: String, pos: Vector3, yaw: float) -> void:
	var s: Node3D = load(path).instantiate()
	s.transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	add_child(s)
func _mk(p: Vector3) -> void:
	var m := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size=Vector3(0.6,0.6,0.6)
	var mat := StandardMaterial3D.new(); mat.albedo_color=Color(1,0.2,0.1)
	m.mesh=bm; m.material_override=mat; m.position=p+Vector3(0,0.3,0); add_child(m)
