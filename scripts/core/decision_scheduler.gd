class_name DecisionScheduler
extends Node

@export var default_max_per_frame: int = 64

var _frame: int = -1
var _used: Dictionary = {}
var _next_allowed: Dictionary = {}
var _perf_monitor: Node = null

func _ready() -> void:
	add_to_group("decision_scheduler")

func can_run(owner: Object, key: StringName, interval: float, max_per_frame: int = -1, force: bool = false) -> bool:
	if owner == null or not is_instance_valid(owner):
		return true
	_reset_frame_if_needed()
	var budget: int = default_max_per_frame if max_per_frame <= 0 else max_per_frame
	if int(_used.get(key, 0)) >= budget:
		_count_perf(&"%s_denied_budget" % str(key))
		return false
	var owner_key: String = _owner_key(owner, key)
	var now: float = _now_seconds()
	if not force and now < float(_next_allowed.get(owner_key, -INF)):
		_count_perf(&"%s_denied_interval" % str(key))
		return false
	_used[key] = int(_used.get(key, 0)) + 1
	_next_allowed[owner_key] = now + maxf(0.0, interval) + _stable_jitter(owner, key, interval)
	_count_perf(&"%s_allowed" % str(key))
	return true

func reset_owner(owner: Object, key: StringName = &"") -> void:
	if owner == null:
		return
	if key != &"":
		_next_allowed.erase(_owner_key(owner, key))
		return
	var prefix: String = "%s:" % str(owner.get_instance_id())
	for owner_key in _next_allowed.keys():
		if str(owner_key).begins_with(prefix):
			_next_allowed.erase(owner_key)

func debug_summary() -> Dictionary:
	_reset_frame_if_needed()
	return {
		"frame": _frame,
		"used": _used.duplicate(),
		"tracked": _next_allowed.size(),
		"default_max_per_frame": default_max_per_frame,
	}

func _reset_frame_if_needed() -> void:
	var current_frame: int = Engine.get_physics_frames()
	if current_frame == _frame:
		return
	_frame = current_frame
	_used.clear()

func _owner_key(owner: Object, key: StringName) -> String:
	return "%s:%s" % [str(owner.get_instance_id()), str(key)]

func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

func _stable_jitter(owner: Object, key: StringName, interval: float) -> float:
	if interval <= 0.0:
		return 0.0
	var hash_value: int = absi(hash("%s:%s" % [str(owner.get_instance_id()), str(key)]))
	return float(hash_value % 1000) / 1000.0 * minf(interval * 0.35, 0.12)

func _count_perf(key: StringName) -> void:
	if _perf_monitor == null or not is_instance_valid(_perf_monitor):
		_perf_monitor = get_tree().get_first_node_in_group("perf_monitor")
	if _perf_monitor != null and _perf_monitor.has_method("count"):
		_perf_monitor.call("count", key)
