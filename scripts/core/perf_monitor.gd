class_name PerfMonitor
extends Node

@export var enabled: bool = true
@export var max_keys: int = 32

var _stats: Dictionary = {}

func _ready() -> void:
	add_to_group("perf_monitor")

func record_us(key: StringName, elapsed_us: int) -> void:
	if not enabled:
		return
	var stat: Dictionary = _stats.get(key, {"count": 0, "total_us": 0, "max_us": 0})
	stat["count"] = int(stat.get("count", 0)) + 1
	stat["total_us"] = int(stat.get("total_us", 0)) + maxi(0, elapsed_us)
	stat["max_us"] = maxi(int(stat.get("max_us", 0)), elapsed_us)
	_stats[key] = stat
	if _stats.size() > max_keys:
		_prune_low_count_key()

func count(key: StringName, amount: int = 1) -> void:
	if not enabled:
		return
	var stat: Dictionary = _stats.get(key, {"count": 0, "total_us": 0, "max_us": 0})
	stat["count"] = int(stat.get("count", 0)) + maxi(0, amount)
	_stats[key] = stat
	if _stats.size() > max_keys:
		_prune_low_count_key()

func reset() -> void:
	_stats.clear()

func snapshot() -> Dictionary:
	var out := {}
	for key in _stats.keys():
		out[key] = (_stats[key] as Dictionary).duplicate()
	return out

func summary_lines(limit: int = 4) -> PackedStringArray:
	var rows := []
	for key in _stats.keys():
		var stat: Dictionary = _stats[key]
		var count_value := int(stat.get("count", 0))
		if count_value <= 0:
			continue
		var total_us := int(stat.get("total_us", 0))
		var avg_us := float(total_us) / float(count_value)
		rows.append([total_us, "%s c%d avg%.2fms max%.2fms" % [
			str(key),
			count_value,
			avg_us / 1000.0,
			float(stat.get("max_us", 0)) / 1000.0,
		]])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	var out := PackedStringArray()
	for i in mini(rows.size(), limit):
		out.append(str(rows[i][1]))
	return out

func _prune_low_count_key() -> void:
	var lowest_key: Variant = null
	var lowest_count := INF
	for key in _stats.keys():
		var count_value := float((_stats[key] as Dictionary).get("count", 0))
		if count_value < lowest_count:
			lowest_count = count_value
			lowest_key = key
	if lowest_key != null:
		_stats.erase(lowest_key)
