@tool
class_name TerrainModule
extends Node3D

## Reusable terrain module: owns a Terrain3D child and builds the original horseshoe mountain
## bowl (Height_Map.exr import + symmetric procedural sculpt + noise stone textures). Exposes
## base() (courtyard height) and height(x,z) so the fortress generator can seat modules on it.

const HEIGHT_EXR := "res://assets/raw/terrain/motion_forge/Height_Map.exr"
const PREVIEW_RES := 1024
const HEIGHT_SCALE := 900.0

@export var centre := Vector2(330.0, 500.0)   # CX, CZ
@export var flat_front: float = 56.0          # R_FLAT
@export var flat_back: float = 36.0           # R_FLAT_BACK
@export var ridge_max: float = 58.0
@export var ridge_slope: float = 1.35
@export var reach: float = 112.0              # RMAX
@export var front_open: float = 0.95
@export var front_band: float = 0.45
@export_group("Approach slope")
## Courtyard rises from the front (west, field side) up toward the rear (east, mountain) so the
## approach climbs to the keep — Helm's-Deep style, not a flat table. Metres of total rise.
@export var court_slope: float = 11.0
## Fraction of the front kept ~flat: the field approach AND the whole outer D-curtain footprint
## sit on level ground (no tilted walls); the ramp to the keep rises behind the curtain.
@export var court_flat_front: float = 0.5
@export_group("Keep pad")
## A FLAT rock shelf for the citadel (keep + inner ring) so its modules seat level (no floating,
## no terrain poking into the keep) and its rear meets the mountain. World x-range = centre.x +
## [dx_min, dx_max]; z within ±hz. Height = _base + rise. Mountain rising above the pad is kept
## (the rear cliff the keep backs into).
@export var keep_pad_rise: float = 10.8
@export var keep_pad_dx_min: float = 12.0
@export var keep_pad_dx_max: float = 34.0
@export var keep_pad_hz: float = 20.0    # covers the inner-ring drum z-rims (dz up to ~19) on flat pad
@export var keep_pad_blend: float = 5.0
@export_group("Cave pocket")
## Carves a flat pocket into the mountain behind the keep (same level as the pad) so a cave hall
## chamber fits, with the mountain rising around/beyond it. World x = centre.x + [dx_min, dx_max].
@export var cave_pocket: bool = true
@export var cave_dx_min: float = 33.0
@export var cave_dx_max: float = 56.0
@export var cave_hz: float = 10.0
@export var cave_blend: float = 4.0
@export_group("Jaggedness")
@export var jag_amp: float = 26.0       # height of the ridged noise on the mountain rim
@export var jag_freq: float = 0.02
@export var jag_octaves: int = 5
@export var base_jitter: float = 8.0    # breaks the flat-to-mountain boundary
@export var edge_blend: float = 0.35    # fraction of `reach` used to melt into the surrounding EXR
@export var rebuild_now: bool = false:
	set(value):
		rebuild_now = false
		if is_inside_tree():
			rebuild()

var _terrain: Node
var _base := 0.0
var _built := false

func _ready() -> void:
	rebuild()

func rebuild() -> void:
	_built = false
	ensure_built()

func ensure_built() -> void:
	if _built:
		return
	_terrain = get_node_or_null("Terrain3D")
	if _terrain == null:
		push_warning("TerrainModule: no Terrain3D child")
		return
	_import()
	setup_textures()
	sculpt()
	_built = true

func base() -> float:
	ensure_built()
	return _base

func height(x: float, z: float) -> float:
	if _terrain == null:
		return 0.0
	var v: float = _terrain.get("data").get_height(Vector3(x, 0.0, z))
	return 0.0 if is_nan(v) else v

func _import() -> void:
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(HEIGHT_EXR)) != OK:
		return
	img.resize(PREVIEW_RES, PREVIEW_RES, Image.INTERPOLATE_LANCZOS)
	if img.get_format() != Image.FORMAT_RF:
		img.convert(Image.FORMAT_RF)
	var data = _terrain.get("data")
	if data.get_region_count() == 0:
		data.import_images([img, null, null], Vector3.ZERO, 0.0, HEIGHT_SCALE)
	data.calc_height_range(true)

