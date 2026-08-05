extends GdUnitTestSuite

const DecisionSchedulerScript := preload("res://scripts/core/decision_scheduler.gd")

func test_caps_decisions_per_frame() -> void:
	var scheduler := _scheduler()
	var actors := [_actor(), _actor(), _actor()]
	assert_bool(scheduler.call("can_run", actors[0], &"targeting", 0.0, 2)).is_true()
	assert_bool(scheduler.call("can_run", actors[1], &"targeting", 0.0, 2)).is_true()
	assert_bool(scheduler.call("can_run", actors[2], &"targeting", 0.0, 2)).is_false()

func test_tracks_intervals_per_owner_and_key() -> void:
	var scheduler := _scheduler()
	var actor := _actor()
	assert_bool(scheduler.call("can_run", actor, &"targeting", 10.0, 4)).is_true()
	assert_bool(scheduler.call("can_run", actor, &"targeting", 10.0, 4)).is_false()
	assert_bool(scheduler.call("can_run", actor, &"separation", 10.0, 4)).is_true()

func test_reset_owner_allows_immediate_decision() -> void:
	var scheduler := _scheduler()
	var actor := _actor()
	assert_bool(scheduler.call("can_run", actor, &"targeting", 10.0, 4)).is_true()
	assert_bool(scheduler.call("can_run", actor, &"targeting", 10.0, 4)).is_false()
	scheduler.call("reset_owner", actor, &"targeting")
	assert_bool(scheduler.call("can_run", actor, &"targeting", 10.0, 4)).is_true()

func _scheduler() -> Node:
	var scheduler := Node.new()
	scheduler.set_script(DecisionSchedulerScript)
	add_child(scheduler)
	return auto_free(scheduler)

func _actor() -> Node:
	var actor := Node.new()
	add_child(actor)
	return auto_free(actor)
