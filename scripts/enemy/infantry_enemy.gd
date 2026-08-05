class_name InfantryEnemy
extends Enemy

## Foot soldier: the swarm. A dark-red spearman with shield; barely dents the gate on its own, but
## storms through once it's breached and hammers the keep. Uses the base body/route unchanged.

func _tune() -> void:
	attack_damage = 3.0        # little gate damage — infantry win by numbers, not by the ram's punch
