extends CanvasLayer

## Siege HUD: gate-HP bar, wave/enemy status, wave banners, a crosshair with a draw-power bar and
## a hit-marker, and a controls hint that fades. Positions are computed from the viewport size each
## frame (Control anchors are unreliable directly under a CanvasLayer). Hidden while paused.

const MINIMAP_SCENE := preload("res://scripts/ui/minimap.gd")
const ROSTER_REFRESH_INTERVAL := 0.35

@export var spawner_path: NodePath

var _spawner: WaveSpawner
var _player: Node
var _root: Control
var _status: Label
var _gate_bg: ColorRect
var _gate_fill: ColorRect
var _gate_label: Label
var _banner: Label
var _banner_t: float = 0.0
var _controls: Label
var _controls_t: float = 9.0
var _cross: Label
var _hit: Label
var _hit_t: float = 0.0
var _kill: Label
var _kill_t: float = 0.0
var _draw_fill: ColorRect
var _draw_bg: ColorRect
var _last_wave: int = 0
var _dmg: ColorRect
var _dmg_t: float = 0.0
var _last_g: float = 1.0
var _keep_bg: ColorRect
var _keep_fill: ColorRect
var _keep_label: Label
var _hp_bg: ColorRect
var _hp_fill: ColorRect
var _hp_label: Label
var _ally_label: Label
var _breach: Label
var _breach_t: float = 0.0
var _gate_was_up: bool = true
var _ram_warn: Label
var _ram_chevron: Label
var _hurt_arc: Label
var _hurt_from: Vector3 = Vector3.INF
var _roster_bg: ColorRect
var _roster_title: Label
var _roster_rows: Array[Label] = []
var _roster_max_rows: int = 8
var _roster_refresh_t: float = 0.0
var _orders: Node = null
var _order_label: Label
var _commands_bg: ColorRect
var _commands_title: Label
var _commands_rows: Array[Label] = []
var _minimap: Control
var _combat_registry: Node

