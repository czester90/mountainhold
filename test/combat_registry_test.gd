extends GdUnitTestSuite

const CombatRegistryScript := preload("res://scripts/core/combat_registry.gd")

func test_active_enemies_in_group_filters_staged_and_invalid_units() -> void:
	var registry := _registry()
	var active := _enemy("active", Vector3.ZERO, false)
	var staged := _enemy("staged", Vector3(1.0, 0.0, 0.0), true)
	var sky := _enemy("sky", Vector3(2.0, 200.0, 0.0), false)
	_add_units([active, staged, sky])
	await await_millis(20)
	registry.call("sync_from_groups")
	var carriers: Array = registry.call("active_enemies_in_group", &"ladder_carrier")
	assert_int(carriers.size()).is_equal(1)
	assert_bool(carriers.has(active)).is_true()
	assert_bool(carriers.has(staged)).is_false()
	assert_bool(carriers.has(sky)).is_false()

func test_active_enemies_near_uses_flat_radius_across_grid_cells() -> void:
	var registry := _registry()
	var near_same_cell := _enemy("near_same_cell", Vector3(4.0, 50.0, 0.0), false)
	var near_next_cell := _enemy("near_next_cell", Vector3(15.0, 0.0, 0.0), false)
	var outside := _enemy("outside", Vector3(22.0, 0.0, 0.0), false)
	_add_units([near_same_cell, near_next_cell, outside])
	await await_millis(20)
	registry.call("sync_from_groups")
	var result: Array = registry.call("active_enemies_near", Vector3.ZERO, 16.0)
	assert_bool(result.has(near_same_cell)).is_true()
	assert_bool(result.has(near_next_cell)).is_true()
	assert_bool(result.has(outside)).is_false()

func test_active_allies_near_excludes_enemy_team() -> void:
	var registry := _registry()
	var enemy := _enemy("enemy", Vector3(1.0, 0.0, 0.0), false)
	var ally := _ally("ally", Vector3(2.0, 0.0, 0.0))
	_add_units([enemy, ally])
	await await_millis(20)
	registry.call("sync_from_groups")
	var allies: Array = registry.call("active_allies_near", Vector3.ZERO, 5.0)
	var enemies: Array = registry.call("active_enemies_near", Vector3.ZERO, 5.0)
	assert_bool(allies.has(ally)).is_true()
	assert_bool(allies.has(enemy)).is_false()
	assert_bool(enemies.has(enemy)).is_true()
	assert_bool(enemies.has(ally)).is_false()

func test_active_units_near_respects_include_flags_and_player() -> void:
	var registry := _registry()
	var enemy := _enemy("enemy", Vector3(1.0, 0.0, 0.0), false)
	var ally := _ally("ally", Vector3(2.0, 0.0, 0.0))
	var player := _player("player", Vector3(3.0, 0.0, 0.0))
	_add_units([enemy, ally, player])
	await await_millis(20)
	registry.call("sync_from_groups")
	var enemies_only: Array = registry.call("active_units_near", Vector3.ZERO, 5.0, true, false, false)
	assert_bool(enemies_only.has(enemy)).is_true()
	assert_bool(enemies_only.has(ally)).is_false()
	assert_bool(enemies_only.has(player)).is_false()
	var allies_player: Array = registry.call("active_units_near", Vector3.ZERO, 5.0, false, true, true)
	assert_bool(allies_player.has(enemy)).is_false()
	assert_bool(allies_player.has(ally)).is_true()
	assert_bool(allies_player.has(player)).is_true()

func test_spatial_queries_filter_hidden_and_staged_units() -> void:
	var registry := _registry()
	var active := _enemy("active", Vector3(1.0, 0.0, 0.0), false)
	var hidden := _enemy("hidden", Vector3(2.0, 0.0, 0.0), false)
	var staged := _enemy("staged", Vector3(3.0, 0.0, 0.0), true)
	hidden.visible = false
	_add_units([active, hidden, staged])
	await await_millis(20)
	registry.call("sync_from_groups")
	var result: Array = registry.call("active_enemies_near", Vector3.ZERO, 10.0)
	assert_bool(result.has(active)).is_true()
	assert_bool(result.has(hidden)).is_false()
	assert_bool(result.has(staged)).is_false()

func test_register_unregister_updates_spatial_results() -> void:
	var registry := _registry()
	var enemy := _enemy("manual_enemy", Vector3(1.0, 0.0, 0.0), false)
	add_child(enemy)
	await await_millis(20)
	registry.call("register_enemy", enemy)
	assert_bool((registry.call("active_enemies_near", Vector3.ZERO, 5.0) as Array).has(enemy)).is_true()
	registry.call("unregister_enemy", enemy)
	assert_bool((registry.call("active_enemies_near", Vector3.ZERO, 5.0) as Array).has(enemy)).is_false()

func _registry() -> Node:
	var registry: Node = auto_free(Node.new())
	registry.set_script(CombatRegistryScript)
	add_child(registry)
	return registry

func _add_units(units: Array) -> void:
	for unit in units:
		add_child(unit)
		if unit is Node3D:
			(unit as Node3D).global_position = (unit as Node3D).position

func _enemy(label: String, position: Vector3, staged: bool) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = position
	node.add_to_group("enemy")
	node.add_to_group("ladder_carrier")
	if staged:
		node.set_meta("staged_waiting", true)
	return auto_free(node)

func _ally(label: String, position: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = position
	node.add_to_group("ally")
	return auto_free(node)

func _player(label: String, position: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = position
	node.add_to_group("player")
	return auto_free(node)
