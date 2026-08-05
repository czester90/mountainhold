extends GdUnitTestSuite

func test_fortress_registers_navigation_without_extra_podests() -> void:
	var runner := scene_runner("res://scenes/play.tscn")
	await runner.simulate_frames(30)
	await await_millis(3500)
	var tree := runner.scene().get_tree()
	var nav_edges := tree.get_nodes_in_group("castle_navigation_edge")
	var nav_links := tree.get_nodes_in_group("castle_navigation_link")
	var nav_regions := tree.get_nodes_in_group("castle_navigation_region")
	assert_int(nav_edges.size()).is_greater_equal(14)
	assert_int(nav_links.size()).is_greater_equal(nav_edges.size())
	assert_int(nav_regions.size()).is_equal(1)
	assert_object((nav_regions[0] as NavigationRegion3D).navigation_mesh).is_not_null()
	for node in nav_links:
		assert_bool(node is NavigationLink3D).is_true()
	for node in nav_edges:
		assert_bool(str(node.name).contains("RetreatWalkway")).is_false()
