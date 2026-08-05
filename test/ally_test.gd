extends GdUnitTestSuite

## Characterization tests for the ally archer — lock targeting + stats before extracting a
## TargetingComponent. Isolated: no world geometry, so line-of-sight is always clear.

const Ally := preload("res://scenes/ally/ally_archer.tscn")
const Enemy := preload("res://scenes/enemy/enemy.tscn")
const Ram := preload("res://scenes/enemy/enemy_ram.tscn")
const DefenderTargetingScript := preload("res://scripts/ally/defender_targeting.gd")

func test_default_stats() -> void:
	var a: Node3D = auto_free(Ally.instantiate())
	add_child(a)
	await await_millis(30)
	assert_float(a.fire_interval).is_equal(2.2)
	assert_float(a.arrow_speed).is_equal(58.0)
	assert_float(a.range).is_equal(70.0)
	assert_float(a.arrow_damage).is_equal(25.0)
	assert_float(a.melee_damage).is_equal(4.0)
	assert_str(str(a.type_id)).is_equal("ally_archer")
	assert_bool(a.behavior_tags.has("wall")).is_true()
	assert_float(a.get("_target_decision_interval")).is_equal(0.45)
	assert_float(a.defense).is_equal(0.5)
	assert_float(a.armor).is_equal(0.08)

func test_archer_uses_character_body_navigation_foundation() -> void:
	var a: Node3D = auto_free(Ally.instantiate())
	add_child(a)
	await await_millis(30)
	assert_bool(a is CharacterBody3D).is_true()
	assert_object(a.get_node_or_null("NavigationAgent3D")).is_not_null()
	assert_str(str(a.navigation_debug_driver())).is_equal("fallback")
	for child in a.get_children():
		assert_bool(child is StaticBody3D).is_false()

func test_levels_after_fifth_kill_and_scales_combat_stats() -> void:
	var a: Node3D = auto_free(Ally.instantiate())
	add_child(a)
	var e: CharacterBody3D = auto_free(Enemy.instantiate())
	add_child(e)
	await await_millis(30)
	a.kills = 4
	e.take_damage(1000.0)
	a._on_arrow_hit(e)
	assert_int(a.kills).is_equal(5)
	assert_int(a.level).is_equal(2)
	assert_float(a.arrow_damage).is_equal_approx(27.5, 0.001)
	assert_float(a.melee_damage).is_equal(4.4)
	assert_float(a.range).is_equal_approx(77.0, 0.001)
	assert_float(a.defense).is_equal(0.55)
	assert_float(a.armor).is_equal_approx(0.088, 0.001)

func test_acquires_enemy_in_range() -> void:
	var a: Node3D = auto_free(Ally.instantiate())
	add_child(a)
	a.global_position = Vector3.ZERO
	var e: CharacterBody3D = auto_free(Enemy.instantiate())
	add_child(e)
	e.global_position = Vector3(12, 0, 0)          # inside range 70, clear LOS
	await await_millis(50)
	var target: Node = a._acquire()
	assert_object(target).is_same(e)

func test_defender_targeting_keeps_recent_target_without_order_change() -> void:
	var targeting: TargetingComponent = auto_free(TargetingComponent.new())
	var brain: Node = auto_free(DefenderTargetingScript.new())
	var archer: Node3D = auto_free(Node3D.new())
	var first: CharacterBody3D = auto_free(Enemy.instantiate())
	var second: CharacterBody3D = auto_free(Enemy.instantiate())
	add_child(brain)
	add_child(archer)
	add_child(first)
	add_child(second)
	archer.global_position = Vector3.ZERO
	first.global_position = Vector3(12.0, 0.0, 0.0)
	second.global_position = Vector3(40.0, 0.0, 0.0)
	await await_millis(30)

	var first_result: Dictionary = brain.call("acquire", archer, targeting, 0, 70.0, Vector3.ZERO)
	second.global_position = Vector3(11.0, 0.0, 0.0)
	var second_result: Dictionary = brain.call("acquire", archer, targeting, 0, 70.0, Vector3.ZERO)

	assert_object(first_result["target"]).is_same(first)
	assert_object(second_result["target"]).is_same(first)

