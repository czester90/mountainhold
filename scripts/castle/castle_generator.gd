@tool
class_name CastleGenerator
extends Node3D

## Places and docks reusable modules — it never builds geometry itself. Stage-2 layout: a
## corner bastion with two arms. Arm 1: corner -> wall -> gatehouse -> stairs. Arm 2:
## corner -> wall -> tower. Buttresses brace the gatehouse arm. Everything lands under
## GeneratedGeometry, cleared/rebuilt on demand (@tool). Wall-walk is continuous by snap ports.

const WALL_SCENE := preload("res://scenes/castle/wall_segment.tscn")
const TOWER_SCENE := preload("res://scenes/castle/tower.tscn")
const STAIRS_SCENE := preload("res://scenes/castle/stairs.tscn")
const CORNER_SCENE := preload("res://scenes/castle/wall_corner.tscn")
const GATE_SCENE := preload("res://scenes/castle/gatehouse.tscn")
const BUTTRESS_SCENE := preload("res://scenes/castle/buttress.tscn")
const GEN_NAME := "GeneratedGeometry"
const DOCK_EPSILON := 1.0   # allows the intentional seam-closing overlaps on joints

@export var wall_def: WallDefinition = WallDefinition.new()
@export var tower_def: TowerDefinition = TowerDefinition.new()
@export var stair_def: StairDefinition = StairDefinition.new()
@export var corner_def: CornerDefinition = CornerDefinition.new()
@export var gate_def: GatehouseDefinition = GatehouseDefinition.new()
@export var buttress_def: ButtressDefinition = ButtressDefinition.new()
@export var rebuild_now: bool = false:
	set(value):
		rebuild_now = false
		if is_inside_tree():
			build()

var _joints: Array = []

func _ready() -> void:
	build()

func gen() -> Node3D:
	var n := get_node_or_null(GEN_NAME)
	if n == null:
		n = Node3D.new()
		n.name = GEN_NAME
		add_child(n)
	return n

func clear_generated() -> void:
	var n := get_node_or_null(GEN_NAME)
	if n:
		for c in n.get_children():
			n.remove_child(c)
			c.free()

func build() -> void:
	clear_generated()
	_joints.clear()
	var corner := _spawn(CORNER_SCENE, corner_def)          # anchor at origin
	# arm 1: corner -> wall -> gatehouse -> stairs (mirror so merlons face the same convex side)
	var wall_a := _spawn(WALL_SCENE, wall_def)
	wall_a.set("mirror", true)
	wall_a.rebuild()
	_dock(wall_a, "WallWalkExit", corner, "WallWalkA", 0.4)
	var gate := _spawn(GATE_SCENE, gate_def)
	gate.set("mirror", true)
	gate.rebuild()
	_dock(gate, "WallWalkExit", wall_a, "WallWalkEntry", 0.4)
	var stairs := _spawn(STAIRS_SCENE, stair_def)
	_dock(stairs, "StairExit", gate, "WallWalkEntry", 0.3)
	stairs.global_position.y -= 0.03
	# arm 2: corner -> wall -> tower (default side; its merlons already face the convex side)
	var wall_b := _spawn(WALL_SCENE, wall_def)
	_dock(wall_b, "WallWalkExit", corner, "WallWalkB", 0.4)
	var tower := _spawn(TOWER_SCENE, tower_def)
	_dock(tower, "WallWalkEntry", wall_b, "WallWalkEntry", 0.8)
	place_buttresses(wall_a)
	validate_geometry()

func _spawn(scene: PackedScene, def_value: Resource) -> CastleModule:
	var inst: CastleModule = scene.instantiate()
	gen().add_child(inst)
	inst.set("definition", def_value)
	inst.rebuild()
	return inst

# Two stepped buttresses bracing a wall's outer (-Z local) face.
func place_buttresses(wall: CastleModule) -> void:
	var t := wall.global_transform
	for x in [-wall_def.length * 0.28, wall_def.length * 0.28]:
		var b := _spawn(BUTTRESS_SCENE, buttress_def)
		b.global_transform = t * Transform3D(Basis.IDENTITY, Vector3(x, 0.0, -wall_def.thickness * 0.5))

func _dock(mover: CastleModule, mover_port: String, anchor: CastleModule, anchor_port: String, overlap: float = 0.0) -> void:
	var ap := anchor.snap(anchor_port)
	var mp := mover.snap(mover_port)
	if ap == null or mp == null:
		push_warning("dock failed: missing port %s / %s" % [anchor_port, mover_port])
		return
	mover.global_transform = CastleModule.compute_dock(anchor.global_transform, ap.transform, mp.transform)
	if overlap != 0.0:
		var outward := (anchor.global_transform.basis * (ap.transform.basis * Vector3.FORWARD)).normalized()
		mover.global_position -= outward * overlap
	_joints.append([mover, mover_port, anchor, anchor_port])

func validate_geometry() -> void:
	for j in _joints:
		var mover: CastleModule = j[0]
		var mp: Marker3D = mover.snap(j[1])
		var anchor: CastleModule = j[2]
		var ap: Marker3D = anchor.snap(j[3])
		if mp == null or ap == null:
			push_warning("validate: missing port on joint %s<->%s" % [j[1], j[3]])
			continue
		var g: float = (mover.global_transform * mp.transform.origin).distance_to(anchor.global_transform * ap.transform.origin)
		if g > DOCK_EPSILON:
			push_warning("validate: %s<->%s gap = %.2f m" % [j[1], j[3], g])
		else:
			print("validate OK: %s<->%s (%.2f m)" % [j[1], j[3], g])
