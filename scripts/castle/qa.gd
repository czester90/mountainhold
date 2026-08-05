extends Node3D

## 30-camera sweep of the whole fortress -> screenshots/sweep/. Runs the window OFF-SCREEN and
## NO_FOCUS so it never steals the user's mouse/keyboard. Uses play.tscn (real geometry + terrain).

func _ready() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	get_window().position = Vector2i(-4000, -4000)
	get_window().size = Vector2i(960, 540)
	DirAccess.make_dir_recursive_absolute("res://screenshots/sweep")
	var scene = load("res://scenes/castle/fortress.tscn").instantiate()
	add_child(scene)
	var we: Node = scene.get_node_or_null("WorldEnvironment")
	if we:
		# BRIGHT, flat lighting + no fog: this is an inspection sweep, not a beauty shot — we need to
		# see asset seams/gaps on the walls clearly, not atmospheric dusk.
		var env: Environment = we.environment
		env.fog_enabled = false
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.95, 0.95, 0.98)
		env.ambient_light_energy = 1.6
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.55, 0.62, 0.72)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-55, -35, 0)
	fill.light_energy = 1.4
	add_child(fill)
	get_tree().paused = false
	for _i in 90: await get_tree().process_frame
	await get_tree().create_timer(4.0).timeout
	var cam := Camera3D.new()
	cam.fov = 62
	cam.far = 4000
	add_child(cam)
	cam.current = true
	var shots := [
		# --- INNER RING audit v2: elevated obliques to read wall-TOP profile (walk vs merlons side) ---
		["ir01_cave_behind", Vector3(384, 36, 500), Vector3(368, 28, 500)],
		["ir02_keep_rear_cave", Vector3(362, 28, 500), Vector3(376, 27, 500)],
		["ir03_keepcave_side", Vector3(369, 34, 484), Vector3(369, 27, 500)],
		["ir04_cave_interior", Vector3(373, 28, 500), Vector3(380, 27, 500)],
		["ir05_keepcave_ovw", Vector3(392, 48, 500), Vector3(366, 28, 500)],
		["ir06_keep_rear_out", Vector3(366, 29, 500), Vector3(374, 27, 500)],
		["ir07_cave_mouth", Vector3(367, 29, 500), Vector3(373, 27, 500)],
		["ir08_keepcave_side2", Vector3(369, 34, 516), Vector3(369, 27, 500)],
		["ir09_pad_rear", Vector3(360, 40, 500), Vector3(375, 27, 500)],
		["ir10_cave_far", Vector3(400, 40, 500), Vector3(370, 28, 500)],
	]
	var _unused := [
		# --- overviews of the whole curtain line ---
		["01_overview_high", Vector3(287, 95, 400), Vector3(330, 20, 500)],
		["02_curtain_line_field", Vector3(250, 40, 500), Vector3(300, 20, 500)],
		["03_curtain_line_S", Vector3(255, 34, 455), Vector3(295, 20, 490)],
		["04_curtain_line_N", Vector3(255, 34, 545), Vector3(295, 20, 510)],
		# --- OUTER curtain, SOUTH run: field face + kit facing + base + junctions ---
		["05_curtainS_field_eye", Vector3(276, 19, 481), Vector3(291, 20, 487)],
		["06_curtainS_kit_oblique", Vector3(279, 19, 476), Vector3(292, 19, 488)],
		["07_curtainS_base_low", Vector3(280, 16.5, 480), Vector3(291, 16, 485)],
		["08_junction_gate_S", Vector3(279, 19, 491), Vector3(288, 21, 495)],
		["09_junction_towerS", Vector3(283, 20, 470), Vector3(295, 22, 468)],
		["10_curtainS_walk_court", Vector3(303, 25, 484), Vector3(291, 21, 486)],
		["11_curtainS_merlons", Vector3(296, 31, 483), Vector3(289, 22, 486)],
		# --- OUTER curtain, NORTH run (mirror) ---
		["12_curtainN_field_eye", Vector3(276, 19, 519), Vector3(291, 20, 513)],
		["13_curtainN_kit_oblique", Vector3(279, 19, 524), Vector3(292, 19, 512)],
		["14_junction_gate_N", Vector3(279, 19, 509), Vector3(288, 21, 505)],
		["15_junction_towerN", Vector3(283, 20, 530), Vector3(295, 22, 532)],
		# --- corner towers (drum facing + base + wall meet) ---
		["16_towerS_field", Vector3(284, 22, 456), Vector3(297, 22, 466)],
		["17_towerS_base", Vector3(289, 16.5, 460), Vector3(297, 15.5, 466)],
		["18_towerN_field", Vector3(284, 22, 544), Vector3(297, 22, 534)],
		# --- open ends (where the curtain dies into the rock) ---
		["19_open_end_S", Vector3(300, 22, 452), Vector3(314, 18, 458)],
		["20_sally_port", Vector3(322, 17.5, 548), Vector3(308, 17, 537)],
		# --- INNER ring: front wall, side wall, tower junction ---
		["21_innerring_front", Vector3(330, 24, 500), Vector3(345, 27, 500)],
		["22_innerring_towerS", Vector3(338, 28, 478), Vector3(345, 30, 487)],
		["23_innerring_sidewall", Vector3(356, 29, 496), Vector3(352, 31, 488)],
		["24_innerring_base", Vector3(338, 22, 494), Vector3(345, 26, 490)],
		# --- keep walls ---
		["25_keep_front", Vector3(347, 31, 500), Vector3(361, 33, 500)],
		["26_keep_side", Vector3(360, 31, 490), Vector3(361, 33, 500)],
		# --- mural stairs (do they meet the wall/ground) ---
		["27_mural_stair_S", Vector3(300, 24, 476), Vector3(294, 19, 483)],
		["28_mural_stair_foot", Vector3(299, 17, 486), Vector3(295, 18, 483)],
		# --- inner gate + inner tower doors (pinpoint the orange assets) ---
		["29_innergate_close", Vector3(338, 27, 500), Vector3(346, 27, 500)],
		["30_innertower_door", Vector3(349, 27, 496), Vector3(345, 27, 490)],
	]
	for _w in 4: await get_tree().process_frame
	for s in shots:
		cam.global_position = s[1]
		cam.look_at(s[2], Vector3.UP)
		await get_tree().create_timer(0.2).timeout
		for _w in 3: await get_tree().process_frame
		var tex := get_viewport().get_texture()
		if tex:
			tex.get_image().save_png("res://screenshots/sweep/%s.png" % s[0])
			print("SHOT ", s[0])
	get_tree().quit()
