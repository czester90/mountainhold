extends Node3D

## Stage 00 startup validation scene controller.
## Confirms the project boots on Forward+, renders a lit ground plane with a
## 1.8 m human reference capsule, and drives a live debug readout.

@onready var _debug_label: Label = $DebugLayer/DebugPanel/MarginContainer/DebugLabel
@onready var _camera: Camera3D = $Camera

var _renderer_name: String = ""

func _ready() -> void:
	_renderer_name = _resolve_renderer_name()
	_camera.look_at(Vector3(0.0, 0.9, 0.0), Vector3.UP)

func _process(_delta: float) -> void:
	_debug_label.text = _build_debug_text()

func _build_debug_text() -> String:
	var v: Dictionary = Engine.get_version_info()
	var version: String = "%d.%d.%d-%s" % [v.major, v.minor, v.patch, v.status]
	var current: Node = get_tree().current_scene
	var scene_path: String = current.scene_file_path if current else "(none)"
	var fps: int = int(Engine.get_frames_per_second())
	return "Godot version : %s\nRenderer      : %s\nCurrent scene : %s\nFPS           : %d" % [
		version, _renderer_name, scene_path, fps
	]

func _resolve_renderer_name() -> String:
	var method: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown"))
	match method:
		"forward_plus":
			return "Forward+"
		"mobile":
			return "Mobile"
		"gl_compatibility":
			return "Compatibility"
		_:
			return method
