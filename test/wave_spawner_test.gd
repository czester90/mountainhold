extends GdUnitTestSuite

const WaveSpawnerScript := preload("res://scripts/enemy/wave_spawner.gd")

func test_wave_composition_includes_ladder_orcs() -> void:
	var spawner: Node3D = auto_free(Node3D.new())
	spawner.set_script(WaveSpawnerScript)
	spawner.set("auto_start", false)
	add_child(spawner)
	var wave: Array = spawner.call("_wave_kinds", 0, 16)
	assert_bool(wave.has("ladder_crew")).is_true()

func test_later_waves_escalate_ladder_orcs() -> void:
	var spawner: Node3D = auto_free(Node3D.new())
	spawner.set_script(WaveSpawnerScript)
	spawner.set("auto_start", false)
	add_child(spawner)
	var wave: Array = spawner.call("_wave_kinds", 2, 38)
	var count := 0
	for kind in wave:
		if kind == "ladder_crew":
			count += 1
	assert_int(count).is_equal(6)