func _ang_to_west(dx: float, dz: float) -> float:
	var a := atan2(dz, dx)
	var d: float = absf(a - PI)
	if d > PI:
		d = TAU - d
	return d

func sculpt() -> void:
	var data = _terrain.get("data")
	_base = height(centre.x - 12.0, centre.y)
	# FBM for broad undulation of the mountain mass
	var nz := FastNoiseLite.new()
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX
	nz.fractal_type = FastNoiseLite.FRACTAL_FBM
	nz.fractal_octaves = jag_octaves
	nz.frequency = jag_freq
	# ridged noise for sharp ridgelines (added only higher up, so no needles at the base)
	var nzr := FastNoiseLite.new()
	nzr.noise_type = FastNoiseLite.TYPE_SIMPLEX
	nzr.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	nzr.fractal_octaves = jag_octaves
	nzr.frequency = jag_freq * 1.3
	nzr.seed = 5
	# lower-frequency noise to jitter the mountain base line
	var nz2 := FastNoiseLite.new()
	nz2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz2.frequency = jag_freq * 0.4
	nz2.seed = 12
	var rr: int = int(reach)
	var blend_w := maxf(1.0, reach * edge_blend)
	for dz in range(-rr, rr + 1):
		for dx in range(-rr, rr + 1):
			var d := sqrt(float(dx * dx + dz * dz))
			if d > reach:
				continue
			var wx := centre.x + dx
			var wz := centre.y + dz
			var exr := height(wx, wz)                                    # original EXR height (read before we set)
			var g: float = clampf((_ang_to_west(float(dx), float(dz)) - front_open) / front_band, 0.0, 1.0)
			# jitter the flat-radius boundary so the mountain foot isn't a clean circle
			var rflat_eff: float = lerp(flat_front, flat_back, g) + nz2.get_noise_2d(wx, wz) * base_jitter
			var over := d - rflat_eff
			# courtyard floor rises front(west)->rear(east): the approach climbs toward the keep.
			# court_t 0 at the west edge, 1 at the east edge; kept flat over the front fraction.
			var court_t: float = clampf((float(dx) + flat_front) / (flat_front + flat_back), 0.0, 1.0)
			var court_h: float = _base + court_slope * smoothstep(court_flat_front, 1.0, court_t)
			var target := court_h
			if over > 0.0:
				var rise := minf(ridge_max, over * ridge_slope)
				var hf := clampf(over / 35.0, 0.0, 1.0)                  # 0 at the foot -> 1 high up (no base needles)
				var fbm := nz.get_noise_2d(wx, wz)                       # -1..1 broad undulation
				var ridge := nzr.get_noise_2d(wx, wz) * 0.5 + 0.5        # 0..1 sharp ridgelines
				rise = rise * lerp(0.7, 1.25, fbm * 0.5 + 0.5)           # vary the mass
				rise += jag_amp * hf * ridge                             # ridgelines, only higher up
				target = court_h + g * rise                              # mountains grow from the sloped foot
			# flat citadel pad: level the shelf under the keep+inner ring, but keep any mountain
			# that rises above it (the rear cliff the keep backs into)
			if keep_pad_rise > 0.0:
				var pad_h: float = _base + keep_pad_rise
				var ux: float = smoothstep(keep_pad_dx_min - keep_pad_blend, keep_pad_dx_min, float(dx))
				var uz: float = 1.0 - smoothstep(keep_pad_hz, keep_pad_hz + keep_pad_blend, absf(float(dz)))
				var pad_w: float = ux * uz
				if pad_w > 0.0:
					var flat_target: float = pad_h
					if over > 0.0 and target > pad_h:
						flat_target = target                             # mountain higher than pad -> keep the cliff
					target = lerp(target, flat_target, pad_w)
				# cave pocket: carve the mountain down to pad level behind the keep for the cave hall
				if cave_pocket:
					var cxx: float = smoothstep(cave_dx_min - cave_blend, cave_dx_min, float(dx)) * (1.0 - smoothstep(cave_dx_max, cave_dx_max + cave_blend, float(dx)))
					var czz: float = 1.0 - smoothstep(cave_hz, cave_hz + cave_blend, absf(float(dz)))
					var cw: float = cxx * czz
					if cw > 0.0:
						target = lerp(target, pad_h, cw)
				# keep footprint (dx 24-36, |dz|<9): force the pad level so the mountain never pokes
				# THROUGH the keep interior (the keep sits fitted into the mountain, not buried by it)
				var kxx: float = smoothstep(20.0, 23.0, float(dx)) * (1.0 - smoothstep(37.0, 40.0, float(dx)))
				var kzz: float = 1.0 - smoothstep(10.0, 12.0, absf(float(dz)))
				var kw: float = kxx * kzz
				if kw > 0.0:
					target = lerp(target, pad_h, kw)
			# melt the sculpt edge into the surrounding natural EXR terrain (kills the RMAX cliff)
			var edge := clampf((reach - d) / blend_w, 0.0, 1.0)
			var final_h: float = lerp(exr, target, edge)
			data.set_height(Vector3(wx, 0.0, wz), final_h)
	data.calc_height_range(true)
	data.update_maps()

