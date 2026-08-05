extends CanvasLayer

## In-game debug overlay, toggled with F3 or Tab (hidden by default). Shows FPS/frame time, live unit
## counts + enemy state breakdown, the current wave, gate HP, and player position. Handy for
## tuning and for reading load during the perf tests. Robust to current_scene (uses get_parent()).

@export var toggle_key: int = KEY_F3
@export var alternate_toggle_key: int = KEY_TAB
@export var screenshot_key: int = KEY_P       # press P to save a screenshot
@export var spawner_path: NodePath = ^"../WaveSpawner"
const SHOT_DIR := "res://screenshots/player"

var _label: Label
var _msg: Label
var _msg_t: float = 0.0
var _spawner: Node
var _player: Node3D
var _shown: bool = false
var _t: float = 0.0
var _combat_registry: Node

func _ready() -> void:
	layer = 128
	_label = Label.new()
	_label.position = Vector2(16, 130)
	_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_font_size_override("font_size", 15)
	_label.visible = false
	add_child(_label)
	_msg = Label.new()
	_msg.position = Vector2(16, 16)
	_msg.add_theme_color_override("font_color", Color(1, 0.95, 0.5))
	_msg.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_msg.add_theme_constant_override("outline_size", 4)
	_msg.add_theme_font_size_override("font_size", 20)
	_msg.visible = false
	add_child(_msg)
	var root: Node = get_parent()
	_spawner = get_node_or_null(spawner_path)
	_player = root.get_node_or_null("Player") if root else null
	_combat_registry = get_tree().get_first_node_in_group("combat_registry")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: int = (event as InputEventKey).keycode
		if kc == toggle_key or kc == alternate_toggle_key:
			_shown = not _shown
		elif kc == screenshot_key:
			_snap()

# save the current frame to screenshots/player/shot_NNN.png (next free index)
func _snap() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	var n := 0
	var dir := DirAccess.open(SHOT_DIR)
	if dir:
		for f in dir.get_files():
			if f.begins_with("shot_") and f.ends_with(".png"):
				n = maxi(n, f.trim_prefix("shot_").trim_suffix(".png").to_int() + 1)
	var img := get_viewport().get_texture().get_image()
	var path := "%s/shot_%03d.png" % [SHOT_DIR, n]
	img.save_png(path)
	_msg.text = "📸  %s" % path.get_file()
	_msg_t = 2.0
	print("screenshot saved: ", path)

func _process(delta: float) -> void:
	if _msg_t > 0.0:
		_msg_t -= delta
		_msg.visible = true
		_msg.modulate = Color(1, 1, 1, clampf(_msg_t, 0.0, 1.0))
	else:
		_msg.visible = false
	_label.visible = _shown                       # authoritative, so setting _shown alone shows it
	if not _shown:
		return
	_t += delta
	if _t < 0.2:
		return
	_t = 0.0
	var enemies := _active_enemies()
	var attacking := 0
	for e in enemies:
		if e.get("_attacking"):
			attacking += 1
	var allies := _active_allies().size()
	var lines := PackedStringArray()
	lines.append("=== DEV (F3/Tab) ===")
	lines.append("FPS %d  (%.1f ms)" % [Engine.get_frames_per_second(), delta * 1000.0])
	if _spawner:
		lines.append("Wave %d/%d   gate %d%%" % [_spawner.call("wave"), _spawner.call("total_waves"), int(round(_spawner.call("gate_fraction") * 100.0))])
		if _spawner.has_method("siege_debug_summary"):
			var siege_summary := str(_spawner.call("siege_debug_summary"))
			if not siege_summary.is_empty():
				lines.append("Siege %s" % siege_summary)
	lines.append("Enemies %d  (march %d / attack %d)" % [enemies.size(), enemies.size() - attacking, attacking])
	lines.append("Allies %d" % allies)
	var nav_states := _ally_navigation_states()
	if not nav_states.is_empty():
		lines.append("Ally nav %s" % nav_states)
	var nav_drivers := _ally_navigation_drivers()
	if not nav_drivers.is_empty():
		lines.append("Ally nav driver %s" % nav_drivers)
	var recovery := _movement_recovery_summary()
	if not recovery.is_empty():
		lines.append("Recovery %s" % recovery)
	var no_floor := _active_enemies_without_floor()
	if no_floor > 0:
		lines.append("NO FLOOR enemies: %d" % no_floor)
	var collision_summary := _collision_summary()
	if not collision_summary.is_empty():
		lines.append("Collision %s" % collision_summary)
	var tactical_slots := _tactical_slot_summary()
	if not tactical_slots.is_empty():
		lines.append("Slots %s" % tactical_slots)
	var defender_ai := _defender_ai_summary()
	if not defender_ai.is_empty():
		lines.append("DefAI %s" % defender_ai)
	var wall_ai := _wall_assault_ai_summary()
	if not wall_ai.is_empty():
		lines.append("WallAI %s" % wall_ai)
	var ladder_ai := _ladder_assault_ai_summary()
	if not ladder_ai.is_empty():
		lines.append("LadderAI %s" % ladder_ai)
	var ladder_state := _ladder_state_summary()
	if not ladder_state.is_empty():
		lines.append("Ladders %s" % ladder_state)
	var defender_focus := _defender_focus_lines()
	for focus_line in defender_focus:
		lines.append(focus_line)
	if is_instance_valid(_player):
		var p: Vector3 = _player.global_position
		lines.append("Player %.0f, %.0f, %.0f" % [p.x, p.y, p.z])
	_label.text = "\n".join(lines)

