extends GdUnitTestSuite

## Characterization tests for the besieger — lock CURRENT behaviour before the stats->Resource +
## Health/Targeting/Attack component refactor, so the refactor stays green. Isolated (no terrain):
## take_damage/death need no physics; the gate-attack emits on cooldown even while falling.

const Enemy := preload("res://scenes/enemy/enemy.tscn")
const LadderOrc := preload("res://scenes/enemy/enemy_ladder_orc.tscn")
const Ram := preload("res://scenes/enemy/enemy_ram.tscn")
const SiegeLadder := preload("res://scenes/enemy/siege_ladder.tscn")

func _spawn() -> CharacterBody3D:
	var e: CharacterBody3D = auto_free(Enemy.instantiate())
	add_child(e)
	return e

func test_default_stats() -> void:
	var e := _spawn()
	await await_millis(30)
	assert_float(e.hp).is_equal(e.max_hp)
	assert_float(e.max_hp).is_equal(100.0)
	assert_float(e.speed).is_equal(2.0)
	assert_float(e.attack_damage).is_equal(3.0)
	assert_str(str(e.type_id)).is_equal("enemy_infantry")
	assert_int(e.level).is_equal(1)
	assert_float(e.defense).is_equal(1.0)
	assert_float(e.armor).is_equal(0.05)
	assert_bool(e.is_in_group("enemy")).is_true()
	assert_bool((e.collision_mask & (1 << 1)) != 0).is_true()
	assert_bool((e.collision_mask & (1 << 3)) != 0).is_true()

func test_takes_damage() -> void:
	var e := _spawn()
	await await_millis(30)
	e.take_damage(30.0)
	assert_float(e.hp).is_equal_approx(72.45, 0.01)

func test_dies_and_emits_signal() -> void:
	var e := _spawn()
	await await_millis(30)
	var died := [false]
	e.died.connect(func(_x): died[0] = true)
	e.take_damage(1000.0)
	assert_bool(died[0]).is_true()

func test_humanoid_does_not_attack_gate_when_in_range() -> void:
	var e := _spawn()
	e.global_position = Vector3.ZERO
	e.setup_path([Vector3.ZERO, Vector3(1.0, 0.0, 0.0)], null, 0)
	var hits := [0]
	e.hit_gate.connect(func(_amount): hits[0] += 1)
	await await_millis(300)
	assert_int(hits[0]).is_equal(0)

func test_ram_attacks_gate_when_in_range() -> void:
	var e: CharacterBody3D = auto_free(Ram.instantiate())
	add_child(e)
	e.global_position = Vector3.ZERO
	e.setup_path([Vector3.ZERO, Vector3(1.0, 0.0, 0.0)], null, 0)
	var hits := [0]
	e.hit_gate.connect(func(_amount): hits[0] += 1)
	await await_millis(300)
	assert_int(hits[0]).is_greater(0)

func test_ladder_orc_stats_and_group() -> void:
	var e: CharacterBody3D = auto_free(LadderOrc.instantiate())
	add_child(e)
	await await_millis(30)
	assert_str(str(e.type_id)).is_equal("enemy_ladder_orc")
	assert_bool(e.is_in_group("ladder")).is_true()
	assert_float(e.max_hp).is_equal(125.0)
	assert_float(e.speed).is_equal(3.2)
	assert_float(e.attack_damage).is_equal(11.0)
	assert_float(e.defense).is_equal(1.5)
	assert_float(e.armor).is_equal(0.1)

func test_ladder_orc_carry_setup_requires_crew_deployment() -> void:
	var e: CharacterBody3D = auto_free(LadderOrc.instantiate())
	add_child(e)
	await await_millis(30)
	e.setup_ladder_carry(7, 0, Vector3(288.0, 0.0, 492.0), Vector3(294.0, 22.0, 492.0), Vector3(-1.0, 0.0, 0.0), null, Vector3(252.0, 0.0, 492.0))
	assert_bool(e.is_in_group("ladder_carrier")).is_true()
	assert_int(e.get_meta("crew_id")).is_equal(7)
	assert_float(e.max_hp).is_greater_equal(275.0)
	assert_float(e.defense).is_greater_equal(4.0)
	assert_float(e.armor).is_greater_equal(0.34)
	assert_int(e.get("path").size()).is_equal(2)
	assert_int(get_tree().get_nodes_in_group("siege_ladder_active").size()).is_equal(0)

