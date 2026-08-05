extends GdUnitTestSuite

## Unit tests for the extracted components — pure logic, no scene needed (the payoff of the refactor).

func test_health_damage_and_death() -> void:
	var h: HealthComponent = auto_free(HealthComponent.new())
	add_child(h)
	h.setup(50.0)
	assert_float(h.hp).is_equal(50.0)
	assert_bool(h.is_alive()).is_true()
	var died := [false]
	h.died.connect(func(): died[0] = true)
	h.take_damage(20.0)
	assert_float(h.hp).is_equal(30.0)
	h.take_damage(100.0)
	assert_bool(h.is_alive()).is_false()
	assert_bool(died[0]).is_true()

func test_health_ignores_damage_when_dead() -> void:
	var h: HealthComponent = auto_free(HealthComponent.new())
	add_child(h)
	h.setup(10.0)
	h.take_damage(10.0)
	var count := [0]
	h.died.connect(func(): count[0] += 1)
	h.take_damage(5.0)                       # already dead -> no further death signal
	assert_int(count[0]).is_equal(0)

func test_health_applies_defense_and_armor() -> void:
	var h: HealthComponent = auto_free(HealthComponent.new())
	add_child(h)
	h.setup(100.0, 2.0, 0.25)
	var dealt := h.take_damage(42.0)
	assert_float(dealt).is_equal(30.0)
	assert_float(h.hp).is_equal(70.0)

func test_unit_stats_level_thresholds_double() -> void:
	assert_int(UnitStats.level_for_kills(1, 4)).is_equal(1)
	assert_int(UnitStats.level_for_kills(1, 5)).is_equal(2)
	assert_int(UnitStats.level_for_kills(1, 10)).is_equal(3)
	assert_int(UnitStats.level_for_kills(1, 19)).is_equal(3)
	assert_int(UnitStats.level_for_kills(1, 20)).is_equal(4)
	assert_float(UnitStats.stat_multiplier(1, 4)).is_equal_approx(1.3, 0.001)

func test_attack_fires_on_interval() -> void:
	var a: AttackComponent = auto_free(AttackComponent.new())
	add_child(a)
	a.setup(6.0, 1.0)
	var hits := [0]
	a.attacked.connect(func(_d): hits[0] += 1)
	a.tick(0.0)                              # first tick fires immediately
	assert_int(hits[0]).is_equal(1)
	a.tick(0.5)                              # 0.5 < 1.0 -> no
	assert_int(hits[0]).is_equal(1)
	a.tick(0.6)                              # cumulative 1.1 >= 1.0 -> fires
	assert_int(hits[0]).is_equal(2)
