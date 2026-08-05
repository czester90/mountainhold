@tool
class_name Keep
extends CastleModule

## Great-keep (stołp) — a faithful port of the original donjon: kit-faced 3x3 grid (front gate
## arch + square windows + slits, back gate, side doors), floor at 6 m, solid side wall bodies
## linking the curtain, interior wooden switchback stair to an 18 m roof with a hatch, buttress
## pilasters, machicolation + battlement crown. Front = +Z (faces the field).
## Ports: WallWalkEntry (-X), WallWalkExit (+X) at walk level.

const WALL_H := 6.0

@export var definition: KeepDefinition = KeepDefinition.new():
	set(value):
		definition = value
		if is_inside_tree():
			rebuild()

func _construct() -> void:
	var hx := definition.width * 0.5
	var hz := definition.depth * 0.5
	var floor_mat := mat_floor()
	var brick := mat_stone()
	for s in 3:
		var y := s * WALL_H
		for c in 3:
			var fx := -hx + c * WALL_H
			var back := "Courtine_Door_Arch" if (s == 0 and c == 1) else "Courtine_Wall"
			var front := "Courtine_Wall"
			if s == 0:
				front = "Courtine_Door_Arch" if c == 1 else "Courtine_Slit"
			elif s == 1:
				# field-facing firing gallery: DOOR-arch kit pieces have their opening at the storey
				# floor (eye level), unlike the square-window kit whose hole sits ~2.3 m up. Same kit
				# so the wall plane is unchanged (no shifted wall).
				front = "Courtine_Door_Arch"
			else:
				front = "Courtine_Slit"
			add_kit(front, Vector3(fx, y, hz), 0.0)
			add_kit(back, Vector3(hx - c * WALL_H, y, -hz), PI)
		for c in 2:
			var rp := "Courtine_Door_Square" if (s == 1 and c == 1) else "Courtine_Wall"
			var lp := "Courtine_Door_Square" if (s == 1 and c == 0) else "Courtine_Wall"
			add_kit(rp, Vector3(hx, y, hz - c * WALL_H), PI * 0.5)
			add_kit(lp, Vector3(-hx, y, -hz + c * WALL_H), PI * 1.5)
	# paved GROUND floor at the base, so the first-floor access hole shows a stone floor below instead
	# of the bare carved terrain of the keep pocket (the "gap in the floor" the player saw). Top sits
	# ~0.25 m PROUD of the seat so it never z-fights the pocket terrain (which is ~coplanar at y0).
	add_box(Vector3(0, 0.1, 0), Vector3(2.0 * hx, 0.3, 2.0 * hz), floor_mat)
	# ground -> first-floor access switchback in the NE quadrant (local x~6.5 -> world z~506, north
	# of the back arch), clear of the central bailey->cave through-passage (|local x|<=3)
	build_wooden_switchback(Vector3(6.5, 0.0, 0.0), 0.0, WALL_H, Vector3(0, 0, 1), 3.0, 2.0, 3.0)
	# first floor at 6 m: a picture-frame of slabs leaving a hole over the access stair
	_floor_with_hole(WALL_H - 0.15, hx, hz, floor_mat, 4.0, 9.0, -3.0, 3.0)
	# solid side wall bodies (0-6 m) linking to the flanking curtain
	for sgn in [-1.0, 1.0]:
		add_box(Vector3(float(sgn) * (hx + 1.5), WALL_H * 0.5, 0), Vector3(3.0, WALL_H, 2 * hz - 0.5), brick)
	# interior wooden switchback stair 6 m -> 18 m roof (reached from the first floor, which is at
	# wall-walk level and joins the flanking inner-ring rampart)
	var kws := build_wooden_switchback(Vector3.ZERO, WALL_H, 3 * WALL_H, Vector3(1, 0, 0), 7.0, 2.2, 3.0)
	_tiled_deck(3 * WALL_H - 0.15, kws, hx, hz, floor_mat)
	# buttress pilasters framing the gate + front corners
	# light waist-high parapet across the front firing gallery so the player can't fall out of the
	# floor-level door openings (low enough to loose arrows over it)
	add_box(Vector3(0, WALL_H + 0.3, hz - 0.1), Vector3(2.0 * hx - 1.0, 0.95, 0.3), brick)
	for px in [-hx, -WALL_H * 0.5, WALL_H * 0.5, hx]:
		add_box(Vector3(px, 3 * WALL_H * 0.5, hz + 0.35), Vector3(1.2, 3 * WALL_H, 1.1), brick)
	# crown: machicolation on the front, battlements all around
	var top := 3 * WALL_H
	for c in 3:
		var fx := -hx + c * WALL_H + WALL_H * 0.5
		add_kit("Wall_Machicolation", Vector3(fx, top - 1.0, hz), 0.0)
		add_kit("Wall_Battlements", Vector3(fx, top, hz), 0.0)
		add_kit("Wall_Battlements", Vector3(hx - c * WALL_H - WALL_H * 0.5, top, -hz), PI)
	for c in 2:
		add_kit("Wall_Battlements", Vector3(hx, top, hz - c * WALL_H - WALL_H * 0.5), PI * 0.5)
		add_kit("Wall_Battlements", Vector3(-hx, top, -hz + c * WALL_H + WALL_H * 0.5), PI * 1.5)
	place_snaps()

