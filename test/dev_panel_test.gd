extends GdUnitTestSuite

## Verifies the DeveloperPanel renders live stats when shown (headless-friendly: we force _shown
## rather than simulating the F3 key).

func test_panel_renders_stats_when_shown() -> void:
	var runner := scene_runner("res://scenes/play.tscn")
	await runner.simulate_frames(30)
	await await_millis(3000)
	var panel: CanvasLayer = runner.scene().get_node("DeveloperPanel")
	panel.set("_shown", true)
	await await_millis(400)                       # panel refreshes every 0.2 s
	var label: Label = panel.get("_label")
	assert_str(label.text).contains("FPS")
	assert_str(label.text).contains("Enemies")
	assert_str(label.text).contains("gate")
