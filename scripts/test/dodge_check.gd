extends Node3D

## Verifies the enemy arrow is a REAL dodgeable projectile: the same archer shoots a target that is
## first stationary, then strafing. The moving target must take far fewer hits (arrows aimed at its
## old position sail past). Fixes "arrow flies beside me but I still take damage".

var _ally: Node
var _archer: Node

func _ready() -> void:
	var fb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(120, 1, 120)
	cs.shape = bs
	fb.add_child(cs)
	fb.position = Vector3(0, -0.5, 0)
	add_child(fb)
	_archer = load("res://scenes/enemy/enemy_archer.tscn").instantiate()
	add_child(_archer)
	_archer.global_position = Vector3(0, 0.2, 0)
	_archer.call("setup_path", [Vector3(30, 0, 0)], null)      # stops at standoff x~10
	_ally = load("res://scenes/ally/ally_archer.tscn").instantiate()
	add_child(_ally)
	_ally.global_position = Vector3(22, 0.2, 0)
	for _i in 10: await get_tree().process_frame
	_ally.set("max_hp", 100000.0)
	_ally.set("hp", 100000.0)
	var ah = _archer.get("_health")                    # make the archer invulnerable so the ally can't kill it
	if ah:
		ah.max_hp = 1.0e9
		ah.hp = 1.0e9
	# phase 1: stationary target
	var h0: float = _ally.get("hp")
	await get_tree().create_timer(10.0).timeout
	var loss_still: float = h0 - float(_ally.get("hp"))
	# phase 2: same duration but strafing hard along Z (arrows aimed at the old spot should miss)
	var h1: float = _ally.get("hp")
	var t := 0.0
	while t < 10.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		if is_instance_valid(_ally):
			_ally.global_position = Vector3(22, 0.2, sin(t * 3.5) * 7.0)
	var loss_move: float = h1 - float(_ally.get("hp"))
	print("STILL loss=%.0f   MOVING loss=%.0f" % [loss_still, loss_move])
	print("%s : DODGE (moving takes fewer hits)" % ["PASS" if loss_move < loss_still else "FAIL"])
	get_tree().quit()
