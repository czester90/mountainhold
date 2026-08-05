extends Node

## Autoload holding player-facing settings (mouse sensitivity, master volume) so they survive
## scene changes and are readable from anywhere (player reads mouse_sensitivity; the settings
## panel writes here and calls apply()). Persisted to user:// so choices stick between runs.

const PATH := "user://settings.cfg"

var mouse_sensitivity: float = 1.0    # multiplier on the player's base sens
var master_volume: float = 0.8        # 0..1 linear
var ally_archers_fire_enabled: bool = true

func _ready() -> void:
	load_settings()
	apply()

func apply() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(master_volume, 0.0001, 1.0)))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.save(PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	mouse_sensitivity = cfg.get_value("input", "mouse_sensitivity", mouse_sensitivity)
	master_volume = cfg.get_value("audio", "master_volume", master_volume)
