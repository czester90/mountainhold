extends GdUnitTestSuite

func test_fortress_registers_navigation_without_extra_podests() -> void:
	var runner := scene_runner("res://scenes/play.tscn")
	await runner.simulate_frames(30)
	await await_millis(3500)
	var tree := runner.scene().get_tree()
	var nav_edges := tree.get_nodes_in_group("castle_navigation_edge")
	var nav_links := tree.get_nodes_in_group("castle_navigation_link")
	var nav_regions := tree.get_nodes_in_group("castle_navigation_region")
	var model := tree.get_first_node_in_group("castle_model")
	assert_int(nav_edges.size()).is_greater_equal(14)
	assert_int(nav_links.size()).is_greater_equal(nav_edges.size())
	assert_int(nav_regions.size()).is_equal(1)
	assert_object(model).is_not_null()
	assert_int((model.call("summary") as Dictionary)["regions"]).is_greater_equal(6)
	assert_bool((model.call("region", &"staging_horizon") as Dictionary).has("center")).is_true()
	assert_bool((model.call("region", &"wall_front") as Dictionary).has("metadata")).is_true()
	var validator := SceneValidator.new()
	var issues: Array = validator.validate_model(model)
	assert_array(issues).override_failure_message("Fortress model issues: %s" % str(issues)).is_empty()
	assert_object((nav_regions[0] as NavigationRegion3D).navigation_mesh).is_not_null()
	for node in nav_links:
		assert_bool(node is NavigationLink3D).is_true()
	for node in nav_edges:
		assert_bool(str(node.name).contains("RetreatWalkway")).is_false()

func test_fortress_navigation_routes_key_assault_scenarios() -> void:
	var runner := scene_runner("res://scenes/play.tscn")
	await runner.simulate_frames(30)
	await await_millis(3500)
	var scene := runner.scene()
	var model := scene.get_tree().get_first_node_in_group("castle_model")
	assert_object(model).is_not_null()
	var pathfinder := CastlePathfinder.new()
	scene.add_child(pathfinder)
	var ladder_slot := _nearest_slot(model.call("wall_ladder_slots"), Vector3(290.0, 21.0, 520.0))
	var gate_slot := _nearest_slot(model.call("gate_slots"), Vector3(284.0, 27.0, 500.0))
	var keep_slot := _nearest_slot(model.call("keep_slots"), Vector3(362.0, 44.0, 500.0))
	var tower_slot := _nearest_slot(model.call("archer_slots"), Vector3(299.0, 27.0, 532.0))
	assert_object(ladder_slot).is_not_null()
	assert_object(gate_slot).is_not_null()
	assert_object(keep_slot).is_not_null()
	assert_object(tower_slot).is_not_null()
	_assert_route(pathfinder, scene, ladder_slot.get_meta("foot"), ladder_slot.get_meta("top"), "ground-to-ladder")
	_assert_route(pathfinder, scene, ladder_slot.get_meta("top"), tower_slot.global_position, "wall-to-tower")
	_assert_route(pathfinder, scene, ladder_slot.get_meta("top"), gate_slot.global_position, "wall-to-gate")
	_assert_route(pathfinder, scene, gate_slot.global_position, keep_slot.global_position, "gate-to-keep")
	_assert_route(pathfinder, scene, ladder_slot.get_meta("top"), keep_slot.global_position, "wall-to-keep")

func _nearest_slot(slots: Array, point: Vector3) -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	for slot in slots:
		if not slot is Node3D or not is_instance_valid(slot):
			continue
		var slot_node := slot as Node3D
		var distance := slot_node.global_position.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = slot_node
	return best

func _assert_route(pathfinder: CastlePathfinder, context: Node, start: Vector3, target: Vector3, label: String) -> void:
	var route: Array[Vector3] = pathfinder.route(context, start, target)
	assert_int(route.size()).override_failure_message("%s route missing from %s to %s" % [label, str(start), str(target)]).is_greater(0)
	assert_bool(route.back().distance_to(target) <= 0.75).override_failure_message("%s route ended at %s, expected %s" % [label, str(route.back()), str(target)]).is_true()
