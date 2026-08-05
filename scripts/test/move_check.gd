extends Node3D

## Isolated: one infantry on a flat floor marching 30 m to a target. Prints x over time so we can
## tell whether besieger movement itself is slow (vs. allies just mowing them down in play.tscn).

func _ready() -> void:
	var fb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(120, 1, 120)
	cs.shape = bs
	fb.add_child(cs)
	fb.position = Vector3(0, -0.5, 0)
	add_child(fb)
	var e = load("res://scenes/enemy/enemy.tscn").instantiate()
	add_child(e)
	e.global_position = Vector3(0, 0.3, 0)
	e.call("setup_path", [Vector3(30, 0, 0)], null)
	var t := 0.0
	while t < 16.0:
		await get_tree().create_timer(2.0).timeout
		t += 2.0
		if is_instance_valid(e):
			print("t=%.0f x=%.1f atk=%s" % [t, e.global_position.x, str(e.get("_attacking"))])
	get_tree().quit()
