@tool
class_name WallCorner
extends CastleModule

## Square corner bastion turning the wall-walk 90 degrees. Solid brick block + walk deck on
## top + merlons on the two outer edges (+X, +Z). Ports: WallWalkA (-X), WallWalkB (-Z).

@export var definition: CornerDefinition = CornerDefinition.new():
	set(value):
		definition = value
		if is_inside_tree():
			rebuild()

func _construct() -> void:
	build_body()
	place_battlements()
	place_snaps()

func build_body() -> void:
	var d := definition
	var s := d.side
	add_box(Vector3(0, (d.height - 0.3) * 0.5, 0), Vector3(s, d.height - 0.3, s), mat_stone())   # core below walk
	add_box(Vector3(0, d.height - 0.15, 0), Vector3(s, 0.3, s), mat_floor())                     # walk deck on top

func place_battlements() -> void:
	var d := definition
	var h := d.side * 0.5
	# crenellations on the two OUTER edges (+X, +Z); outer faces on the block edges, deck supports
	merlon_line(Vector3(h, d.height, -h), Vector3(h, d.height, h), Vector3.RIGHT, 0.4)
	merlon_line(Vector3(-h, d.height, h), Vector3(h, d.height, h), Vector3.BACK, 0.4)

func place_snaps() -> void:
	var d := definition
	var s := d.side
	set_snap("WallWalkA", Vector3(-s * 0.5, d.height, 0), Vector3.LEFT)
	set_snap("WallWalkB", Vector3(0, d.height, -s * 0.5), Vector3.FORWARD)

func validate_geometry() -> void:
	pass
