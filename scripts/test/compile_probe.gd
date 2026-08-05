extends SceneTree

## Loads enemy.gd directly and reports whether it compiled — surfaces the REAL error instead of the
## downstream "Could not resolve class Enemy".

func _init() -> void:
	var s = load("res://scripts/enemy/enemy.gd")
	print("enemy.gd loaded=", s, " can_instantiate=", (s.can_instantiate() if s else false))
	var inf = load("res://scripts/enemy/infantry_enemy.gd")
	print("infantry_enemy.gd loaded=", inf)
	quit()
