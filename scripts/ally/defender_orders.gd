class_name DefenderOrders
extends Node

signal order_changed(mode: int, label: String)

enum Mode {
	AUTO,
	ATTACK_RAM,
	ATTACK_ARCHERS,
	ATTACK_CLOSEST,
	DEFEND_GATE,
	RETREAT_KEEP,
}

const GATE_RALLY_X := 284.2
const KEEP_RALLY_X := 345.0
const KEEP_RALLY_Y := 32.0
const CENTRE_Z := 500.0
const GATE_REINFORCE_FRACTION := 0.30

var mode: int = Mode.AUTO
var label: String = "Auto"
var _apply_t := 0.0
var _issued_seq: int = 0
var _gate_reinforcement: Dictionary = {}
var _gate_call_count: int = 0
var _slot_reservations: Dictionary = {}

func _ready() -> void:
	add_to_group("defender_orders")
	_apply_order_to_archers()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			issue_order(Mode.ATTACK_RAM)
		KEY_2:
			issue_order(Mode.ATTACK_ARCHERS)
		KEY_3:
			issue_order(Mode.ATTACK_CLOSEST)
		KEY_4:
			issue_order(Mode.DEFEND_GATE)
		KEY_5:
			issue_order(Mode.RETREAT_KEEP)
		KEY_0:
			issue_order(Mode.AUTO)

func _process(delta: float) -> void:
	_apply_t -= delta
	if _apply_t <= 0.0:
		_apply_t = 0.5
		_apply_order_to_archers()

func issue_order(new_mode: int) -> void:
	var was_gate := mode == Mode.DEFEND_GATE
	mode = new_mode
	label = _label_for_mode(mode)
	_issued_seq += 1
	if mode == Mode.DEFEND_GATE:
		_gate_call_count = _gate_call_count + 1 if was_gate else 1
		_pick_gate_reinforcements()
	else:
		_gate_call_count = 0
		_gate_reinforcement.clear()
	_apply_order_to_archers()
	order_changed.emit(mode, label)

func current_label() -> String:
	return label

func _apply_order_to_archers() -> void:
	var allies := _active_allies()
	_prune_slot_reservations(allies)
	var slot := 0
	for ally in allies:
		if not is_instance_valid(ally) or not ally.has_method("set_defender_order"):
			continue
		var ally_mode := mode
		if mode == Mode.DEFEND_GATE and not _gate_reinforcement.has(ally.get_instance_id()):
			ally_mode = Mode.AUTO
		var rally := _reserved_slot_for(ally, ally_mode)
		if rally.x >= 1.0e19:
			rally = _rally_for(slot, ally.global_position.y, ally_mode)
		ally.set_defender_order(ally_mode, rally, _issued_seq)
		slot += 1

func _pick_gate_reinforcements() -> void:
	_gate_reinforcement.clear()
	var allies := _active_allies()
	var candidates: Array[Node3D] = []
	for ally in allies:
		if ally is Node3D and is_instance_valid(ally):
			candidates.append(ally)
	candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		var pa := _gate_priority(a)
		var pb := _gate_priority(b)
		if pa != pb:
			return pa < pb
		var da := absf(a.global_position.x - GATE_RALLY_X) + absf(a.global_position.z - CENTRE_Z) * 0.35
		var db := absf(b.global_position.x - GATE_RALLY_X) + absf(b.global_position.z - CENTRE_Z) * 0.35
		return da < db
	)
	var fraction := minf(1.0, GATE_REINFORCE_FRACTION * float(maxi(1, _gate_call_count)))
	var count := maxi(1, int(ceil(float(candidates.size()) * fraction)))
	for i in mini(count, candidates.size()):
		_gate_reinforcement[candidates[i].get_instance_id()] = true

func _active_allies() -> Array:
	var registry := get_tree().get_first_node_in_group("combat_registry")
	if registry != null and registry.has_method("active_allies"):
		return registry.call("active_allies")
	return get_tree().get_nodes_in_group("ally")

