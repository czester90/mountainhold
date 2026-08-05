extends GdUnitTestSuite

const Ally := preload("res://scenes/ally/ally_archer.tscn")
const OrdersScript := preload("res://scripts/ally/defender_orders.gd")

func test_order_moves_archers_to_gate_rally() -> void:
	var orders: Node = auto_free(Node.new())
	orders.set_script(OrdersScript)
	add_child(orders)
	var ally: Node3D = auto_free(Ally.instantiate())
	add_child(ally)
	ally.global_position = Vector3(300.0, 27.0, 500.0)
	await await_millis(30)
	orders.call("issue_order", DefenderOrders.Mode.DEFEND_GATE)
	assert_int(ally.get("_order_mode")).is_equal(DefenderOrders.Mode.DEFEND_GATE)
	var rally: Vector3 = ally.get("_order_rally")
	assert_float(rally.x).is_equal_approx(284.2, 0.001)
	assert_float(rally.z).is_between(495.0, 505.0)

func test_gate_order_reserves_generated_tactical_slots() -> void:
	var orders: Node = auto_free(Node.new())
	orders.set_script(OrdersScript)
	add_child(orders)
	var slot_a := _add_slot(&"gate", Vector3(281.0, 27.0, 498.0))
	var slot_b := _add_slot(&"gate", Vector3(282.0, 27.0, 502.0))
	var ally_a: Node3D = auto_free(Ally.instantiate())
	var ally_b: Node3D = auto_free(Ally.instantiate())
	add_child(ally_a)
	add_child(ally_b)
	ally_a.global_position = Vector3(300.0, 27.0, 498.0)
	ally_b.global_position = Vector3(300.0, 27.0, 502.0)
	await await_millis(30)
	orders.call("issue_order", DefenderOrders.Mode.DEFEND_GATE)
	orders.call("issue_order", DefenderOrders.Mode.DEFEND_GATE)
	var rally_a: Vector3 = ally_a.get("_order_rally")
	var rally_b: Vector3 = ally_b.get("_order_rally")
	assert_bool([slot_a.global_position, slot_b.global_position].has(rally_a)).is_true()
	assert_bool([slot_a.global_position, slot_b.global_position].has(rally_b)).is_true()
	assert_vector(rally_a).is_not_equal(rally_b)
	assert_int(slot_a.get_meta("reserved_by")).is_not_equal(0)
	assert_int(slot_b.get_meta("reserved_by")).is_not_equal(0)

func test_gate_order_calls_only_thirty_percent_first() -> void:
	var orders: Node = auto_free(Node.new())
	orders.set_script(OrdersScript)
	add_child(orders)
	var allies: Array[Node3D] = []
	for i in 10:
		var ally: Node3D = auto_free(Ally.instantiate())
		add_child(ally)
		ally.global_position = Vector3(300.0 + float(i), 27.0, 500.0)
		allies.append(ally)
	await await_millis(30)
	orders.call("issue_order", DefenderOrders.Mode.DEFEND_GATE)
	var called := 0
	for ally in allies:
		if int(ally.get("_order_mode")) == DefenderOrders.Mode.DEFEND_GATE:
			called += 1
	assert_int(called).is_equal(3)

func test_repeated_gate_order_calls_more_archers() -> void:
	var orders: Node = auto_free(Node.new())
	orders.set_script(OrdersScript)
	add_child(orders)
	var allies: Array[Node3D] = []
	for i in 10:
		var ally: Node3D = auto_free(Ally.instantiate())
		add_child(ally)
		ally.global_position = Vector3(300.0 + float(i), 27.0, 500.0)
		allies.append(ally)
	await await_millis(30)
	orders.call("issue_order", DefenderOrders.Mode.DEFEND_GATE)
	orders.call("issue_order", DefenderOrders.Mode.DEFEND_GATE)
	var called := 0
	for ally in allies:
		if int(ally.get("_order_mode")) == DefenderOrders.Mode.DEFEND_GATE:
			called += 1
	assert_int(called).is_equal(6)

func test_gate_order_prefers_archers_already_on_gate_roof() -> void:
	var orders: Node = auto_free(Node.new())
	orders.set_script(OrdersScript)
	add_child(orders)
	var lower_close: Node3D = auto_free(Ally.instantiate())
	add_child(lower_close)
	lower_close.global_position = Vector3(286.0, 21.0, 500.0)
	var roof_archers: Array[Node3D] = []
	for i in 3:
		var roof: Node3D = auto_free(Ally.instantiate())
		add_child(roof)
		roof.global_position = Vector3(291.0, 27.0, 496.0 + float(i) * 4.0)
		roof_archers.append(roof)
	for i in 6:
		var reserve: Node3D = auto_free(Ally.instantiate())
		add_child(reserve)
		reserve.global_position = Vector3(320.0 + float(i), 27.0, 500.0)
	await await_millis(30)
	orders.call("issue_order", DefenderOrders.Mode.DEFEND_GATE)
	for roof in roof_archers:
		assert_int(roof.get("_order_mode")).is_equal(DefenderOrders.Mode.DEFEND_GATE)
	assert_int(lower_close.get("_order_mode")).is_not_equal(DefenderOrders.Mode.DEFEND_GATE)

func test_order_can_return_to_auto() -> void:
	var orders: Node = auto_free(Node.new())
	orders.set_script(OrdersScript)
	add_child(orders)
	await await_millis(10)
	orders.call("issue_order", DefenderOrders.Mode.ATTACK_RAM)
	assert_str(orders.call("current_label")).is_equal("Atakuj taran")
	orders.call("issue_order", DefenderOrders.Mode.AUTO)
	assert_str(orders.call("current_label")).is_equal("Auto")

func test_retreat_order_rallies_to_keep_platform_height() -> void:
	var orders: Node = auto_free(Node.new())
	orders.set_script(OrdersScript)
	add_child(orders)
	var ally: Node3D = auto_free(Ally.instantiate())
	add_child(ally)
	ally.global_position = Vector3(290.0, 21.0, 500.0)
	await await_millis(30)
	orders.call("issue_order", DefenderOrders.Mode.RETREAT_KEEP)
	var rally: Vector3 = ally.get("_order_rally")
	assert_float(rally.x).is_greater_equal(345.0)
	assert_float(rally.y).is_equal(32.0)

func _add_slot(kind: StringName, position: Vector3) -> Marker3D:
	var slot: Marker3D = auto_free(Marker3D.new())
	slot.add_to_group("castle_tactical_slot")
	slot.add_to_group("castle_tactical_slot_%s" % str(kind))
	slot.set_meta("slot_kind", kind)
	slot.set_meta("priority", 0)
	slot.set_meta("reserved_by", 0)
	add_child(slot)
	slot.global_position = position
	return slot
