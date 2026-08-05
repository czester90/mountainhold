class_name DefenderState
extends RefCounted

const IDLE := &"idle"
const MOVING_TO_ORDER := &"moving_to_order"
const HOLDING_ORDER := &"holding_order"
const ENGAGING := &"engaging"
const REPOSITIONING := &"repositioning"
const RETREATING := &"retreating"
const STUCK := &"stuck"
const DEAD := &"dead"

var _state: StringName = IDLE
var _reason: StringName = &"spawn"
var _order_mode: int = 0
var _rally: Vector3 = Vector3.INF

func apply_order(order_mode: int, rally: Vector3) -> void:
	_order_mode = order_mode
	_rally = rally
	if rally.x >= 1.0e19:
		set_state(IDLE, &"order_idle")
	elif order_mode == 5:
		set_state(RETREATING, &"order_retreat")
	else:
		set_state(MOVING_TO_ORDER, &"order_move")

func set_state(state: StringName, reason: StringName = &"") -> void:
	_state = state
	if reason != &"":
		_reason = reason

func current_state() -> StringName:
	return _state

func reason() -> StringName:
	return _reason

func snapshot() -> Dictionary:
	return {
		"state": _state,
		"reason": _reason,
		"order": _order_mode,
		"rally": _rally,
	}
