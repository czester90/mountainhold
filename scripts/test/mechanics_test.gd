extends Node3D

## Automated mechanic scenarios driving the REAL player (via test_wish -> real _physics_process:
## real step-up, floor_snap, collision). Each test teleports the player to a mechanic's start,
## drives it through, and asserts it reached the goal (didn't jam). Prints PASS/FAIL per mechanic.

var _p: CharacterBody3D
var _scene: Node

func _ready() -> void:
	_scene = load("res://scenes/play.tscn").instantiate()
	add_child(_scene)
	_p = _scene.get_node("Player")
	for _i in 60: await get_tree().process_frame
	await get_tree().create_timer(4.0).timeout            # terrain + fortress + allies build

	# the gate starts SHUT (solid) -> blocks; once breached it opens and you can pass through
	await _t_blocked("GATE CLOSED (shut gate blocks the passage)", Vector3(278,16,500), Vector3(300,16,500), 289.0)
	var _sp = _scene.get_node_or_null("WaveSpawner")
	if _sp:
		_sp.set("_gate_hp", 0.0)                              # breach it
	for _i in 8: await get_tree().process_frame               # let the spawner swing the gate open
	await _t("GATE breached (open gate -> pass through)", [Vector3(278,16,500), Vector3(300,15,500)], 0.5, 15.0)
	await _t("CAUSEWAY (foot->inner gate, climbs)", [Vector3(326,20,500), Vector3(344,27,500)], 2.0, 15.0)
	await _t("INNER GATE (bailey approach->through)", [Vector3(340,27,500), Vector3(352,27,500)], 1.5, 12.0)
	await _t("KEEP entry (bailey->inside keep)", [Vector3(349,27,500), Vector3(363,27,500)], 1.5, 12.0)
	await _t("KEEP->CAVE (through rear gate)", [Vector3(358,27,500), Vector3(377,27,500)], 1.5, 12.0)
	await _t_reach("KEEP CLIMB (bailey->interior stair->first floor y32)", [Vector3(360,26.5,500), Vector3(361,26.5,504), Vector3(361,27.5,505.5), Vector3(358,29,505.5), Vector3(357.5,30,507), Vector3(359,31.2,508.5), Vector3(360,32,508)], Vector2(360, 508), 30.5, 24.0)
	await _t("TOWER climb (outer S switchback->deck y27)", [Vector3(296.85,22,466), Vector3(296.85,24,469), Vector3(299.15,25,469), Vector3(299.15,27,465.5), Vector3(298,27.5,467)], 26.9, 16.0)
	await _t("MURAL STAIR (courtyard->rampart y21)", [Vector3(295,15.6,489.5), Vector3(295,18,485), Vector3(295,20.5,482), Vector3(294,21,480)], 20.5, 14.0)
	await _t("GATE TOP walk (through the gate tower on the rampart)", [Vector3(290,22.5,511), Vector3(289,22.5,506), Vector3(288.5,22.5,500), Vector3(289,22.5,494), Vector3(290,22.5,488)], 0.5, 18.0)
	await _t("GATE ROOF (gallery->interior stair->open roof y27)", [Vector3(287.8,21.5,505), Vector3(290.5,21.5,505), Vector3(293,21.5,505.5), Vector3(292.5,22.5,504), Vector3(292,24,501), Vector3(291.9,24.5,500.4), Vector3(291,25.5,502), Vector3(291.5,26.5,504.5), Vector3(291.9,27.5,506)], 26.5, 24.0)
	await _t_blocked("GATE SIDE solid (no bypass past the portcullis)", Vector3(280,16,495), Vector3(300,16,495), 291.0)
	# can the DEFENDER get from the keep back out to the outer wall/gate rampart?
	await _t_reach("KEEP->WALLS (keep -> outer rampart to defend)", [Vector3(356,26,500), Vector3(348,26,500), Vector3(338,23,500), Vector3(326,19,500), Vector3(312,15.5,500), Vector3(302,15.5,494), Vector3(295,15.6,489.5), Vector3(295,18,485), Vector3(295,20.5,482), Vector3(294,21,480)], Vector2(294,480), 20.0, 40.0)
	# can the player enter the inner tower by the keep (ground door) and climb it to the roof?
	await _t_reach("KEEP TOWER entry (bailey -> ground door -> inside the inner tower)", [Vector3(349,26,500), Vector3(346,26,495), Vector3(345,26,491), Vector3(344,26,488)], Vector2(345,488), 24.0, 20.0)
	# fell outside -> back in through the hidden sally port in the wall by the corner tower
	await _t("SALLY PORT (field -> secret door -> courtyard)", [Vector3(283,17,523), Vector3(291.6,16,517.5), Vector3(299,16,514)], 1.5, 14.0)

	_test_arrow()
	await get_tree().create_timer(1.0).timeout
	await _test_siege_route()
	# enemy-archer ranged damage + dodge are covered by the standalone scenes/archer_check.tscn +
	# scenes/dodge_check.tscn (reliable; the in-scene player case is flaky amid the full siege)
	await _test_allies()
	print("=== MECHANICS TEST DONE ===")
	get_tree().quit()

