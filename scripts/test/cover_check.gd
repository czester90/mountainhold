extends Node3D

## Verifies enemy-archer _exposure() grades down with cover: same archer+ally, measured in the open,
## behind a chest-high parapet (rampart), and behind a narrow window slot (tower loop).

func _ready() -> void:
	var fb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(60, 1, 60)
	cs.shape = bs
	fb.add_child(cs)
	fb.position = Vector3(0, -0.5, 0)
	add_child(fb)
	var e = load("res://scenes/enemy/enemy_archer.tscn").instantiate()
	add_child(e)
	e.global_position = Vector3(0, 0.2, 0)
	var ally = load("res://scenes/ally/ally_archer.tscn").instantiate()
	add_child(ally)
	ally.global_position = Vector3(12, 0.2, 0)
	for _i in 8: await get_tree().process_frame
	print("OPEN exposure = %.2f" % float(e.call("_exposure", ally)))
	# chest-high parapet between them (covers legs, leaves chest/head) -> "on a rampart"
	var parapet := _wall(Vector3(6, 0.6, 0), Vector3(2, 1.2, 8))
	await get_tree().process_frame
	print("PARAPET exposure = %.2f" % float(e.call("_exposure", ally)))
	parapet.queue_free()
	# tall wall with only a narrow window slot at chest height -> "behind a window in a tower"
	_wall(Vector3(6, 2.0, -1.1), Vector3(2, 4.0, 2.0))       # left of slot
	_wall(Vector3(6, 2.0, 1.1), Vector3(2, 4.0, 2.0))        # right of slot
	_wall(Vector3(6, 3.2, 0), Vector3(2, 1.6, 0.6))          # above the slot
	_wall(Vector3(6, 0.6, 0), Vector3(2, 0.8, 0.6))          # below the slot
	await get_tree().process_frame
	print("WINDOW exposure = %.2f" % float(e.call("_exposure", ally)))
	get_tree().quit()

func _wall(pos: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	b.position = pos
	add_child(b)
	return b
