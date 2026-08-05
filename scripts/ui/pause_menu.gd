extends CanvasLayer

## Pause overlay for the siege scene. Owns the Esc key: Esc toggles pause. While paused the
## tree is frozen (get_tree().paused) and the mouse is freed; resuming recaptures it. process_mode
## ALWAYS so it keeps running while everything else is paused. Offers Wznów / Ustawienia /
## Menu główne / Wyjście.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const SETTINGS := preload("res://scenes/ui/settings_panel.tscn")

var _root: Control
var _menu: VBoxContainer
var _settings: Control
var _paused := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(centre)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 18)
	_menu.custom_minimum_size = Vector2(340, 0)
	centre.add_child(_menu)

	var title := Label.new()
	title.text = "PAUZA"
	title.add_theme_font_size_override("font_size", 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(title)

	_button("Wznów", _resume)
	_button("Ustawienia", _open_settings)
	_button("Menu główne", _to_main_menu)
	_button("Wyjście", func(): get_tree().quit())

	_settings = SETTINGS.instantiate()
	_root.add_child(_settings)
	_settings.closed.connect(func(): _menu.visible = true)

func _button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	b.pressed.connect(_play_click)
	_menu.add_child(b)

func _play_click() -> void:
	if not is_inside_tree():
		return
	var a := get_tree().root.get_node_or_null("Audio")
	if a:
		a.play_2d("ui_click", "UI")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		# if Settings is open, Esc returns from it (saves) — don't toggle pause
		if _settings.visible:
			_settings.call("_on_back")
			_menu.visible = true
			get_viewport().set_input_as_handled()
			return
		# if something ELSE paused the tree (the game-over overlay), ignore Esc entirely
		if get_tree().paused and not _paused:
			return
		if _paused:
			_resume()
		else:
			_pause()
		get_viewport().set_input_as_handled()

func _pause() -> void:
	_paused = true
	get_tree().paused = true
	_menu.visible = true
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _resume() -> void:
	_paused = false
	get_tree().paused = false
	_root.visible = false
	_settings.visible = false
	_menu.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _open_settings() -> void:
	_menu.visible = false
	_settings.open()

func _to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)
