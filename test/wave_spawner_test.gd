extends GdUnitTestSuite

const WaveSpawnerScript := preload("res://scripts/enemy/wave_spawner.gd")
const SiegeDirectorScript := preload("res://scripts/enemy/siege_director.gd")

func test_wave_composition_includes_ladder_orcs() -> void:
	var spawner: Node3D = auto_free(WaveSpawnerScript.new())
	spawner.set("auto_start", false)
	add_child(spawner)
	var wave: Array = spawner.call("_wave_kinds", 0, 16)
	assert_bool(wave.has("ladder_crew")).is_true()

func test_later_waves_escalate_ladder_orcs() -> void:
	var spawner: Node3D = auto_free(WaveSpawnerScript.new())
	spawner.set("auto_start", false)
	add_child(spawner)
	var wave: Array = spawner.call("_wave_kinds", 2, 38)
	var count := 0
	for kind in wave:
		if kind == "ladder_crew":
			count += 1
	assert_int(count).is_equal(6)

func test_staged_wave_expands_ladder_crews_into_full_formation() -> void:
	var spawner: Node3D = auto_free(WaveSpawnerScript.new())
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

func test_siege_director_builds_wall_width_assault_sectors() -> void:
	var director: Node3D = auto_free(SiegeDirectorScript.new())
	add_child(director)
	director.call("setup", Vector3(248.0, 0.0, 500.0), Vector3(6.0, 0.0, 30.0), null, null)
	_add_ladder_slot(Vector3(288.0, 0.0, 456.0))
	_add_ladder_slot(Vector3(288.0, 0.0, 484.0))
	_add_ladder_slot(Vector3(288.0, 0.0, 516.0))
	_add_ladder_slot(Vector3(288.0, 0.0, 544.0))

	var sectors: Array = director.call("assault_sectors")

	assert_int(sectors.size()).is_equal(4)
	assert_float((sectors[3]["foot"] as Vector3).z - (sectors[0]["foot"] as Vector3).z).is_greater(80.0)
	assert_str(sectors[0]["name"]).is_equal("wall_sector_00")

func test_siege_director_spawns_from_sector_spread_order() -> void:
	var director: Node3D = auto_free(SiegeDirectorScript.new())
	add_child(director)
	director.call("setup", Vector3(248.0, 0.0, 500.0), Vector3(6.0, 0.0, 30.0), null, null)
	_add_ladder_slot(Vector3(288.0, 0.0, 456.0))
	_add_ladder_slot(Vector3(288.0, 0.0, 484.0))
	_add_ladder_slot(Vector3(288.0, 0.0, 516.0))
	_add_ladder_slot(Vector3(288.0, 0.0, 544.0))

	var first: Vector3 = director.call("next_wide_spawn_point")
	var second: Vector3 = director.call("next_wide_spawn_point")

	assert_float(first.z).is_less(470.0)
	assert_float(second.z).is_greater(530.0)

func test_siege_director_skips_reserved_ladder_sectors() -> void:
	var director: Node3D = auto_free(SiegeDirectorScript.new())
	add_child(director)
	director.call("setup", Vector3(248.0, 0.0, 500.0), Vector3(6.0, 0.0, 30.0), null, null)
	var reserved := _add_ladder_slot(Vector3(288.0, 0.0, 456.0))
	reserved.set_meta("reserved_by", 123)
	_add_ladder_slot(Vector3(288.0, 0.0, 544.0))

	var selected: Node3D = director.call("reserve_ladder_slot")

	assert_vector(selected.get_meta("foot")).is_equal(Vector3(288.0, 0.0, 544.0))

func _add_ladder_slot(foot: Vector3) -> Marker3D:
	var slot: Marker3D = auto_free(Marker3D.new())
	add_child(slot)
	slot.global_position = foot
	slot.set_meta("ladder_surface", &"wall")
	slot.set_meta("foot", foot)
	slot.set_meta("top", foot + Vector3.UP * 8.0)
	slot.set_meta("normal", Vector3(-1.0, 0.0, 0.0))
	slot.add_to_group("castle_ladder_slot")
	return slot
