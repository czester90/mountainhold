extends Node3D

## Fast headless check: an enemy archer with a clear line of sight to a friendly archer should
## whittle the ally's HP down (verifies enemy-archer target selection + ranged damage on units).

func _ready() -> void:
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(120, 1, 120)
	cs.shape = bs
	floor_body.add_child(cs)
	floor_body.position = Vector3(0, -0.5, 0)
	add_child(floor_body)
	var ally = load("res://scenes/ally/ally_archer.tscn").instantiate()
	add_child(ally)
	ally.global_position = Vector3(10, 0.2, 0)
	var e = load("res://scenes/enemy/enemy_archer.tscn").instantiate()
	add_child(e)
	e.global_position = Vector3(0, 0.2, 0)
	e.call("setup_path", [Vector3(30, 0, 0)], null)          # marches east; stops at standoff and shoots
	for _i in 8: await get_tree().process_frame
	var eh = e.get("_health")
	if eh:
		eh.max_hp = 1.0e6
		eh.hp = 1.0e6
	var hp0: float = ally.get("hp")
	var t := 0.0
	while t < 12.0 and is_instance_valid(ally) and float(ally.get("hp")) >= hp0:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
	var dead := not is_instance_valid(ally)
	var hp1: float = 0.0 if dead else ally.get("hp")
	var ok := dead or hp1 < hp0
	print("%s : ENEMY ARCHER hits ally (hp %.0f->%s)" % ["PASS" if ok else "FAIL", hp0, "DEAD" if dead else "%.0f" % hp1])
	get_tree().quit()
