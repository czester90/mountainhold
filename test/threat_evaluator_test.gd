extends GdUnitTestSuite

const ThreatEvaluatorScript := preload("res://scripts/core/threat_evaluator.gd")

func test_weighted_distance_score_prioritizes_ram() -> void:
	var infantry := _target(Vector3(8.0, 0.0, 0.0))
	var ram := _target(Vector3(12.0, 0.0, 0.0), "ram")
	assert_float(ThreatEvaluatorScript.weighted_distance_score(Vector3.ZERO, infantry, 0.4, 0.55)).is_equal_approx(64.0, 0.001)
	assert_float(ThreatEvaluatorScript.weighted_distance_score(Vector3.ZERO, ram, 0.4, 0.55)).is_equal_approx(57.6, 0.001)

func test_weighted_distance_score_prioritizes_ladder() -> void:
	var ladder := _target(Vector3(10.0, 0.0, 0.0), "ladder")
	assert_float(ThreatEvaluatorScript.weighted_distance_score(Vector3.ZERO, ladder, 0.4, 0.55)).is_equal_approx(55.0, 0.001)

func test_flat_distance_ignores_height() -> void:
	assert_float(ThreatEvaluatorScript.flat_distance_to_point(Vector3(3.0, 50.0, 4.0), Vector3.ZERO)).is_equal_approx(5.0, 0.001)

func test_gate_threat_score_matches_existing_gate_formula() -> void:
	var ladder := _target(Vector3(6.0, 8.0, 0.0), "ladder")
	var score: float = ThreatEvaluatorScript.gate_threat_score(Vector3.ZERO, ladder, Vector3.ZERO, 20.0, 0.5)
	assert_float(score).is_equal_approx(65.0, 0.001)

func test_priority_distance_score_applies_inside_radius_or_ladder() -> void:
	var near_gate := _target(Vector3(12.0, 0.0, 0.0))
	var ladder := _target(Vector3(30.0, 0.0, 0.0), "ladder")
	var far := _target(Vector3(30.0, 0.0, 0.0))
	assert_float(ThreatEvaluatorScript.priority_distance_score(Vector3.ZERO, near_gate, Vector3.ZERO, 18.0, 0.35)).is_equal_approx(50.4, 0.001)
	assert_float(ThreatEvaluatorScript.priority_distance_score(Vector3.ZERO, ladder, Vector3.ZERO, 18.0, 0.35)).is_equal_approx(315.0, 0.001)
	assert_float(ThreatEvaluatorScript.priority_distance_score(Vector3.ZERO, far, Vector3.ZERO, 18.0, 0.35)).is_equal_approx(900.0, 0.001)

func _target(position: Vector3, group_name: String = "") -> Node3D:
	var node := Node3D.new()
	add_child(node)
	node.global_position = position
	if not group_name.is_empty():
		node.add_to_group(group_name)
	return auto_free(node)
