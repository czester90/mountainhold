extends GdUnitTestSuite

## Runs SceneValidator against the built fortress — asserts no structural gaps/holes (regression
## guard for the gate<->wall seam and any future floating/void geometry).

func test_fortress_has_no_structural_gaps() -> void:
	var runner := scene_runner("res://scenes/play.tscn")
	await runner.simulate_frames(30)
	await await_millis(3500)                       # terrain + fortress collision ready
	var space: PhysicsDirectSpaceState3D = (runner.scene() as Node3D).get_world_3d().direct_space_state
	var validator := SceneValidator.new()
	var issues: Array = validator.validate(space)
	assert_array(issues).override_failure_message("Structural issues: %s" % str(issues)).is_empty()