func _ally_navigation_states() -> String:
	var counts := {}
	for node in get_tree().get_nodes_in_group("navigation_debug_actor"):
		if not is_instance_valid(node) or not node.has_method("navigation_debug_state"):
			continue
		var key := str(node.navigation_debug_state())
		counts[key] = int(counts.get(key, 0)) + 1
	var parts := PackedStringArray()
	for key in counts.keys():
		parts.append("%s:%d" % [key, counts[key]])
	return ", ".join(parts)

func _ally_navigation_drivers() -> String:
	var counts := {}
	for node in get_tree().get_nodes_in_group("navigation_debug_actor"):
		if not is_instance_valid(node) or not node.has_method("navigation_debug_driver"):
			continue
		var key := str(node.navigation_debug_driver())
		counts[key] = int(counts.get(key, 0)) + 1
	var parts := PackedStringArray()
	for key in counts.keys():
		parts.append("%s:%d" % [key, counts[key]])
	return ", ".join(parts)

func _movement_recovery_summary() -> String:
	var recoveries := 0
	var stuck := 0
	for group_name in ["enemy", "navigation_debug_actor"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(node):
				continue
			if node.has_method("recovery_count"):
				recoveries += int(node.call("recovery_count"))
			if node.has_method("stuck_recovery_count"):
				stuck += int(node.call("stuck_recovery_count"))
	if recoveries <= 0 and stuck <= 0:
		return ""
	return "snap:%d stuck:%d" % [recoveries, stuck]

func _active_enemies_without_floor() -> int:
	var resolver := get_tree().get_first_node_in_group("ground_resolver")
	if resolver == null or not resolver.has_method("has_floor_below"):
		return 0
	var count := 0
	for node in _active_enemies():
		if not node is Node3D or not is_instance_valid(node):
			continue
		if node.has_method("is_active_enemy") and not bool(node.call("is_active_enemy")):
			continue
		if not bool(resolver.call("has_floor_below", node)):
			count += 1
	return count

func _collision_summary() -> String:
	var missing_shapes := 0
	var bad_masks := 0
	var checked := 0
	for node in _active_enemies():
		if not is_instance_valid(node) or not node.has_method("collision_debug_snapshot"):
			continue
		checked += 1
		var snap: Dictionary = node.call("collision_debug_snapshot")
		if int(snap.get("shapes", 0)) <= 0:
			missing_shapes += 1
		if int(snap.get("mask", 0)) <= 0 or int(snap.get("layer", 0)) <= 0:
			bad_masks += 1
	for node in _active_allies():
		if not is_instance_valid(node) or not node.has_method("collision_debug_snapshot"):
			continue
		checked += 1
		var snap: Dictionary = node.call("collision_debug_snapshot")
		if int(snap.get("shapes", 0)) <= 0:
			missing_shapes += 1
		if int(snap.get("mask", 0)) <= 0 or int(snap.get("layer", 0)) <= 0:
			bad_masks += 1
	if checked <= 0:
		return ""
	return "units:%d no_shape:%d bad_mask:%d" % [checked, missing_shapes, bad_masks]

func _tactical_slot_summary() -> String:
	var total := 0
	var reserved := 0
	for node in get_tree().get_nodes_in_group("castle_tactical_slot"):
		if not is_instance_valid(node):
			continue
		total += 1
		if int(node.get_meta("reserved_by", 0)) != 0:
			reserved += 1
	return "%d/%d reserved" % [reserved, total] if total > 0 else ""

func _defender_ai_summary() -> String:
	var counts := {}
	var los := 0
	var with_target := 0
	var with_slot := 0
	for ally in _active_allies():
		if not is_instance_valid(ally) or not ally.has_method("defender_debug_snapshot"):
			continue
		var snap: Dictionary = ally.call("defender_debug_snapshot")
		var reason := str(snap.get("reason", "unknown"))
		counts[reason] = int(counts.get(reason, 0)) + 1
		if bool(snap.get("has_los", false)):
			los += 1
		if str(snap.get("target", "none")) != "none":
			with_target += 1
		if bool(snap.get("has_slot", false)):
			with_slot += 1
	var parts := PackedStringArray()
	for reason in counts.keys():
		parts.append("%s:%d" % [reason, counts[reason]])
	if parts.is_empty():
		return ""
	return "target:%d los:%d slot:%d | %s" % [with_target, los, with_slot, ", ".join(parts)]

func _defender_focus_lines() -> PackedStringArray:
	var rows := []
	for ally in _active_allies():
		if not is_instance_valid(ally) or not ally.has_method("defender_debug_snapshot"):
			continue
		var snap: Dictionary = ally.call("defender_debug_snapshot")
		var target_distance := float(snap.get("target_distance", -1.0))
		var priority := 0.0
		if str(snap.get("target", "none")) != "none":
			priority -= 1000.0
		if bool(snap.get("has_los", false)):
			priority -= 300.0
		if bool(snap.get("has_slot", false)):
			priority -= 100.0
		if target_distance >= 0.0:
			priority += target_distance
		rows.append([priority, snap])
	rows.sort_custom(func(a, b): return a[0] < b[0])
	var out := PackedStringArray()
	for i in mini(rows.size(), 3):
		var snap: Dictionary = rows[i][1]
		var dist := float(snap.get("target_distance", -1.0))
		var dist_text := "%.0fm" % dist if dist >= 0.0 else "-"
		var slot_text := "slot" if bool(snap.get("has_slot", false)) else "noslot"
		var los_text := "LOS" if bool(snap.get("has_los", false)) else "block"
		out.append("  %s %s %s %s %s cd%.1f" % [
			str(snap.get("name", "ally")),
			str(snap.get("target", "none")),
			dist_text,
			los_text,
			slot_text,
			float(snap.get("cooldown", 0.0)),
		])
	return out

func _wall_assault_ai_summary() -> String:
	var on_wall := 0
	var counts := {}
	for enemy in _active_enemies():
		if not is_instance_valid(enemy):
			continue
		if not bool(enemy.get("_on_wall")):
			continue
		on_wall += 1
		if enemy.has_method("wall_assault_debug_summary"):
			var summary := str(enemy.call("wall_assault_debug_summary"))
			var reason := summary.split(" ")[0] if not summary.is_empty() else "unknown"
			counts[reason] = int(counts.get(reason, 0)) + 1
		else:
			counts["no_debug"] = int(counts.get("no_debug", 0)) + 1
	if on_wall <= 0:
		return ""
	var parts := PackedStringArray()
	for reason in counts.keys():
		parts.append("%s:%d" % [reason, counts[reason]])
	return "on_wall:%d | %s" % [on_wall, ", ".join(parts)]

func _ladder_assault_ai_summary() -> String:
	var counts := {}
	var with_brain := 0
	for enemy in _active_enemies():
		if not is_instance_valid(enemy) or not enemy.has_method("ladder_assault_debug_summary"):
			continue
		with_brain += 1
		var summary := str(enemy.call("ladder_assault_debug_summary"))
		var reason := summary.split(" ")[0] if not summary.is_empty() else "unknown"
		counts[reason] = int(counts.get(reason, 0)) + 1
	if with_brain <= 0:
		return ""
	var parts := PackedStringArray()
	for reason in counts.keys():
		parts.append("%s:%d" % [reason, counts[reason]])
	return "%d | %s" % [with_brain, ", ".join(parts)]

func _ladder_state_summary() -> String:
	var ladders := _active_ladders()
	if ladders.is_empty():
		return ""
	var queued := 0
	var entry := 0
	var climbing := 0
	var capacity := 0
	var damaged := 0
	for ladder in ladders:
		if not is_instance_valid(ladder):
			continue
		if ladder.has_method("debug_summary"):
			var snap: Dictionary = ladder.call("debug_summary")
			queued += int(snap.get("queued", 0))
			entry += int(snap.get("entry", 0))
			climbing += int(snap.get("climbing", 0))
			capacity += int(snap.get("capacity", 0))
			if float(snap.get("hp", 1.0)) <= 0.0:
				damaged += 1
	return "active:%d queue:%d entry:%d climb:%d/%d broken:%d" % [ladders.size(), queued, entry, climbing, capacity, damaged]

func _registry() -> Node:
	if _combat_registry == null:
		_combat_registry = get_tree().get_first_node_in_group("combat_registry")
	return _combat_registry

func _active_enemies() -> Array:
	var registry := _registry()
	if registry != null and registry.has_method("active_enemies"):
		return registry.call("active_enemies")
	return get_tree().get_nodes_in_group("enemy")

func _active_allies() -> Array:
	var registry := _registry()
	if registry != null and registry.has_method("active_allies"):
		return registry.call("active_allies")
	return get_tree().get_nodes_in_group("ally")

func _active_ladders() -> Array:
	var registry := _registry()
	if registry != null and registry.has_method("active_ladders"):
		return registry.call("active_ladders")
	return get_tree().get_nodes_in_group("siege_ladder_active")
