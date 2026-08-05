extends GdUnitTestSuite

const MinimapScript := preload("res://scripts/ui/minimap.gd")
const WallScene := preload("res://scenes/castle/wall_segment.tscn")
const TowerScene := preload("res://scenes/castle/tower.tscn")
const EnemyScene := preload("res://scenes/enemy/enemy.tscn")
const RamScene := preload("res://scenes/enemy/enemy_ram.tscn")

func test_minimap_collects_castle_modules_from_scene_tree() -> void:
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	var wall: Node3D = auto_free(WallScene.instantiate())
	root.add_child(wall)
	var tower: Node3D = auto_free(TowerScene.instantiate())
	root.add_child(tower)
	tower.global_position = Vector3(18.0, 0.0, 0.0)
	var minimap: Control = auto_free(MinimapScript.new())
	add_child(minimap)
	minimap.call("setup", root)
	var modules: Array = minimap.get("_castle_modules")
	assert_int(modules.size()).is_equal(2)

func test_minimap_bounds_include_units_and_field_padding() -> void:
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	var wall: Node3D = auto_free(WallScene.instantiate())
	root.add_child(wall)
	wall.global_position = Vector3(300.0, 0.0, 500.0)
	var enemy: Node3D = auto_free(EnemyScene.instantiate())
	add_child(enemy)
	enemy.global_position = Vector3(240.0, 0.0, 500.0)
	var minimap: Control = auto_free(MinimapScript.new())
	add_child(minimap)
	minimap.call("setup", root)
	var bounds_min: Vector2 = minimap.get("_bounds_min")
	assert_float(bounds_min.x).is_less(240.0)

func test_minimap_recognizes_special_enemy_types() -> void:
	var minimap: Control = auto_free(MinimapScript.new())
	add_child(minimap)
	var ram: Node3D = auto_free(RamScene.instantiate())
	add_child(ram)
	assert_bool(ram.is_in_group("ram")).is_true()
	assert_bool(minimap.call("_is_archer", ram)).is_false()

func test_minimap_orients_enemy_approach_from_top() -> void:
	var minimap: Control = auto_free(MinimapScript.new())
	add_child(minimap)
	minimap.size = Vector2(200.0, 200.0)
	minimap.set("_bounds_min", Vector2(240.0, 480.0))
	minimap.set("_bounds_max", Vector2(360.0, 520.0))
	var enemy_field: Vector2 = minimap.call("_world_to_map", Vector3(250.0, 0.0, 500.0))
	var keep_side: Vector2 = minimap.call("_world_to_map", Vector3(350.0, 0.0, 500.0))
	assert_float(enemy_field.y).is_less(keep_side.y)
