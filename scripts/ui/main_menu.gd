extends Control

## Main menu: title + Graj / Ustawienia / Wyjście. Built in code so no .tscn wiring is needed.
## "Graj" loads the playable siege scene; "Ustawienia" opens the shared settings overlay.

const PLAY_SCENE := "res://scenes/play.tscn"
const SETTINGS := preload("res://scenes/ui/settings_panel.tscn")

var _menu: VBoxContainer
var _settings: Control

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 20)
	_menu.custom_minimum_size = Vector2(360, 0)
	centre.add_child(_menu)

	var title := Label.new()
	title.text = "MOUNTAINHOLD"
	title.add_theme_font_size_override("font_size", 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(title)

	var sub := Label.new()
	sub.text = "Broń twierdzy z muru"
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(sub)

	_menu.add_child(_spacer(24))
	_button("Graj", _on_play)
	_button("Ustawienia", _on_settings)
	_button("Wyjście", _on_quit)

	_settings = SETTINGS.instantiate()
	add_child(_settings)
	_settings.closed.connect(func(): _menu.visible = true)

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(cb)
	b.pressed.connect(_play_click)
	_menu.add_child(b)

func _play_click() -> void:
	if not is_inside_tree():
		return
	var a := get_tree().root.get_node_or_null("Audio")
	if a:
		a.play_2d("ui_click", "UI")

func _on_play() -> void:
	get_tree().change_scene_to_file(PLAY_SCENE)

func _on_settings() -> void:
	_menu.visible = false
	_settings.open()

func _on_quit() -> void:
	get_tree().quit()