# a floor deck at height y, tiled, leaving a hatch hole over the switchback `kws` so the stair
# emerges through it
func _tiled_deck(y: float, kws: Dictionary, hx: float, hz: float, mat: StandardMaterial3D) -> void:
	var hc: Vector3 = kws["hatch_c"]
	var hd: Vector3 = kws["hatch_d"]
	var hs := hd.cross(Vector3.UP).normalized()
	var hrun: float = kws["hatch_run"]
	var hw: float = kws["hatch_w"]
	var step := 1.5
	var mx: int = int(hx / step) + 1
	var mz: int = int(hz / step) + 1
	for ix in range(-mx, mx + 1):
		for iz in range(-mz, mz + 1):
			var px := ix * step
			var pz := iz * step
			if absf(px) > hx or absf(pz) > hz:
				continue
			var rel := Vector3(px - hc.x, 0.0, pz - hc.z)
			if absf(rel.dot(hd)) < hrun * 0.5 and absf(rel.dot(hs)) < hw * 0.5:
				continue
			add_box(Vector3(px, y, pz), Vector3(step + 0.05, 0.3, step + 0.05), mat)

# first-floor deck as 4 slabs framing a rectangular hole (local x[x0,x1], z[z0,z1]) for the access
# stair to emerge through; preserves the original slab extent so the side-wall bodies stay covered
func _floor_with_hole(y: float, hx: float, hz: float, mat: StandardMaterial3D, x0: float, x1: float, z0: float, z1: float) -> void:
	var ex := hx + 3.0
	var ez := hz - 0.25
	add_box(Vector3(0, y, (-ez + z0) * 0.5), Vector3(2.0 * ex, 0.3, ez + z0), mat)                 # south strip
	add_box(Vector3(0, y, (ez + z1) * 0.5), Vector3(2.0 * ex, 0.3, ez - z1), mat)                  # north strip
	add_box(Vector3((-ex + x0) * 0.5, y, (z0 + z1) * 0.5), Vector3(ex + x0, 0.3, z1 - z0), mat)     # west of hole
	add_box(Vector3((ex + x1) * 0.5, y, (z0 + z1) * 0.5), Vector3(ex - x1, 0.3, z1 - z0), mat)      # east of hole

func place_snaps() -> void:
	var hx := definition.width * 0.5
	set_snap("WallWalkEntry", Vector3(-hx, WALL_H, 0), Vector3.LEFT)
	set_snap("WallWalkExit", Vector3(hx, WALL_H, 0), Vector3.RIGHT)

func validate_geometry() -> void:
	pass
