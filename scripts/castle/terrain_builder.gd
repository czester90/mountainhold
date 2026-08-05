@tool
extends Node3D

## Procedural mountain-bowl terrain around the fortress: a flat courtyard at y=0, rock rising on
## the sides and back (a horseshoe wrapping the fortress), open on the front (+Z field) where the
## keep and gate face. One merged ArrayMesh + trimesh collision.

@export var size: float = 260.0
@export var step: float = 3.0
@export var flat_front: float = 66.0     # courtyard/field stays flat this far on the open side
@export var flat_back: float = 46.0      # rock climbs closer behind
@export var front_open: float = 0.85     # half-angle (rad) of the open field wedge (around +Z)
@export var front_band: float = 0.5
@export var slope: float = 1.25
@export var ridge_max: float = 62.0
@export var rebuild_now: bool = false:
	set(value):
		rebuild_now = false
		if is_inside_tree():
			build()

func _ready() -> void:
	build()

func _h(x: float, z: float) -> float:
	var d := sqrt(x * x + z * z)
	var ang := atan2(x, z)                          # 0 at +Z (open field direction)
	var g := clampf((absf(ang) - front_open) / front_band, 0.0, 1.0)
	var rflat: float = lerp(flat_front, flat_back, g)
	var over := d - rflat
	if over <= 0.0:
		return 0.0
	return g * minf(ridge_max, over * slope)

func build() -> void:
	for c in get_children():
		remove_child(c)
		c.free()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.31, 0.33, 0.29)
	mat.roughness = 1.0
	var half := size * 0.5
	var n: int = int(size / step)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in n:
		for ix in n:
			var x0 := -half + ix * step
			var z0 := -half + iz * step
			var x1 := x0 + step
			var z1 := z0 + step
			var p00 := Vector3(x0, _h(x0, z0), z0)
			var p10 := Vector3(x1, _h(x1, z0), z0)
			var p11 := Vector3(x1, _h(x1, z1), z1)
			var p01 := Vector3(x0, _h(x0, z1), z1)
			for v in [p00, p10, p11, p00, p11, p01]:
				st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)
	mi.create_trimesh_collision()
