extends Control

## Reusable settings overlay (mouse sensitivity + master volume). Built entirely in code so it
## needs no .tscn wiring. Reads/writes the GameSettings autoload and persists on close. Emits
## `closed` so the opener (main menu or pause menu) can restore its own view.

signal closed

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.custom_minimum_size = Vector2(420, 0)
	centre.add_child(box)

	var title := Label.new()
	title.text = "Ustawienia"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_slider_row(box, "Czułość myszy", 0.2, 3.0, GameSettings.mouse_sensitivity, _on_sens)
	_slider_row(box, "Głośność", 0.0, 1.0, GameSettings.master_volume, _on_vol)

	var back := Button.new()
	back.text = "Powrót"
	back.custom_minimum_size = Vector2(0, 44)
	back.pressed.connect(_on_back)
	back.pressed.connect(_play_click)
	box.add_child(back)

func _play_click() -> void:
	if not is_inside_tree():
		return
	var a := get_tree().root.get_node_or_null("Audio")
	if a:
		a.play_2d("ui_click", "UI")

func _slider_row(parent: VBoxContainer, label: String, lo: float, hi: float, value: float, cb: Callable) -> void:
	var row := VBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 20)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(0, 28)
	s.value_changed.connect(cb)
	row.add_child(s)
	parent.add_child(row)

func open() -> void:
	visible = true

func _on_sens(v: float) -> void:
	GameSettings.mouse_sensitivity = v

func _on_vol(v: float) -> void:
	GameSettings.master_volume = v
	GameSettings.apply()

func _on_back() -> void:
	GameSettings.save_settings()
	visible = false
	closed.emit()
