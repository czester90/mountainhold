extends Node3D

## Confirms an enemy archer's arrow actually damages the PLAYER (layer 5) when the player stands
## still in its line of fire — the core of "enemy archers can hurt me".

func _ready() -> void:
	var fb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(120, 1, 120)
	cs.shape = bs
	fb.add_child(cs)
	fb.position = Vector3(0, -0.5, 0)
	add_child(fb)
	var player = load("res://scenes/player/fps_bow_player.tscn").instantiate()
	add_child(player)
	player.global_position = Vector3(14, 1.0, 0)
	var e = load("res://scenes/enemy/enemy_archer.tscn").instantiate()
	add_child(e)
	e.global_position = Vector3(0, 0.2, 0)
	e.call("setup_path", [Vector3(30, 0, 0)], null)          # stops at standoff x~10, ~4 m from the player
	for _i in 10: await get_tree().process_frame
	var eh = e.get("_health")
	if eh:
		eh.max_hp = 1.0e9
		eh.hp = 1.0e9
	var hp0: float = player.get("hp")
	var t := 0.0
	while t < 14.0 and float(player.get("hp")) >= hp0:
		player.set("test_wish", Vector3.ZERO)                # keep the player still
		await get_tree().create_timer(0.5).timeout
		t += 0.5
	var hp1: float = player.get("hp")
	print("%s : ENEMY ARCHER hits PLAYER (hp %.0f->%.0f)" % ["PASS" if hp1 < hp0 else "FAIL", hp0, hp1])
	get_tree().quit()