# with the gate breached, an enemy should path through the gate + bailey + causeway + inner gate to the keep
func _test_siege_route() -> void:
	var spawner: Node = _scene.get_node_or_null("WaveSpawner")
	if spawner == null:
		print("FAIL : SIEGE ROUTE (no WaveSpawner)")
		return
	spawner.set("_gate_hp", 0.0)                          # pretend the gate is already breached
	var Enemy = load("res://scenes/enemy/enemy.tscn")
	var e = Enemy.instantiate()
	_scene.add_child(e)
	e.global_position = Vector3(283, 16.5, 500)
	var route := [Vector3(285,0,500), Vector3(301,0,500), Vector3(322,0,500), Vector3(341,0,500), Vector3(351,0,500), Vector3(357,0,500)]
	e.call("setup_path", route, spawner)
	for _i in 6: await get_tree().process_frame
	var h = e.get("_health")                              # make it invulnerable so allies can't cut the run short
	if h:
		h.max_hp = 1.0e6
		h.hp = 1.0e6
	var keep0: float = spawner.call("keep_hp")
	var t := 0.0
	var best := 0.0
	var stuck := Vector3.ZERO
	while t < 62.0 and is_instance_valid(e) and best < 351.0:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
		if is_instance_valid(e):
			stuck = e.global_position
			best = maxf(best, e.global_position.x)
	# success = the besieger traversed gate->bailey->causeway->inner gate to the keep's attack range
	var reached := best >= 350.0
	print("%s : SIEGE ROUTE (breached gate -> keep, best x=%.1f, keep hp %.0f->%.0f, final=%.1f,%.1f,%.1f)" % ["PASS" if reached else "FAIL", best, keep0, spawner.call("keep_hp"), stuck.x, stuck.y, stuck.z])
	if is_instance_valid(e):
		e.queue_free()

# drive player through waypoints; last arg: if >3 treat as min-Y to reach (climb tests), else reach xz-dist
func _t(name: String, wps: Array, goal: float, timeout: float) -> void:
	_p.velocity = Vector3.ZERO
	_p.test_wish = Vector3.ZERO
	_p.global_position = wps[0]
	for _i in 8: await get_tree().process_frame
	var wp := 1
	var t := 0.0
	var climb := goal > 3.0
	var reached := false
	while t < timeout:
		var tgt: Vector3 = wps[min(wp, wps.size() - 1)]
		var to := tgt - _p.global_position
		to.y = 0.0
		if to.length() < 1.0 and wp < wps.size() - 1:
			wp += 1
		_p.test_wish = to.normalized()
		await get_tree().create_timer(0.1).timeout
		t += 0.1
		if climb:
			if _p.global_position.y >= goal:
				reached = true; break
		else:
			var last: Vector3 = wps[wps.size() - 1]
			if Vector2(_p.global_position.x - last.x, _p.global_position.z - last.z).length() < goal + 1.0:
				reached = true; break
	_p.test_wish = Vector3.ZERO
	var pos := _p.global_position
	print("%s : %s  (final=%.1f,%.1f,%.1f)" % ["PASS" if reached else "FAIL", name, pos.x, pos.y, pos.z])

