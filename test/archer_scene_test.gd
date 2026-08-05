extends GdUnitTestSuite

## Isolated integration test for the archer combat loop on test/scenes/archer_range.tscn:
## a stationary enemy in range must be shot dead by the ally within a few volleys.

func test_archer_kills_stationary_enemy() -> void:
	var runner := scene_runner("res://test/scenes/archer_range.tscn")
	await runner.simulate_frames(5)
	assert_int(runner.invoke("enemies_alive")).is_equal(1)   # target present at start
	await await_millis(9000)                                 # ~4 volleys @ 2.2s, arrow dmg 55 vs hp 100
	assert_int(runner.invoke("enemies_alive")).is_equal(0)   # archer killed it

func test_archer_ignores_when_no_target() -> void:
	var runner := scene_runner("res://test/scenes/archer_range.tscn")
	await runner.simulate_frames(5)
	_free_enemies(runner.scene())
	await runner.simulate_frames(10)
	assert_int(runner.invoke("enemies_alive")).is_equal(0)   # nothing to shoot, no crash

func _free_enemies(node: Node) -> void:
	if node.is_in_group("enemy"):
		node.queue_free()
	for child in node.get_children():
		_free_enemies(child)