func test_ladder_orc_carry_pair_moves_fast_and_solo_slows() -> void:
	var a: CharacterBody3D = auto_free(LadderOrc.instantiate())
	var b: CharacterBody3D = auto_free(LadderOrc.instantiate())
	add_child(a)
	add_child(b)
	await await_millis(30)
	var foot := Vector3(288.0, 0.0, 492.0)
	var top := Vector3(294.0, 22.0, 492.0)
	var normal := Vector3(-1.0, 0.0, 0.0)
	a.setup_ladder_carry(8, 0, foot, top, normal, null, Vector3(252.0, 0.0, 492.0))
	b.setup_ladder_carry(8, 1, foot, top, normal, null, Vector3(252.0, 0.0, 492.0))
	a.call("_update_carrying_speed")
	b.call("_update_carrying_speed")
	assert_float(a.speed).is_equal(2.55)
	assert_float(b.speed).is_equal(2.55)
	a.take_damage(1000.0)
	b.call("_update_carrying_speed")
	assert_float(b.speed).is_equal(1.45)

func test_enemy_ai_debug_snapshot_reports_objective_and_recovery() -> void:
	var e := _spawn()
	await await_millis(30)
	e.setup_path([Vector3.ZERO, Vector3(4.0, 0.0, 0.0)], null, -1)
	e.call("_unstick_forward", Vector3.FORWARD)
	var snapshot: Dictionary = e.call("ai_debug_snapshot")
	assert_str(snapshot["state"]).is_equal("advancing")
	assert_int(snapshot["state_id"]).is_equal(e.call("ai_state"))
	assert_int(snapshot["waypoint"]).is_equal(0)
	assert_int(snapshot["path_size"]).is_equal(2)
	assert_str(snapshot["last_recovery"]).is_equal("stuck_unstick")
	assert_bool((snapshot["objective"] as Dictionary).has("current")).is_true()
	assert_bool(snapshot.has("wall_brain")).is_true()
	assert_bool(snapshot.has("ladder_brain")).is_true()

func test_ladder_debug_status_reports_unit_reservations() -> void:
	var e := _spawn()
	var ladder: Node3D = auto_free(SiegeLadder.instantiate())
	add_child(ladder)
	await await_millis(30)
	ladder.call("deploy", Vector3.ZERO, Vector3(3.0, 8.0, 0.0), Vector3.FORWARD)
	assert_bool(ladder.call("reserve_entry", e)).is_true()
	var status: Dictionary = ladder.call("debug_unit_status", e)
	assert_bool(status["deployed"]).is_true()
	assert_bool(status["unit_entry_reserved"]).is_true()
	assert_bool(status["unit_climbing"]).is_false()
	assert_int(status["entry_reservations"]).is_equal(1)
	assert_int(status["unit_climb_slot"]).is_equal(-1)
	assert_bool(ladder.call("reserve_climb", e)).is_true()
	e.set("_climbing_ladder", true)
	status = ladder.call("debug_unit_status", e)
	assert_bool(status["unit_climbing"]).is_true()
	assert_bool(status["unit_entry_reserved"]).is_false()
	assert_int(status["active_climbers"]).is_equal(1)

func test_ladder_orc_ai_debug_snapshot_reports_crew_state() -> void:
	var e: CharacterBody3D = auto_free(LadderOrc.instantiate())
	add_child(e)
	await await_millis(30)
	e.setup_ladder_carry(11, 1, Vector3(288.0, 0.0, 492.0), Vector3(294.0, 22.0, 492.0), Vector3(-1.0, 0.0, 0.0), null, Vector3(252.0, 0.0, 492.0))
	var snapshot: Dictionary = e.call("ai_debug_snapshot")
	assert_str(snapshot["state"]).is_equal("carrying_ladder")
	assert_int(snapshot["state_id"]).is_equal(e.call("ai_state"))
	assert_bool((snapshot["crew"] as Dictionary).has("id")).is_true()
	assert_int(snapshot["crew"]["id"]).is_equal(11)
	assert_bool(snapshot["crew"]["carrying"]).is_true()

func test_enemy_avoidance_changes_direction_near_unit() -> void:
	var a := _spawn()
	var b := _spawn()
	a.global_position = Vector3.ZERO
	b.global_position = Vector3(0.2, 0.0, 0.0)
	await await_millis(30)
	var adjusted: Vector3 = a.call("_avoidance_direction", Vector3.FORWARD)
	assert_float(adjusted.x).is_less(0.0)
