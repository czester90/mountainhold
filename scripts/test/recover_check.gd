extends Node3D

## Forces the "fell through a seam" case: teleport a besieger deep below the world and confirm the
## recovery net snaps it back onto the ground (so it can never become an invisible under-map attacker).

func _ready() -> void:
	var fb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(80, 1, 80)
	cs.shape = bs
	fb.add_child(cs)
	fb.position = Vector3(0, -0.5, 0)
	add_child(fb)
	var e = load("res://scenes/enemy/enemy.tscn").instantiate()
	add_child(e)
	e.global_position = Vector3(0, 0.3, 0)
	e.call("setup_path", [Vector3(30, 0, 0)], null)
	for _i in 20: await get_tree().process_frame
	print("before fall y=%.1f" % e.global_position.y)
	e.global_position = Vector3(5, -2900.0, 0)         # simulate falling through a seam
	await get_tree().create_timer(1.5).timeout
	var y: float = e.global_position.y
	print("%s : FALL RECOVERY (y=%.1f back on ground)" % ["PASS" if y > -5.0 else "FAIL", y])
	get_tree().quit()
