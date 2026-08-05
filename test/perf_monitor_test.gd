extends GdUnitTestSuite

const PerfMonitorScript := preload("res://scripts/core/perf_monitor.gd")

func test_records_average_and_max_time() -> void:
	var monitor := _monitor()
	monitor.call("record_us", &"targeting", 1000)
	monitor.call("record_us", &"targeting", 3000)
	var snap: Dictionary = monitor.call("snapshot")
	var stat: Dictionary = snap[&"targeting"]
	assert_int(stat["count"]).is_equal(2)
	assert_int(stat["total_us"]).is_equal(4000)
	assert_int(stat["max_us"]).is_equal(3000)
	var lines: PackedStringArray = monitor.call("summary_lines", 1)
	assert_str(lines[0]).contains("targeting")
	assert_str(lines[0]).contains("avg2.00ms")
	assert_str(lines[0]).contains("max3.00ms")

func test_count_records_zero_cost_events() -> void:
	var monitor := _monitor()
	monitor.call("count", &"denied", 3)
	var snap: Dictionary = monitor.call("snapshot")
	var stat: Dictionary = snap[&"denied"]
	assert_int(stat["count"]).is_equal(3)
	assert_int(stat["total_us"]).is_equal(0)

func test_summary_lines_respects_limit() -> void:
	var monitor := _monitor()
	monitor.call("record_us", &"slow", 5000)
	monitor.call("record_us", &"fast", 1000)
	var lines: PackedStringArray = monitor.call("summary_lines", 1)
	assert_int(lines.size()).is_equal(1)
	assert_str(lines[0]).contains("slow")

func _monitor() -> Node:
	var monitor := Node.new()
	monitor.set_script(PerfMonitorScript)
	add_child(monitor)
	return auto_free(monitor)
