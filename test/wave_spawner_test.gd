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

func test_staged_wave_expands_ladder_crews_into_full_formation() -> void:
	var spawner: Node3D = auto_free(Node3D.new())
	spawner.set_script(WaveSpawnerScript)
	spawner.set("auto_start", false)
	add_child(spawner)
	var kinds := ["ladder_crew", "archer", "infantry", "ram"]
	assert_int(spawner.call("_staged_unit_count", kinds)).is_equal(7)
	spawner.set("_staged_spawn_total", 7)
	spawner.set("_staged_spawn_index", 0)
	var first: Vector3 = spawner.call("_next_staging_point")
	for _i in 4:
		spawner.call("_next_staging_point")
	var last: Vector3 = spawner.call("_next_staging_point")
	assert_float(absf(last.z - first.z)).is_greater(40.0)
