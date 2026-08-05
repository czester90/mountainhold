extends GdUnitTestSuite

const ProjectilePoolScript := preload("res://scripts/core/projectile_pool.gd")

func before_test() -> void:
	_clear_static_pools()

func after_test() -> void:
	_clear_static_pools()

func test_enemy_arrow_reuses_detached_instance() -> void:
	var host: Node3D = auto_free(Node3D.new()) as Node3D
	add_child(host)
	var first: Node = ProjectilePoolScript.acquire_enemy_arrow(host, host)
	assert_object(first.get_parent()).is_same(host)
	first.call("_despawn")
	await await_millis(50)
	assert_object(first.get_parent()).is_null()
	var second: Node = ProjectilePoolScript.acquire_enemy_arrow(host, host)
	assert_object(second).is_same(first)
	assert_object(second.get_parent()).is_same(host)

func test_player_arrow_double_despawn_enqueues_once() -> void:
	var host: Node3D = auto_free(Node3D.new()) as Node3D
	add_child(host)
	var arrow: Node = ProjectilePoolScript.acquire_player_arrow(host, host)
	arrow.call("_despawn")
	arrow.call("_despawn")
	await await_millis(50)
	assert_int(ProjectilePoolScript._player_arrows.size()).is_equal(1)

func _clear_static_pools() -> void:
	for arrow in ProjectilePoolScript._player_arrows:
		if is_instance_valid(arrow):
			arrow.queue_free()
	for arrow in ProjectilePoolScript._enemy_arrows:
		if is_instance_valid(arrow):
			arrow.queue_free()
	ProjectilePoolScript._player_arrows.clear()
	ProjectilePoolScript._enemy_arrows.clear()