func test_ignores_enemy_out_of_range() -> void:
	var a: Node3D = auto_free(Ally.instantiate())
	add_child(a)
	a.global_position = Vector3.ZERO
	var e: CharacterBody3D = auto_free(Enemy.instantiate())
	add_child(e)
	e.global_position = Vector3(200, 0, 0)         # beyond range 70
	await await_millis(50)
	assert_object(a._acquire()).is_null()

func test_gate_defender_forces_damage_on_enemy_at_gate() -> void:
	var a: Node3D = auto_free(Ally.instantiate())
	add_child(a)
	a.global_position = Vector3(284.5, 21.0, 500.0)
	var e: CharacterBody3D = auto_free(Enemy.instantiate())
	add_child(e)
	e.global_position = Vector3(285.0, 16.0, 500.0)
	await await_millis(50)
	a.arrow_damage = 80.0
	a._last_forced_gate_threat = true
	a._shoot_at(e)
	await await_millis(500)
	assert_bool(e.hp <= 0.0).is_true()
	assert_int(a.kills).is_greater_equal(1)

func test_gate_defender_hits_ram_weak_spot() -> void:
	var a: Node3D = auto_free(Ally.instantiate())
	add_child(a)
	a.global_position = Vector3(284.5, 21.0, 500.0)
	var ram: CharacterBody3D = auto_free(Ram.instantiate())
	add_child(ram)
	ram.global_position = Vector3(285.0, 16.0, 500.0)
	await await_millis(50)
	var before: float = ram.hp
	a._last_forced_gate_threat = true
	a._shoot_at(ram)
	await await_millis(500)
	assert_float(ram.hp).is_less(before - 70.0)

func test_gate_defender_moves_to_wall_edge() -> void:
	_add_test_floor(Vector3(286.5, 26.95, 500.0), Vector3(10.0, 0.1, 14.0))
	var a: Node3D = auto_free(Ally.instantiate())
	add_child(a)
	a.global_position = Vector3(289.0, 27.0, 500.0)
	var e: CharacterBody3D = auto_free(Enemy.instantiate())
	add_child(e)
	e.global_position = Vector3(278.0, 16.0, 500.0)
	await await_millis(50)
	a._current_target = e
	a._move_to_gate_edge(1.0)
	assert_float(a.global_position.x).is_less(289.0)
	assert_float(a.global_position.y).is_equal_approx(27.0, 0.05)

func test_gate_roof_order_goes_directly_to_front_edge() -> void:
	var a: Node3D = auto_free(Ally.instantiate())
	add_child(a)
	a.global_position = Vector3(290.0, 27.0, 494.0)
	await await_millis(30)
	a.set_defender_order(AllyArcher.ORDER_DEFEND_GATE, Vector3(284.2, 27.0, 500.0))
	var path: Array = a.get("_nav_path")
	assert_int(path.size()).is_equal(1)
	assert_vector(path[0]).is_equal(Vector3(284.2, 27.0, 500.0))

func test_gate_threat_forces_archer_to_edge_even_with_target() -> void:
	_add_test_floor(Vector3(286.5, 26.95, 500.0), Vector3(10.0, 0.1, 14.0))
	var a: Node3D = auto_free(Ally.instantiate())
	add_child(a)
	a.global_position = Vector3(290.0, 27.0, 500.0)
	var e: CharacterBody3D = auto_free(Enemy.instantiate())
	add_child(e)
	e.global_position = Vector3(285.0, 16.0, 500.0)
	await await_millis(50)
	a._last_forced_gate_threat = true
	a._reposition_for_target(1.0, e)
	assert_float(a.global_position.x).is_less(290.0)
	assert_bool(a.get("_last_has_los")).is_false()

func test_order_rally_does_not_move_without_floor() -> void:
	var a: Node3D = auto_free(Ally.instantiate())
	add_child(a)
	a.global_position = Vector3(289.0, 27.0, 500.0)
	await await_millis(30)
	a.set_defender_order(AllyArcher.ORDER_DEFEND_GATE, Vector3(284.0, 27.0, 500.0))
	a._move_to_order_rally(1.0)
	assert_vector(a.global_position).is_equal(Vector3(289.0, 27.0, 500.0))

