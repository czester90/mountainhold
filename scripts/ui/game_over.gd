extends CanvasLayer

## Watches the WaveSpawner and, on win (all waves repelled) or loss (too many breaches), freezes
## the game and shows an end screen with Zagraj ponownie / Menu główne. Built in code.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const PLAY := "res://scenes/play.tscn"

@export var spawner_path: NodePath

var _spawner: WaveSpawner
var _player: Node
var _shown := false
var _root: Control
var _title: Label
var _sub: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_spawner = get_node_or_null(spawner_path) as WaveSpawner
	var sr: Node = get_parent()
	_player = sr.get_node_or_null("Player") if sr else null
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(centre)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.custom_minimum_size = Vector2(420, 0)
	centre.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 56)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_sub = Label.new()
	_sub.add_theme_font_size_override("font_size", 22)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_color_override("font_color", Color(0.8, 0.82, 0.88))
	box.add_child(_sub)
	_button(box, "Zagraj ponownie", func(): _go(PLAY))
	_button(box, "Menu główne", func(): _go(MAIN_MENU))

func _button(parent: VBoxContainer, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	b.pressed.connect(_play_click)
	parent.add_child(b)

func _play_click() -> void:
	if not is_inside_tree():
		return
	var a := get_tree().root.get_node_or_null("Audio")
	if a:
		a.play_2d("ui_click", "UI")

func _process(_delta: float) -> void:
	if _shown or _spawner == null:
		return
	if _player and _player.has_method("is_dead") and _player.is_dead():
		_end("POLEGŁEŚ", "Ostrzał napastników cię dosięgnął.", Color(0.9, 0.4, 0.35))
	elif _spawner.lost():
		_end("TWIERDZA PADŁA", "Napastnicy skruszyli stołp — twierdza upadła.", Color(0.9, 0.4, 0.35))
	elif _spawner.won():
		_end("OBRONIONO!", "Odparto wszystkie fale. Stołp wytrzymał.", Color(0.6, 0.85, 1.0))

func _end(title: String, sub: String, col: Color) -> void:
	_shown = true
	_title.text = title
	_title.add_theme_color_override("font_color", col)
	_sub.text = sub
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _go(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
