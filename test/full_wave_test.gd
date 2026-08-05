extends GdUnitTestSuite

## Full-wave integration test: let wave 1 play out on the real scene. The spawner only advances to
## wave 2 after every wave-1 besieger is dead (its _run waits `while alive > 0`), so reaching
## wave >= 2 proves the defenders (15 allies) cleared the whole wave — and the gate must not fall.

func test_wave_one_is_cleared_by_defenders() -> void:
	var runner := scene_runner("res://scenes/play.tscn")
	await runner.simulate_frames(30)
	await await_millis(3000)                       # terrain + fortress + allies
	var spawner: Node = runner.scene().get_node("WaveSpawner")
	var reached_wave_2 := false
	var saw_enemies := false
	for _i in 55:                                  # up to ~55 s budget
		await await_millis(1000)
		if spawner.call("alive_count") > 0:
			saw_enemies = true
		if int(spawner.call("wave")) >= 2:
			reached_wave_2 = true
			break
		if bool(spawner.call("lost")):
			break
	assert_bool(saw_enemies).is_true()             # a wave actually spawned + marched
	assert_bool(reached_wave_2).is_true()          # wave 1 fully cleared -> advanced
	assert_bool(spawner.call("lost")).is_false()   # gate held