func test_retreat_from_gate_roof_routes_through_courtyard() -> void:
	var a: Node3D = auto_free(Ally.instantiate())
	add_child(a)
	a.global_position = Vector3(290.0, 27.0, 500.0)
	await await_millis(30)
	a.set_defender_order(AllyArcher.ORDER_RETREAT_KEEP, Vector3(345.0, 32.0, 500.0))
	var path: Array = a.get("_nav_path")
	assert_bool(path.has(Vector3(312.0, 19.0, 490.0))).is_true()
	assert_bool(path.has(Vector3(330.0, 21.0, 495.0))).is_true()
	assert_vector(path.back()).is_equal(Vector3(345.0, 32.0, 500.0))

func test_retreat_uses_dynamic_navigation_graph_when_present() -> void:
	var a: Node3D = auto_free(Ally.instantiate())
	add_child(a)
	a.global_position = Vector3(10.0, 10.0, 0.0)
	_add_navigation_edge(Vector3(10.0, 10.0, 0.0), Vector3(16.0, 10.0, 3.0))
	_add_navigation_edge(Vector3(16.0, 10.0, 3.0), Vector3(22.0, 10.0, 0.0))
	await await_millis(30)
	a.set_defender_order(AllyArcher.ORDER_RETREAT_KEEP, Vector3(22.0, 10.0, 0.0))
	var path: Array = a.get("_nav_path")
	assert_bool(path.has(Vector3(16.0, 10.0, 3.0))).is_true()
	assert_vector(path.back()).is_equal(Vector3(22.0, 10.0, 0.0))

func test_retreat_uses_vertical_navigation_edges() -> void:
	var a: Node3D = auto_free(Ally.instantiate())
	add_child(a)
	a.global_position = Vector3(0.0, 0.0, 0.0)
	_add_navigation_edge(Vector3(0.0, 0.0, 0.0), Vector3(0.0, 6.0, 0.0))
	_add_navigation_edge(Vector3(0.0, 6.0, 0.0), Vector3(10.0, 6.0, 0.0))
	await await_millis(30)
	a.set_defender_order(AllyArcher.ORDER_RETREAT_KEEP, Vector3(10.0, 6.0, 0.0))
	var path: Array = a.get("_nav_path")
	assert_bool(path.has(Vector3(0.0, 6.0, 0.0))).is_true()
	assert_vector(path.back()).is_equal(Vector3(10.0, 6.0, 0.0))

func test_archer_separation_detects_nearby_ally() -> void:
	var a: Node3D = auto_free(Ally.instantiate())
	add_child(a)
	a.global_position = Vector3.ZERO
	var b: Node3D = auto_free(Ally.instantiate())
	add_child(b)
	b.global_position = Vector3(0.2, 0.0, 0.0)
	await await_millis(30)
	var push: Vector3 = a.call("_separation_vector", a.global_position)
	assert_float(push.length()).is_greater(0.0)

func test_archer_repositions_after_arrow_hits_wall() -> void:
	var a: Node3D = auto_free(Ally.instantiate())
	add_child(a)
	await await_millis(30)
	var wall: StaticBody3D = auto_free(StaticBody3D.new())
	wall.add_to_group("wall")
	add_child(wall)
	a._on_arrow_hit(wall)
	assert_float(a.get("_bad_shot_reposition_t")).is_greater(0.0)

func _add_test_floor(pos: Vector3, size: Vector3) -> StaticBody3D:
	var floor: StaticBody3D = auto_free(StaticBody3D.new())
	floor.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	floor.add_child(shape)
	add_child(floor)
	floor.global_position = pos
	return floor

func _add_navigation_edge(a: Vector3, b: Vector3) -> Node3D:
	var edge: Node3D = auto_free(Node3D.new())
	edge.add_to_group("castle_navigation_edge")
	edge.set_meta("nav_a", a)
	edge.set_meta("nav_b", b)
	add_child(edge)
	return edge