func _ready() -> void:
	_spawner = get_node_or_null(spawner_path) as WaveSpawner
	var scene_root: Node = get_parent()               # robust: works whether or not current_scene is set (e.g. under a test scene_runner)
	_player = scene_root.get_node_or_null("Player") if scene_root else null
	_combat_registry = get_tree().get_first_node_in_group("combat_registry")
	if _combat_registry != null and _player != null and _combat_registry.has_method("register_player"):
		_combat_registry.call("register_player", _player)
	if _player and _player.has_signal("hit_enemy"):
		_player.hit_enemy.connect(func(): _hit_t = 0.16)

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_dmg = ColorRect.new()                      # red screen flash when the gate takes a hit
	_dmg.color = Color(0.8, 0.1, 0.1, 0.0)
	_dmg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dmg)


	_status = _mk_label(22, Color.WHITE, true)
	_gate_bg = ColorRect.new()
	_gate_bg.color = Color(0, 0, 0, 0.55)
	_gate_bg.size = Vector2(320, 22)
	_root.add_child(_gate_bg)
	_gate_fill = ColorRect.new()
	_gate_fill.color = Color(0.4, 0.8, 0.4)
	_gate_fill.position = Vector2(2, 2)
	_gate_fill.size = Vector2(316, 18)
	_gate_bg.add_child(_gate_fill)
	_gate_label = Label.new()                # rides ON the bar (child of the bar, not _root)
	_gate_label.add_theme_font_size_override("font_size", 15)
	_gate_label.add_theme_color_override("font_color", Color.WHITE)
	_gate_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_gate_label.add_theme_constant_override("outline_size", 3)
	_gate_label.size = Vector2(320, 18)
	_gate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gate_bg.add_child(_gate_label)

	# KEEP (stołp) bar — the last line of defence, stacked under the gate bar
	_keep_bg = ColorRect.new()
	_keep_bg.color = Color(0, 0, 0, 0.55)
	_keep_bg.size = Vector2(320, 22)
	_root.add_child(_keep_bg)
	_keep_fill = ColorRect.new()
	_keep_fill.color = Color(0.55, 0.55, 0.92)
	_keep_fill.position = Vector2(2, 2)
	_keep_fill.size = Vector2(316, 18)
	_keep_bg.add_child(_keep_fill)
	_keep_label = Label.new()
	_keep_label.add_theme_font_size_override("font_size", 15)
	_keep_label.add_theme_color_override("font_color", Color.WHITE)
	_keep_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_keep_label.add_theme_constant_override("outline_size", 3)
	_keep_label.size = Vector2(320, 18)
	_keep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keep_bg.add_child(_keep_label)

	# PLAYER health bar — bottom-left
	_hp_bg = ColorRect.new()
	_hp_bg.color = Color(0, 0, 0, 0.55)
	_hp_bg.size = Vector2(260, 24)
	_root.add_child(_hp_bg)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.45, 0.8, 0.4)
	_hp_fill.position = Vector2(2, 2)
	_hp_fill.size = Vector2(256, 20)
	_hp_bg.add_child(_hp_fill)
	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 15)
	_hp_label.add_theme_color_override("font_color", Color.WHITE)
	_hp_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_hp_label.add_theme_constant_override("outline_size", 3)
	_hp_label.size = Vector2(260, 20)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_bg.add_child(_hp_label)
	_ally_label = _mk_label(18, Color(0.72, 0.86, 1.0), true)
	_roster_bg = ColorRect.new()
	_roster_bg.color = Color(0, 0, 0, 0.48)
	_roster_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_roster_bg)
	_roster_title = _mk_label(17, Color(0.9, 0.92, 1.0), true)
	_roster_title.text = "Obrońcy"
	for _i in _roster_max_rows:
		var row := _mk_label(14, Color(0.82, 0.9, 1.0), true)
		row.autowrap_mode = TextServer.AUTOWRAP_OFF
		_roster_rows.append(row)
	_order_label = _mk_label(16, Color(1.0, 0.88, 0.45), true)
	_commands_bg = ColorRect.new()
	_commands_bg.color = Color(0, 0, 0, 0.50)
	_commands_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_commands_bg)
	_commands_title = _mk_label(18, Color(1.0, 0.9, 0.55), true)
	for text in [
		"1  Atakuj taran",
		"2  Atakuj łuczników wroga",
		"3  Atakuj najbliższych",
		"4  Wezwij łuczników do bramy",
		"5  Wycofaj wszystkich do stołpu",
		"0  Auto / samodzielna obrona",
	]:
		var command_row := _mk_label(15, Color(0.92, 0.94, 1.0), true)
		command_row.text = text
		_commands_rows.append(command_row)
	_minimap = MINIMAP_SCENE.new() as Control
	_minimap.custom_minimum_size = Vector2(288, 216)
	_root.add_child(_minimap)
	_minimap.call("setup", scene_root)
	_breach = _mk_label(44, Color(0.96, 0.42, 0.36), true)
	_breach.visible = false
	_ram_warn = _mk_label(26, Color(1.0, 0.55, 0.2), true)
	_ram_warn.text = "⚠ TARAN NADCIĄGA"
	_ram_warn.visible = false
	_ram_chevron = _mk_label(40, Color(1.0, 0.45, 0.2), true)
	_ram_chevron.text = "◆"
	_ram_chevron.visible = false
	_hurt_arc = _mk_label(54, Color(1.0, 0.25, 0.2), true)
	_hurt_arc.text = "◄"
	_hurt_arc.visible = false
	if _player and _player.has_signal("player_hurt"):
		_player.player_hurt.connect(func(fp): _dmg_t = 0.5; _hurt_from = fp)

	_cross = _mk_label(30, Color(1, 1, 1, 0.85), false)
	_cross.text = "+"
	_hit = _mk_label(32, Color(1, 0.5, 0.35), false)
	_hit.text = "✕"
	_hit.visible = false
	_draw_bg = ColorRect.new()
	_draw_bg.color = Color(0, 0, 0, 0.5)
	_draw_bg.size = Vector2(82, 8)
	_draw_bg.visible = false
	_root.add_child(_draw_bg)
	_draw_fill = ColorRect.new()
	_draw_fill.color = Color(0.95, 0.85, 0.4)
	_draw_fill.position = Vector2(1, 1)
	_draw_fill.size = Vector2(0, 6)
	_draw_bg.add_child(_draw_fill)
	_banner = _mk_label(46, Color(1, 0.9, 0.6), true)
	_banner.visible = false
	_controls = _mk_label(18, Color.WHITE, true)
	_controls.text = "WASD ruch · LPM strzał · rozkazy po lewej · P screenshot"
	_kill = _mk_label(44, Color(1, 0.84, 0.25), true)
	_kill.text = "✕"
	_kill.visible = false
	if _player and _player.has_signal("killed_enemy"):
		_player.killed_enemy.connect(func(): _kill_t = 0.5)

# nearest node (to the player) in a list, skipping freed ones
func _nearest(nodes: Array) -> Node3D:
	var best: Node3D = null
	var bd := INF
	var ref: Vector3 = _player.global_position if _player else Vector3.ZERO
	for n in nodes:
		if not is_instance_valid(n):
			continue
		var d := ref.distance_squared_to((n as Node3D).global_position)
		if d < bd:
			bd = d
			best = n
	return best

