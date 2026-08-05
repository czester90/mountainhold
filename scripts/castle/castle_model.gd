class_name CastleModel
extends Node

var tactical_slots: Array[Node3D] = []
var ladder_slots: Array[Node3D] = []
var navigation_edges: Array[Node] = []
var navigation_links: Array[NavigationLink3D] = []
var navigation_regions: Array[NavigationRegion3D] = []
var regions: Dictionary = {}

func _ready() -> void:
	add_to_group("castle_model")

func reset() -> void:
	tactical_slots.clear()
	ladder_slots.clear()
	navigation_edges.clear()
	navigation_links.clear()
	navigation_regions.clear()
	regions.clear()

func register_tactical_slot(slot: Node3D) -> void:
	if slot == null or tactical_slots.has(slot):
		return
	tactical_slots.append(slot)

func register_ladder_slot(slot: Node3D) -> void:
	if slot == null:
		return
	register_tactical_slot(slot)
	if not ladder_slots.has(slot):
		ladder_slots.append(slot)

func register_navigation_edge(edge: Node) -> void:
	if edge == null or navigation_edges.has(edge):
		return
	navigation_edges.append(edge)

func register_navigation_link(link: NavigationLink3D) -> void:
	if link == null or navigation_links.has(link):
		return
	navigation_links.append(link)

func register_navigation_region(region: NavigationRegion3D) -> void:
	if region == null or navigation_regions.has(region):
		return
	navigation_regions.append(region)

func register_region(region_name: StringName, center: Vector3, radius: float, normal: Vector3 = Vector3.ZERO, metadata: Dictionary = {}) -> void:
	regions[region_name] = {
		"name": region_name,
		"center": center,
		"radius": radius,
		"normal": normal.normalized() if normal.length() > 0.01 else Vector3.ZERO,
		"metadata": metadata,
	}

func region(region_name: StringName) -> Dictionary:
	return regions.get(region_name, {})

func region_names() -> Array:
	return regions.keys()

func slots_for_kind(slot_kind: StringName) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for slot in tactical_slots:
		if is_instance_valid(slot) and str(slot.get_meta("slot_kind", &"")) == str(slot_kind):
			result.append(slot)
	return result

func gate_slots() -> Array[Node3D]:
	return slots_for_kind(&"gate")

func keep_slots() -> Array[Node3D]:
	return slots_for_kind(&"keep")

func archer_slots() -> Array[Node3D]:
	return slots_for_kind(&"archer")

func wall_ladder_slots() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for slot in ladder_slots:
		if is_instance_valid(slot) and str(slot.get_meta("ladder_surface", &"")) == "wall":
			result.append(slot)
	return result

func summary() -> Dictionary:
	return {
		"tactical_slots": tactical_slots.size(),
		"archer_slots": archer_slots().size(),
		"gate_slots": gate_slots().size(),
		"keep_slots": keep_slots().size(),
		"ladder_slots": ladder_slots.size(),
		"wall_ladder_slots": wall_ladder_slots().size(),
		"navigation_edges": navigation_edges.size(),
		"navigation_links": navigation_links.size(),
		"navigation_regions": navigation_regions.size(),
		"regions": regions.size(),
	}