# drive from start toward tgt; PASS only if the player CANNOT push past barrier_x (structure blocks it)
func _t_blocked(name: String, start: Vector3, tgt: Vector3, barrier_x: float) -> void:
	_p.velocity = Vector3.ZERO
	_p.test_wish = Vector3.ZERO
	_p.global_position = start
	for _i in 8: await get_tree().process_frame
	var t := 0.0
	var breached := false
	while t < 8.0:
		var to := tgt - _p.global_position
		to.y = 0.0
		_p.test_wish = to.normalized()
		await get_tree().create_timer(0.1).timeout
		t += 0.1
		if _p.global_position.x >= barrier_x:
			breached = true
			break
	_p.test_wish = Vector3.ZERO
	var pos := _p.global_position
	print("%s : %s  (final=%.1f,%.1f,%.1f)" % ["PASS" if not breached else "FAIL", name, pos.x, pos.y, pos.z])

# drive through waypoints; PASS only if the player ends within 1.5 m (xz) of xz_targ AND at >= min_y
func _t_reach(name: String, wps: Array, xz_targ: Vector2, min_y: float, timeout: float) -> void:
	_p.velocity = Vector3.ZERO
	_p.test_wish = Vector3.ZERO
	_p.global_position = wps[0]
	for _i in 8: await get_tree().process_frame
	var wp := 1
	var t := 0.0
	var ok := false
	while t < timeout:
		var tgt: Vector3 = wps[min(wp, wps.size() - 1)]
		var to := tgt - _p.global_position
		to.y = 0.0
		if to.length() < 1.0 and wp < wps.size() - 1:
			wp += 1
		_p.test_wish = to.normalized()
		await get_tree().create_timer(0.1).timeout
		t += 0.1
		if Vector2(_p.global_position.x - xz_targ.x, _p.global_position.z - xz_targ.y).length() < 1.5 and _p.global_position.y >= min_y:
			ok = true
			break
	_p.test_wish = Vector3.ZERO
	var pos := _p.global_position
	print("%s : %s  (final=%.1f,%.1f,%.1f)" % ["PASS" if ok else "FAIL", name, pos.x, pos.y, pos.z])

func _test_arrow() -> void:
	var root := get_tree().current_scene         # _fire adds arrows here
	var before := 0
	for c in root.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("arrow.gd"): before += 1
	_p.set("_draw_t", 1.0)
	_p.call("_fire")
	var after := 0
	for c in root.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("arrow.gd"): after += 1
	print("%s : ARROW spawns on fire (%d->%d)" % ["PASS" if after > before else "FAIL", before, after])

# an enemy archer with a clear line of sight to the player should whittle the player's HP down
func _test_enemy_archer() -> void:
	var hp_before: float = _p.get("hp")
	var e = load("res://scenes/enemy/enemy_archer.tscn").instantiate()
	_scene.add_child(e)
	e.global_position = Vector3(262, 16.5, 500)
	e.call("setup_path", [Vector3(285, 0, 500)], null)
	for _i in 6: await get_tree().process_frame
	var eh = e.get("_health")                               # invulnerable so allies can't kill it mid-test
	if eh:
		eh.max_hp = 1.0e6
		eh.hp = 1.0e6
	_p.velocity = Vector3.ZERO
	_p.test_wish = Vector3.ZERO
	_p.global_position = Vector3(272, 16.5, 500)             # in the field, clear LOS to the archer
	var t := 0.0
	while t < 10.0 and float(_p.get("hp")) >= hp_before:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
	var hp_after: float = _p.get("hp")
	print("%s : ENEMY ARCHER hits player (hp %.0f->%.0f)" % ["PASS" if hp_after < hp_before else "FAIL", hp_before, hp_after])
	if is_instance_valid(e):
		e.queue_free()

func _test_allies() -> void:
	# spawn a stationary enemy in front of the outer wall in ally LOS; expect it to take damage / die
	var Enemy = load("res://scenes/enemy/enemy.tscn")
	var e = Enemy.instantiate()
	add_child(e)
	e.global_position = Vector3(262, 16, 500)
	e.call("setup", Vector3(9999, 16, 500))     # far east target so it never "breaches"
	e.set("speed", 0.0)
	var hp0 = e.get("hp")
	var t := 0.0
	while t < 12.0 and is_instance_valid(e):
		await get_tree().create_timer(0.5).timeout; t += 0.5
	var killed := not is_instance_valid(e)
	print("%s : ALLIES damage a field enemy (killed=%s in %.1fs)" % ["PASS" if killed else "FAIL", killed, t])
