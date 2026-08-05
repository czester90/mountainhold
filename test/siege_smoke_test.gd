extends GdUnitTestSuite

## Integration smoke tests for the whole siege scene via GdUnit4's scene_runner (replaces the
## hand-rolled mechanics_test driver). Locks: the fortress builds, the player fires arrows, and the
## gate-HP / win-loss logic behaves — the seams the wave/component refactor will touch.

const ARROW_PATH := "res://scripts/player/arrow.gd"
const WALL_SEGMENT_PATH := "res://scripts/castle/modules/wall_segment.gd"

func _arrow_count(root: Node) -> int:
	var n := 0
	for c in root.get_children():
		if c.get_script() and c.get_script().resource_path == ARROW_PATH:
			n += 1
	return n

func test_scene_builds_with_core_nodes() -> void:
	var runner := scene_runner("res://scenes/play.tscn")
	await runner.simulate_frames(60)
	await await_millis(4000)                 # terrain + fortress + allies
	var scene := runner.scene()
	assert_object(scene.get_node_or_null("Player")).is_not_null()
	assert_object(scene.get_node_or_null("WaveSpawner")).is_not_null()
	assert_object(scene.get_node_or_null("HUD")).is_not_null()
	var fort: Node = scene.get_node("Fortress")
	assert_int(_count_meshes(fort)).is_greater(50)  # fortress geometry was generated
	assert_int(_count_mountain_sally_ports(fort)).is_equal(1)
	assert_int(_count_outer_gate_sally_ports(fort)).is_equal(0)
	assert_int(_count_gate_allies(scene)).is_greater_equal(3)
	assert_int(_count_tower_allies(scene)).is_greater_equal(4)

func test_player_fire_spawns_arrow() -> void:
	var runner := scene_runner("res://scenes/play.tscn")
	await runner.simulate_frames(60)
	await await_millis(3500)
	var scene := runner.scene()
	var player: CharacterBody3D = scene.get_node("Player")
	var before := _arrow_count(scene)
	player.set("_draw_t", 1.0)
	player.call("_fire")
	await runner.simulate_frames(2)
	assert_int(_arrow_count(scene)).is_greater(before)

func test_gate_hp_decreases_and_keep_loss() -> void:
	var runner := scene_runner("res://scenes/play.tscn")
	await runner.simulate_frames(30)
	await await_millis(3000)
	var spawner: Node = runner.scene().get_node("WaveSpawner")
	var before: float = spawner.call("gate_fraction")
	spawner.call("_on_hit_gate", 20.0)
	assert_float(spawner.call("gate_fraction")).is_less(before)
	assert_bool(spawner.call("lost")).is_false()
	spawner.call("_on_hit_gate", 100000.0)          # overkill -> gate falls, but the castle still stands
	assert_bool(spawner.call("gate_open")).is_true()
	assert_bool(spawner.call("lost")).is_false()
	spawner.call("_on_hit_keep", 100000.0)          # overkill -> keep falls
	assert_bool(spawner.call("lost")).is_true()

func _count_meshes(n: Node) -> int:
	var c := 1 if n is MeshInstance3D else 0
	for ch in n.get_children():
		c += _count_meshes(ch)
	return c

func _count_mountain_sally_ports(n: Node) -> int:
	var c := 0
	var script: Script = n.get_script()
	if script and script.resource_path == WALL_SEGMENT_PATH and n.get("sally_port") == true:
		if absf(n.global_position.z - 500.0) > 30.0:
			c += 1
	for ch in n.get_children():
		c += _count_mountain_sally_ports(ch)
	return c

func _count_outer_gate_sally_ports(n: Node) -> int:
	var c := 0
	var script: Script = n.get_script()
	if script and script.resource_path == WALL_SEGMENT_PATH and n.get("sally_port") == true:
		if n.global_position.x < 315.0 and absf(n.global_position.z - 500.0) <= 30.0:
			c += 1
	for ch in n.get_children():
		c += _count_outer_gate_sally_ports(ch)
	return c

func _count_gate_allies(n: Node) -> int:
	var c := 0
	var script: Script = n.get_script()
	if n is Node3D and (n.is_in_group("ally") or (script and script.resource_path.ends_with("ally_archer.gd"))):
		var p: Vector3 = (n as Node3D).global_position
		if p.x >= 283.0 and p.x <= 296.0 and p.z >= 492.0 and p.z <= 508.0:
			c += 1
	for ch in n.get_children():
		c += _count_gate_allies(ch)
	return c

func _count_tower_allies(n: Node) -> int:
	var c := 0
	var script: Script = n.get_script()
	if n is Node3D and (n.is_in_group("ally") or (script and script.resource_path.ends_with("ally_archer.gd"))):
		var p: Vector3 = (n as Node3D).global_position
		if p.x >= 292.0 and p.x <= 306.0 and (p.z <= 480.0 or p.z >= 520.0):
			c += 1
	for ch in n.get_children():
		c += _count_tower_allies(ch)
	return c