const PBR := "res://assets/raw/terrain/pbr/"
const CACHE := "res://assets/processed/terrain/pbr/"

# Channel-pack RGB (albedo/normal) + a grayscale alpha (height/roughness) into one RGBA texture,
# per Terrain3D's format. Packs once and caches the result as PNG for fast subsequent loads.
func _packed(rgb_path: String, alpha_path: String, cache_name: String) -> ImageTexture:
	var out := CACHE + cache_name + ".png"
	var img := Image.new()
	if FileAccess.file_exists(out):
		img.load(ProjectSettings.globalize_path(out))
	else:
		img.load(ProjectSettings.globalize_path(rgb_path))
		img.convert(Image.FORMAT_RGBA8)
		var a := Image.new()
		a.load(ProjectSettings.globalize_path(alpha_path))
		if a.get_size() != img.get_size():
			a.resize(img.get_width(), img.get_height())
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				c.a = a.get_pixel(x, y).r
				img.set_pixel(x, y, c)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE))
		img.save_png(ProjectSettings.globalize_path(out))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _pbr_asset(id: int, name: String, dir: String, prefix: String, uv: float) -> Terrain3DTextureAsset:
	var base := PBR + dir + "/" + prefix
	var a := Terrain3DTextureAsset.new()
	a.set("name", name)
	a.set("id", id)
	a.set("albedo_color", Color.WHITE)
	a.set("albedo_texture", _packed(base + "Color.jpg", base + "Displacement.jpg", name + "_alb"))
	a.set("normal_texture", _packed(base + "NormalGL.jpg", base + "Roughness.jpg", name + "_nrm"))
	a.set("uv_scale", uv)
	return a

func setup_textures() -> void:
	# id0 = ground/scree on the flats & valley; id1 = rock on the steep slopes (auto_shader blends
	# them by slope). Real CC0 PBR from ambientCG with normal maps -> reads as actual rock.
	var ground := _pbr_asset(0, "ground", "ground", "Ground037_1K-JPG_", 0.09)
	var rock := _pbr_asset(1, "rock", "rock", "Rock030_1K-JPG_", 0.06)
	var assets := Terrain3DAssets.new()
	assets.set_texture_list([ground, rock])
	_terrain.set_assets(assets)
	var mat = _terrain.get("material")
	if mat:
		mat.set("auto_shader", true)
		mat.set("show_grey", false)
		mat.set("show_checkered", false)
		mat.set("world_background", 1)
	_terrain.set("show_grey", false)
	_terrain.set("show_checkered", false)
