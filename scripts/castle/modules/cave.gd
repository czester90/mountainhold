@tool
class_name Cave
extends CastleModule

## A cave hall carved into the mountain behind the keep (the Glittering Caves). A dark rock
## chamber — floor, side + back walls, ceiling, an arched mouth at the front (toward the keep) —
## lit by a scatter of glowing crystals. Placed in a pocket the terrain module cuts for it, with
## the mountain rising over/around it. Mouth faces local -Z. Collision on all surfaces.

@export var width: float = 15.0
@export var depth: float = 17.0
@export var height: float = 5.2
@export var mouth_width: float = 5.0

func _construct() -> void:
	var dark := _rock()
	var hw := width * 0.5
	var t := 0.7
	# floor rises gently deeper into the mountain
	add_box(Vector3(0, -0.25, depth * 0.5), Vector3(width, 0.5, depth), dark)
	# ceiling (a touch wider so no seam with the walls)
	add_box(Vector3(0, height, depth * 0.5), Vector3(width + 1.0, 0.6, depth + 1.0), dark)
	# back wall
	add_box(Vector3(0, height * 0.5, depth), Vector3(width, height, t), dark)
	# side walls
	add_box(Vector3(-hw, height * 0.5, depth * 0.5), Vector3(t, height, depth), dark)
	add_box(Vector3(hw, height * 0.5, depth * 0.5), Vector3(t, height, depth), dark)
	# front face: solid either side of the mouth + a lintel above it
	var mhw := mouth_width * 0.5
	var side := (hw - mhw) * 0.5
	add_box(Vector3(-(mhw + side * 0.0) - side, height * 0.5, 0), Vector3(hw - mhw, height, t), dark)
	add_box(Vector3((mhw + side * 0.0) + side, height * 0.5, 0), Vector3(hw - mhw, height, t), dark)
	add_box(Vector3(0, height - 0.6, 0), Vector3(mouth_width, 1.2, t), dark)
	_glitter()
	set_snap("Mouth", Vector3(0, 0, 0), Vector3.FORWARD)

func _rock() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.11, 0.12, 0.15)
	m.roughness = 1.0
	return m

func _glitter() -> void:
	var g := StandardMaterial3D.new()
	g.albedo_color = Color(0.6, 0.85, 1.0)
	g.emission_enabled = true
	g.emission = Color(0.45, 0.9, 1.0)
	g.emission_energy_multiplier = 3.5
	var hw := width * 0.5
	# clusters of tapered crystals (cones): on the floor pointing up, on the walls pointing inward.
	# [pos, tilt_axis, tilt_rad, scale] — deterministic (no RNG) so rebuilds are stable.
	var crystals := [
		[Vector3(-hw + 0.4, 0.0, 4.0), Vector3.FORWARD, 0.3, 1.4], [Vector3(-hw + 0.6, 0.0, 4.6), Vector3.FORWARD, -0.2, 1.0],
		[Vector3(hw - 0.4, 0.0, 7.0), Vector3.BACK, 0.35, 1.6], [Vector3(hw - 0.7, 0.0, 7.5), Vector3.BACK, 0.15, 1.1],
		[Vector3(-hw + 2.5, 0.0, depth - 2.0), Vector3.ZERO, 0.0, 2.2], [Vector3(-hw + 3.2, 0.0, depth - 2.4), Vector3.ZERO, 0.0, 1.5],
		[Vector3(hw - 2.5, 0.0, depth - 3.0), Vector3.ZERO, 0.0, 1.9], [Vector3(2.0, 0.0, depth - 1.0), Vector3.ZERO, 0.0, 2.6],
		[Vector3(-1.5, height, 6.0), Vector3.RIGHT, PI, 1.2], [Vector3(1.5, height, 11.0), Vector3.RIGHT, PI, 1.5],
		[Vector3(-hw + 0.4, 2.6, 12.0), Vector3.FORWARD, 1.4, 1.0], [Vector3(hw - 0.4, 3.0, 14.0), Vector3.BACK, 1.4, 1.2],
	]
	for c in crystals:
		var mi := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.18 * c[3]
		cone.height = 1.1 * c[3]
		mi.mesh = cone
		mi.material_override = g
		var basis := Basis.IDENTITY
		if c[1] != Vector3.ZERO:
			basis = basis.rotated(c[1], c[2])
		mi.transform = Transform3D(basis, c[0] + Vector3(0, 0.5 * 1.1 * c[3], 0) if c[1] == Vector3.ZERO else c[0])
		gen().add_child(mi)
	# blue-glow fill lights so the chamber glitters instead of going pitch black
	for lp in [Vector3(0, height * 0.55, depth * 0.35), Vector3(0, 1.2, depth - 2.0)]:
		var lamp := OmniLight3D.new()
		lamp.omni_range = width
		lamp.light_energy = 0.9
		lamp.light_color = Color(0.55, 0.8, 1.0)
		lamp.position = lp
		gen().add_child(lamp)

func validate_geometry() -> void:
	pass
