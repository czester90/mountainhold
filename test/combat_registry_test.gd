extends GdUnitTestSuite

const CombatRegistryScript := preload("res://scripts/core/combat_registry.gd")

func test_active_enemies_in_group_filters_staged_and_invalid_units() -> void:
	var registry: Node = auto_free(Node.new())
	registry.set_script(CombatRegistryScript)
	add_child(registry)
	var active := _enemy("active", Vector3.ZERO, false)
	var staged := _enemy("staged", Vector3(1.0, 0.0, 0.0), true)
	var sky := _enemy("sky", Vector3(2.0, 200.0, 0.0), false)
	add_child(active)
	add_child(staged)
	add_child(sky)
	active.global_position = Vector3.ZERO
	staged.global_position = Vector3(1.0, 0.0, 0.0)
	sky.global_position = Vector3(2.0, 200.0, 0.0)
	await await_millis(20)
	registry.call("sync_from_groups")
	var carriers: Array = registry.call("active_enemies_in_group", &"ladder_carrier")
	assert_int(carriers.size()).is_equal(1)
	assert_bool(carriers.has(active)).is_true()
	assert_bool(carriers.has(staged)).is_false()
	assert_bool(carriers.has(sky)).is_false()

func _enemy(label: String, position: Vector3, staged: bool) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = position
	node.add_to_group("enemy")
	node.add_to_group("ladder_carrier")
	if staged:
		node.set_meta("staged_waiting", true)
	return auto_free(node)