func _gate_priority(ally: Node3D) -> int:
	var pos := ally.global_position
	if pos.y >= 24.0 and pos.x >= 283.0 and pos.x <= 292.0 and absf(pos.z - CENTRE_Z) <= 8.5:
		return 0
	if pos.x >= 286.0 and pos.x <= 296.0 and absf(pos.z - CENTRE_Z) <= 22.0:
		return 1
	return 2

func _rally_for(slot: int, y: float, order_mode: int = mode) -> Vector3:
	match order_mode:
		Mode.DEFEND_GATE:
			var gate_rows := [
				Vector3(GATE_RALLY_X, y, 496.0),
				Vector3(GATE_RALLY_X, y, 500.0),
				Vector3(GATE_RALLY_X, y, 504.0),
				Vector3(GATE_RALLY_X + 0.8, y, 498.0),
				Vector3(GATE_RALLY_X + 0.8, y, 502.0),
			]
			return gate_rows[slot % gate_rows.size()] + Vector3(0.0, 0.0, float(slot / gate_rows.size()) * 0.7)
		Mode.RETREAT_KEEP:
			var row := slot / 5
			var col := slot % 5
			return Vector3(KEEP_RALLY_X + float(row) * 1.4, KEEP_RALLY_Y, CENTRE_Z - 5.0 + float(col) * 2.5)
		_:
			return Vector3.INF

func _reserved_slot_for(ally: Node3D, order_mode: int) -> Vector3:
	var slot_kind := _slot_kind_for(order_mode)
	if slot_kind == &"":
		_release_slot(ally.get_instance_id())
		return Vector3.INF
	var id := ally.get_instance_id()
	var current: Node3D = _slot_reservations.get(id, null)
	if current and is_instance_valid(current) and _slot_matches(current, slot_kind):
		return current.global_position
	var slot := _best_free_slot(slot_kind, ally.global_position)
	if slot == null:
		return Vector3.INF
	_release_slot(id)
	slot.set_meta("reserved_by", id)
	_slot_reservations[id] = slot
	return slot.global_position

func _slot_kind_for(order_mode: int) -> StringName:
	match order_mode:
		Mode.DEFEND_GATE:
			return &"gate"
		Mode.RETREAT_KEEP:
			return &"keep"
		_:
			return &""

func _best_free_slot(slot_kind: StringName, from: Vector3) -> Node3D:
	var best: Node3D = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group("castle_tactical_slot_%s" % str(slot_kind)):
		if not node is Node3D or not is_instance_valid(node):
			continue
		var slot := node as Node3D
		var reserved_by := int(slot.get_meta("reserved_by", 0))
		if reserved_by != 0 and not _slot_reservations.has(reserved_by):
			slot.set_meta("reserved_by", 0)
			reserved_by = 0
		if reserved_by != 0:
			continue
		if not _slot_matches(slot, slot_kind):
			continue
		var priority := int(slot.get_meta("priority", 0))
		var score := from.distance_squared_to(slot.global_position) + float(priority) * 150.0
		if score < best_score:
			best_score = score
			best = slot
	return best

func _slot_matches(slot: Node3D, slot_kind: StringName) -> bool:
	return slot.has_meta("slot_kind") and str(slot.get_meta("slot_kind")) == str(slot_kind)

func _release_slot(id: int) -> void:
	var current: Node3D = _slot_reservations.get(id, null)
	if current and is_instance_valid(current) and int(current.get_meta("reserved_by", 0)) == id:
		current.set_meta("reserved_by", 0)
	_slot_reservations.erase(id)

func _prune_slot_reservations(allies: Array) -> void:
	var live := {}
	for ally in allies:
		if ally is Node3D and is_instance_valid(ally):
			live[ally.get_instance_id()] = true
	for id in _slot_reservations.keys():
		if not live.has(id):
			_release_slot(id)

func _label_for_mode(order_mode: int) -> String:
	match order_mode:
		Mode.ATTACK_RAM:
			return "Atakuj taran"
		Mode.ATTACK_ARCHERS:
			return "Atakuj łuczników"
		Mode.ATTACK_CLOSEST:
			return "Atakuj najbliższych"
		Mode.DEFEND_GATE:
			return "Więcej łuczników do bramy"
		Mode.RETREAT_KEEP:
			return "Wycofaj do stołpu"
		_:
			return "Auto"