# screen position for an off-screen marker: at the target if on-screen, else clamped to a screen-edge ring
func _edge_pos(cam: Camera3D, wp: Vector3, vp: Vector2) -> Vector2:
	var behind := cam.is_position_behind(wp)
	var sp := cam.unproject_position(wp)
	var c := vp * 0.5
	var dir := sp - c
	if behind:
		dir = -dir
	if dir.length() < 1.0:
		dir = Vector2(0, -1)
	dir = dir.normalized()
	var onscreen := (not behind) and sp.x > 24 and sp.x < vp.x - 24 and sp.y > 24 and sp.y < vp.y - 24
	if onscreen:
		return sp - Vector2(12, 22)
	var m := 46.0
	var t: float = min((c.x - m) / maxf(absf(dir.x), 0.001), (c.y - m) / maxf(absf(dir.y), 0.001))
	return c + dir * t - Vector2(12, 22)

func _mk_label(size: int, col: Color, outline: bool) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline:
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 4)
	_root.add_child(l)
	return l

func _unit_float(unit: Node, prop: String, fallback: float = 0.0) -> float:
	var value: Variant = unit.get(prop) if unit else null
	return float(value) if value != null else fallback

func _unit_int(unit: Node, prop: String, fallback: int = 0) -> int:
	var value: Variant = unit.get(prop) if unit else null
	return int(value) if value != null else fallback

func _display_name(unit: Node, fallback: String) -> String:
	var value: Variant = unit.get("display_name") if unit else null
	var label := str(value) if value != null else fallback
	return label if not label.is_empty() else fallback

func _sort_roster(a: Node, b: Node) -> bool:
	var level_a := _unit_int(a, "level", 1)
	var level_b := _unit_int(b, "level", 1)
	if level_a != level_b:
		return level_a > level_b
	var kills_a := _unit_int(a, "kills", 0)
	var kills_b := _unit_int(b, "kills", 0)
	if kills_a != kills_b:
		return kills_a > kills_b
	return _display_name(a, "").naturalnocasecmp_to(_display_name(b, "")) < 0

func _roster_line(unit: Node, fallback: String) -> String:
	var name := _display_name(unit, fallback)
	var level := _unit_int(unit, "level", 1)
	var kills := _unit_int(unit, "kills", 0)
	var bow := _unit_float(unit, "arrow_damage", _unit_float(unit, "ranged_attack_damage", 0.0))
	var melee := _unit_float(unit, "melee_damage", _unit_float(unit, "melee_attack_damage", 0.0))
	var defense := _unit_float(unit, "defense", 0.0)
	var armor := _unit_float(unit, "armor", 0.0) * 100.0
	var range := _unit_float(unit, "range", _unit_float(unit, "max_arrow_speed", 0.0))
	return "%s  L%d  K%d\nŁuk %.0f  Wr %.0f  Obr %.1f  Pnc %.0f%%  Zas %.0f" % [
		name, level, kills, bow, melee, defense, armor, range
	]

func _update_roster(vp: Vector2) -> void:
	_roster_refresh_t -= get_process_delta_time()
	var wide := vp.x >= 1180.0
	_roster_bg.visible = wide
	_roster_title.visible = wide
	_order_label.visible = wide
	for row in _roster_rows:
		row.visible = false
	if not wide:
		return
	var w := 310.0
	var x := vp.x - w - 18.0
	var y := 94.0
	_roster_bg.position = Vector2(x, y)
	_roster_bg.size = Vector2(w, 356)
	_roster_title.position = Vector2(x + 14, y + 10)
	_roster_title.size = Vector2(w - 28, 22)
	_order_label.position = Vector2(x + 14, y + 328)
	_order_label.size = Vector2(w - 28, 22)
	if _orders == null:
		_orders = get_tree().get_first_node_in_group("defender_orders")
	var order_text: String = str(_orders.call("current_label")) if _orders and _orders.has_method("current_label") else "Auto"
	_order_label.text = "Rozkaz: %s   (1-5, 0 auto)" % order_text
	if _roster_refresh_t > 0.0:
		return
	_roster_refresh_t = ROSTER_REFRESH_INTERVAL

	var allies := _active_allies()
	allies.sort_custom(Callable(self, "_sort_roster"))
	var roster: Array[Node] = []
	if _player:
		roster.append(_player)
	for ally in allies:
		if ally is Node:
			roster.append(ally)

	for i in mini(_roster_rows.size(), roster.size()):
		var row := _roster_rows[i]
		row.visible = true
		row.position = Vector2(x + 14, y + 38 + float(i) * 38.0)
		row.size = Vector2(w - 28, 36)
		row.text = _roster_line(roster[i], "Łucznik")
		row.modulate = Color(1.0, 0.95, 0.72, 1.0) if roster[i] == _player else Color(0.82, 0.9, 1.0, 1.0)

