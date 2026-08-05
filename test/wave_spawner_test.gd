extends GdUnitTestSuite

const WaveSpawnerScript := preload("res://scripts/enemy/wave_spawner.gd")
const SiegeDirectorScript := preload("res://scripts/enemy/siege_director.gd")
const WaveOne := preload("res://data/wave_01.tres")
const WaveFour := preload("res://data/wave_04.tres")

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

func test_wave_definition_resources_match_default_composition() -> void:
	var spawner: Node3D = auto_free(WaveSpawnerScript.new())
	spawner.set("auto_start", false)
	var definitions: Array[Resource] = [WaveOne, WaveFour]
	spawner.set("wave_definitions", definitions)
	add_child(spawner)

	var first_wave: Array = spawner.call("_wave_kinds", 0, 14)
	var final_wave: Array = spawner.call("_wave_kinds", 1, 42)

	assert_int(spawner.call("configured_wave_count")).is_equal(2)
	assert_int(first_wave.count("ladder_crew")).is_equal(4)
	assert_int(first_wave.count("archer")).is_equal(3)
	assert_int(first_wave.count("infantry")).is_equal(7)
	assert_int(final_wave.count("bossram")).is_equal(1)
	assert_int(final_wave.count("ram")).is_equal(2)
	assert_int(final_wave.count("ladder_crew")).is_equal(7)

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

func test_siege_director_assigns_high_level_unit_roles() -> void:
	var director: Node3D = auto_free(SiegeDirectorScript.new())
	add_child(director)
	director.call("setup", Vector3(248.0, 0.0, 500.0), Vector3(6.0, 0.0, 30.0), null, null)
	_add_ladder_slot(Vector3(288.0, 0.0, 456.0))

	var ram_order: Dictionary = director.call("unit_order", "ram", [Vector3.ZERO], 0)
	var archer_order: Dictionary = director.call("unit_order", "archer", [Vector3.ZERO], 0)
	var infantry_order: Dictionary = director.call("unit_order", "infantry", [Vector3.ZERO], 0)

	assert_str(ram_order["role"]).is_equal("gate_engine")
	assert_bool(ram_order["uses_wall_assault"]).is_false()
	assert_str(archer_order["role"]).is_equal("archer_cover")
	assert_bool(archer_order["uses_wall_assault"]).is_true()
	assert_str(infantry_order["role"]).is_equal("wall_assault")

func test_siege_director_builds_ladder_crew_orders() -> void:
	var director: Node3D = auto_free(SiegeDirectorScript.new())
	add_child(director)
	director.call("setup", Vector3(248.0, 0.0, 500.0), Vector3(6.0, 0.0, 30.0), null, null)
	var slot := _add_ladder_slot(Vector3(288.0, 0.0, 544.0))

	var plan: Dictionary = director.call("ladder_crew_plan", 77)
	var carrier: Dictionary = director.call("ladder_carrier_order", plan, 0)
	var escort: Dictionary = director.call("ladder_escort_order", plan, 1)

	assert_int(slot.get_meta("reserved_by")).is_equal(77)
	assert_str(carrier["role"]).is_equal("ladder_carrier")
	assert_int(carrier["crew_id"]).is_equal(77)
	assert_str(escort["role"]).is_equal("ladder_escort")
	assert_vector(escort["cover_foot"]).is_not_equal(Vector3.INF)

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
