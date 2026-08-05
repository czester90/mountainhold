extends GdUnitTestSuite

const Player := preload("res://scripts/player/fps_bow_player.gd")
const Enemy := preload("res://scenes/enemy/enemy.tscn")

func test_player_levels_after_fifth_kill_and_scales_combat_stats() -> void:
	var p: CharacterBody3D = auto_free(Player.new())
	p._apply_stats()
	assert_bool(p.behavior_tags.has("hero")).is_true()
	var e: CharacterBody3D = auto_free(Enemy.instantiate())
	add_child(e)
	await await_millis(30)
	p.kills = 4
	e.take_damage(1000.0)
	p._on_arrow_hit(e)
	assert_int(p.kills).is_equal(5)
	assert_int(p.level).is_equal(2)
	assert_int(p.xp).is_equal(10)
	assert_float(p.arrow_damage).is_equal_approx(60.5, 0.001)
	assert_float(p.melee_damage).is_equal_approx(6.6, 0.001)
	assert_float(p.defense).is_equal_approx(1.1, 0.001)
	assert_float(p.armor).is_equal_approx(0.132, 0.001)
	assert_float(p.max_arrow_speed).is_equal_approx(66.0, 0.001)
