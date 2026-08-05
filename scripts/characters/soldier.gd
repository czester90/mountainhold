class_name Soldier
extends RefCounted

## Builds a readable blocky humanoid (helmet, torso, limbs, weapon) from primitives under `parent`,
## facing local +Z. No authored art needed — matches the box-built fortress style. Returns
## {"mats": [...], "bases": [...]} so the owner can hit-flash the whole figure white and restore
## each material's own base colour. `is_archer` gives a bow; otherwise a spear + round shield.

const SKIN := Color(0.72, 0.56, 0.44)
const METAL := Color(0.34, 0.35, 0.40)
const LEATHER := Color(0.28, 0.19, 0.12)
const WOOD := Color(0.45, 0.30, 0.16)

static func build(parent: Node3D, primary: Color, is_archer: bool) -> Dictionary:
	var mats: Array = []
	var bases: Array = []
	var skin := _mat(SKIN, mats, bases)
	var tunic := _mat(primary, mats, bases)
	var metal := _mat(METAL, mats, bases)
	var leather := _mat(LEATHER, mats, bases)
	var wood := _mat(WOOD, mats, bases)
	# legs
	_box(parent, Vector3(-0.16, 0.42, 0), Vector3(0.2, 0.85, 0.24), leather)
	_box(parent, Vector3(0.16, 0.42, 0), Vector3(0.2, 0.85, 0.24), leather)
	# belt + torso
	_box(parent, Vector3(0, 0.92, 0), Vector3(0.62, 0.14, 0.36), leather)
	_box(parent, Vector3(0, 1.28, 0), Vector3(0.6, 0.75, 0.34), tunic)
	# arms (upper tunic + skin forearm)
	for sgn in [-1.0, 1.0]:
		_box(parent, Vector3(sgn * 0.4, 1.42, 0.02), Vector3(0.16, 0.5, 0.18), tunic)
		_box(parent, Vector3(sgn * 0.4, 1.02, 0.06), Vector3(0.14, 0.34, 0.16), skin)
	# head + pointed helm (wide brim at the bottom, tapering to a point on top)
	_sphere(parent, Vector3(0, 1.83, 0), 0.17, skin)
	_cyl(parent, Vector3(0, 1.94, 0), 0.02, 0.21, 0.24, metal)
	if is_archer:
		# a bow held forward-left: two angled wooden limbs + a grip
		_box(parent, Vector3(-0.46, 1.55, 0.16), Vector3(0.05, 0.55, 0.05), wood).rotation = Vector3(0.35, 0, 0)
		_box(parent, Vector3(-0.46, 1.05, 0.16), Vector3(0.05, 0.55, 0.05), wood).rotation = Vector3(-0.35, 0, 0)
		_box(parent, Vector3(-0.46, 1.3, 0.18), Vector3(0.05, 0.28, 0.05), wood)
	else:
		# round shield on the left arm + an upright spear in the right hand
		_cyl(parent, Vector3(-0.46, 1.25, 0.2), 0.34, 0.34, 0.09, wood).rotation = Vector3(PI * 0.5, 0, 0)
		_sphere(parent, Vector3(-0.46, 1.25, 0.26), 0.09, metal)
		var spear := _box(parent, Vector3(0.44, 1.55, 0.1), Vector3(0.05, 2.3, 0.05), wood)
		spear.rotation = Vector3(0.12, 0, 0)
		_cyl(parent, Vector3(0.44, 2.68, 0.24), 0.0, 0.06, 0.28, metal).rotation = Vector3(0.12, 0, 0)
	return {"mats": mats, "bases": bases}

static func _mat(c: Color, mats: Array, bases: Array) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	mats.append(m)
	bases.append(c)
	return m

static func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

static func _sphere(parent: Node3D, pos: Vector3, r: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	mi.mesh = s
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

static func _cyl(parent: Node3D, pos: Vector3, top_r: float, bot_r: float, h: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bot_r
	c.height = h
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi
