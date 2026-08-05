@tool
class_name CastleKit
extends RefCounted

## Shared, cached access to the Loafbrr Castle Wall Kit: meshes (by node name) and the
## textured brick/floor materials, loaded once. Ported from the proven fortress builder so
## every module reuses the SAME look (real kit meshes + triplanar brick textures), instead of
## flat-shaded primitives.

const GLTF := "res://assets/raw/loafbrr_castle_wall_kit/gltf/CastleWallsKit.gltf"
const TEX_DIR := "res://assets/raw/loafbrr_castle_wall_kit/textures"

static var _meshes: Dictionary = {}
static var _mats: Dictionary = {}
static var _brick_tri: StandardMaterial3D
static var _floor_mat: StandardMaterial3D
static var _wood: StandardMaterial3D
static var _wood_dark: StandardMaterial3D
static var _loaded := false

static func _tex(p: String) -> ImageTexture:
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(p)) != OK:
		return null
	return ImageTexture.create_from_image(img)

static func _brick(dir: String, tag: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var b := _tex("%s/%s/Base Color_%s.png" % [TEX_DIR, dir, tag])
	if b:
		m.albedo_texture = b
	var n := _tex("%s/%s/NORMAL_%s.png" % [TEX_DIR, dir, tag])
	if n:
		m.normal_enabled = true
		m.normal_texture = n
	var mr := _tex("%s/%s/MRAO_%s.exr" % [TEX_DIR, dir, tag])
	if mr:
		m.metallic = 1.0
		m.metallic_texture = mr
		m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.roughness_texture = mr
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		m.ao_enabled = true
		m.ao_texture = mr
		m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

static func _load_meshes() -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(GLTF), state) != OK:
		push_error("CastleKit: failed to load " + GLTF)
		return
	var root := doc.generate_scene(state)
	var stack: Array = [root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D and n.mesh:
			_meshes[String(n.name)] = n.mesh
		for c in n.get_children():
			stack.append(c)
	root.queue_free()

static func _ensure() -> void:
	if _loaded:
		return
	_load_meshes()
	_mats["BrickWall"] = _brick("BrickWall", "BrickWall")
	_mats["BrickTrims"] = _brick("BrickTrims", "BrickTrims")
	_mats["BrickFloor"] = _brick("BrickFloor", "BrickFloor")
	_brick_tri = _brick("BrickWall", "BrickWall")
	_brick_tri.uv1_triplanar = true
	_brick_tri.uv1_world_triplanar = true
	_brick_tri.uv1_scale = Vector3(0.16, 0.16, 0.16)
	_floor_mat = _brick("BrickFloor", "BrickFloor")
	_floor_mat.uv1_triplanar = true
	_floor_mat.uv1_world_triplanar = true
	_floor_mat.uv1_scale = Vector3(0.16, 0.16, 0.16)
	_wood = StandardMaterial3D.new()
	_wood.albedo_color = Color(0.40, 0.26, 0.14)
	_wood.roughness = 0.9
	_wood_dark = StandardMaterial3D.new()
	_wood_dark.albedo_color = Color(0.22, 0.14, 0.08)
	_wood_dark.roughness = 0.95
	_loaded = true

static func reload() -> void:
	_loaded = false
	_meshes.clear()
	_mats.clear()
	_ensure()

static func mesh(name: String) -> Mesh:
	_ensure()
	return _meshes.get(name)

static func mat(key: String) -> StandardMaterial3D:
	_ensure()
	return _mats.get(key, _mats["BrickWall"])

static func brick_tri() -> StandardMaterial3D:
	_ensure()
	return _brick_tri

static func floor_mat() -> StandardMaterial3D:
	_ensure()
	return _floor_mat

static func wood() -> StandardMaterial3D:
	_ensure()
	return _wood

static func wood_dark() -> StandardMaterial3D:
	_ensure()
	return _wood_dark
