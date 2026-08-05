extends Node3D

## Verifies weak-hit doubling: a head-height hit on infantry does 2x; a low hit does 1x. And the ram
## is inverted — a LOW (crew) hit does 2x, a high (roof) hit does 1x.

func _ready() -> void:
	var inf = load("res://scenes/enemy/enemy_infantry.tscn").instantiate()
	add_child(inf)
	inf.global_position = Vector3(0, 0, 0)
	var ram = load("res://scenes/enemy/enemy_ram.tscn").instantiate()
	add_child(ram)
	ram.global_position = Vector3(10, 0, 0)
	for _i in 8: await get_tree().process_frame
	var ih0: float = inf.get("hp")
	inf.call("take_damage_at", 10.0, inf.global_position.y + 1.6)   # head -> 2x
	var ih1: float = inf.get("hp")
	inf.call("take_damage_at", 10.0, inf.global_position.y + 0.5)   # legs -> 1x
	var ih2: float = inf.get("hp")
	var rh0: float = ram.get("hp")
	ram.call("take_damage_at", 10.0, ram.global_position.y + 0.5)   # crew (low) -> 2x
	var rh1: float = ram.get("hp")
	ram.call("take_damage_at", 10.0, ram.global_position.y + 2.0)   # roof (high) -> 1x
	var rh2: float = ram.get("hp")
	var head := ih0 - ih1
	var body := ih1 - ih2
	var crew := rh0 - rh1
	var roof := rh1 - rh2
	print("INF head=%.0f body=%.0f ; RAM crew=%.0f roof=%.0f" % [head, body, crew, roof])
	print("%s : WEAK-HIT (head 2x, ram crew 2x)" % ["PASS" if (head == 20.0 and body == 10.0 and crew == 20.0 and roof == 10.0) else "FAIL"])
	get_tree().quit()