func _update_commands(_vp: Vector2) -> void:
	if _orders == null:
		_orders = get_tree().get_first_node_in_group("defender_orders")
	var order_text: String = str(_orders.call("current_label")) if _orders and _orders.has_method("current_label") else "Auto"
	var x := 24.0
	var y := 86.0
	var w := 330.0
	_commands_bg.visible = true
	_commands_bg.position = Vector2(x, y)
	_commands_bg.size = Vector2(w, 222)
	_commands_title.visible = true
	_commands_title.position = Vector2(x + 14, y + 10)
	_commands_title.size = Vector2(w - 28, 24)
	_commands_title.text = "ROZKAZY: %s" % order_text
	for i in _commands_rows.size():
		var row := _commands_rows[i]
		row.visible = true
		row.position = Vector2(x + 16, y + 42 + float(i) * 27.0)
		row.size = Vector2(w - 30, 24)

func _process(delta: float) -> void:
	if _spawner == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var cx := vp.x * 0.5
	var cy := vp.y * 0.5
	# layout (absolute, viewport-relative)
	_status.position = Vector2(24, 16)
	_gate_bg.position = Vector2(cx - 160, 18)
	_gate_label.position = Vector2(0, 2)
	_keep_bg.position = Vector2(cx - 160, 44)
	_keep_label.position = Vector2(0, 2)
	_hp_bg.position = Vector2(24, vp.y - 74)
	_hp_label.position = Vector2(0, 2)
	_cross.position = Vector2(cx - 9, cy - 20)
	_hit.position = Vector2(cx - 11, cy - 22)
	_draw_bg.position = Vector2(cx - 41, cy + 26)
	_banner.position = Vector2(cx - 350, cy - 150)
	_banner.size = Vector2(700, 60)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls.position = Vector2(cx - 450, vp.y - 44)
	_controls.size = Vector2(900, 26)
	_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_update_roster(vp)
	_update_commands(vp)
	_update_minimap(vp)

	var paused := get_tree().paused
	_root.visible = not paused
	if paused:
		return

	var g := _spawner.gate_fraction()
	_status.text = "Fala %d/%d    Wrogowie: %d" % [_spawner.wave(), _spawner.total_waves(), _spawner.alive_count()]
	_gate_fill.size.x = 316.0 * g
	_gate_fill.color = Color(0.85, 0.35, 0.3) if g <= 0.34 else Color(0.4, 0.8, 0.4)
	_gate_label.text = ("BRAMA %d%%" % int(round(g * 100.0))) if g > 0.0 else "BRAMA PRZEŁAMANA"

	var k: float = _spawner.keep_fraction() if _spawner.has_method("keep_fraction") else 1.0
	_keep_fill.size.x = 316.0 * k
	_keep_fill.color = Color(0.85, 0.35, 0.3) if k <= 0.34 else Color(0.55, 0.55, 0.92)
	_keep_label.text = "STOŁP %d%%" % int(round(k * 100.0))

	if _player and _player.has_method("health_fraction"):
		var h: float = _player.health_fraction()
		_hp_fill.size.x = 256.0 * h
		_hp_fill.color = Color(0.85, 0.3, 0.28) if h <= 0.3 else Color(0.45, 0.8, 0.4)
		_hp_label.text = "ZDROWIE %d%%" % int(round(h * 100.0))
		_hp_bg.visible = true
	else:
		_hp_bg.visible = false

	# --- ally counter (losing allies to enemy archers is now legible) ---
	_ally_label.position = Vector2(24, 46)
	_ally_label.text = "Sojusznicy: %d" % _active_allies().size()

	var cam := get_viewport().get_camera_3d()
	# --- TARAN warning + a chevron pointing at the nearest ram (the priority target) ---
	var ram := _nearest(_active_rams())
	if ram != null and cam != null:
		_ram_warn.visible = true
		_ram_warn.position = Vector2(cx - 100, 78)
		_ram_warn.size = Vector2(200, 30)
		_ram_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ram_chevron.visible = true
		_ram_chevron.position = _edge_pos(cam, ram.global_position + Vector3.UP * 1.5, vp)
	else:
		_ram_warn.visible = false
		_ram_chevron.visible = false

	# --- breach alert: the gate just fell ---
	if _gate_was_up and g <= 0.001:
		_gate_was_up = false
		_breach_t = 3.0
	if _breach_t > 0.0:
		_breach_t -= delta
		_breach.visible = true
		_breach.position = Vector2(cx - 360, cy - 96)
		_breach.size = Vector2(720, 60)
		_breach.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_breach.text = "BRAMA PRZEŁAMANA — DO STOŁPU!"
		_breach.modulate = Color(1, 1, 1, clampf(_breach_t, 0.0, 1.0) * 0.5 + 0.5)
	else:
		_breach.visible = false

	# --- directional damage: a red chevron toward where the shot came from ---
	if _dmg_t > 0.0 and cam != null and _hurt_from.x < 1.0e19:
		_hurt_arc.visible = true
		_hurt_arc.position = _edge_pos(cam, _hurt_from, vp)
		_hurt_arc.modulate = Color(1, 1, 1, clampf(_dmg_t / 0.5, 0.0, 1.0))
	else:
		_hurt_arc.visible = false

	_dmg.size = vp
	if g < _last_g - 0.0001:                    # gate just took a hit -> flash
		_dmg_t = 0.4
	_last_g = g
	_dmg_t = maxf(0.0, _dmg_t - delta)
	_dmg.color.a = _dmg_t * 0.35

	if _spawner.wave() != _last_wave and _spawner.wave() > 0:
		_last_wave = _spawner.wave()
		_banner.text = "FALA %d" % _last_wave
		_banner_t = 2.6
	var next_in: float = _spawner.time_to_next_wave() if _spawner.has_method("time_to_next_wave") else 0.0
	var waiting_for_assault: bool = bool(_spawner.call("waiting_for_assault")) if _spawner.has_method("waiting_for_assault") else false
	if waiting_for_assault and _banner_t <= 0.0:
		_banner.visible = true
		_banner.modulate = Color(1, 1, 1, 1)
		_banner.text = "WRÓG NA HORYZONCIE — STRZEL ALBO CZEKAJ %d…" % int(ceil(next_in))
	elif next_in > 0.5 and _banner_t <= 0.0:                # lull between waves -> countdown
		_banner.visible = true
		_banner.modulate = Color(1, 1, 1, 1)
		_banner.text = "Następna fala za %d…" % int(ceil(next_in))
	elif _banner_t > 0.0:
		_banner_t -= delta
		_banner.visible = true
		_banner.modulate = Color(1, 1, 1, clampf(_banner_t, 0.0, 1.0))
	else:
		_banner.visible = false

	if _controls_t > 0.0:
		_controls_t -= delta
		_controls.modulate = Color(1, 1, 1, clampf(_controls_t, 0.0, 1.0))
	else:
		_controls.visible = false

	if _player and _player.has_method("is_drawing") and _player.is_drawing():
		_draw_bg.visible = true
		_draw_fill.size.x = 80.0 * _player.draw_fraction()
	else:
		_draw_bg.visible = false

	if _hit_t > 0.0:
		_hit_t -= delta
		_hit.visible = true
		_hit.modulate = Color(1, 1, 1, clampf(_hit_t / 0.16, 0.0, 1.0))
	else:
		_hit.visible = false

	_kill.position = Vector2(cx - 15, cy - 30)
	if _kill_t > 0.0:
		_kill_t -= delta
		_kill.visible = true
		_kill.modulate = Color(1, 1, 1, clampf(_kill_t / 0.5, 0.0, 1.0))
	else:
		_kill.visible = false

func _update_minimap(vp: Vector2) -> void:
	if _minimap == null:
		return
	var wide := vp.x >= 1040.0
	_minimap.visible = wide
	if not wide:
		return
	var map_size := Vector2(288.0, 216.0)
	_minimap.size = map_size
	_minimap.position = Vector2(vp.x - map_size.x - 18.0, vp.y - map_size.y - 24.0)

func _registry() -> Node:
	if _combat_registry == null:
		_combat_registry = get_tree().get_first_node_in_group("combat_registry")
	return _combat_registry

func _active_allies() -> Array:
	var registry := _registry()
	if registry != null and registry.has_method("active_allies"):
		return registry.call("active_allies")
	return get_tree().get_nodes_in_group("ally")

func _active_rams() -> Array:
	var registry := _registry()
	if registry != null and registry.has_method("active_rams"):
		return registry.call("active_rams")
	return get_tree().get_nodes_in_group("ram")
