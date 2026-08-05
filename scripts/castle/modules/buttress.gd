@tool
class_name Buttress
extends CastleModule

## Stepped support pier set against a wall face. Base centre at origin; projects along -Z
## (outward from the wall) and rises in two stepped stages. Positioned by the generator.

@export var definition: ButtressDefinition = ButtressDefinition.new():
	set(value):
		definition = value
		if is_inside_tree():
			rebuild()

func _construct() -> void:
	var d := definition
	var h1 := d.height * 0.6
	var h2 := d.height * 0.4
	add_box(Vector3(0, h1 * 0.5, -d.depth * 0.5), Vector3(d.width, h1, d.depth), mat_stone())
	add_box(Vector3(0, h1 + h2 * 0.5, -d.depth * 0.3), Vector3(d.width, h2, d.depth * 0.6), mat_stone())

func validate_geometry() -> void:
	pass
