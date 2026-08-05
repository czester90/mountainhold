extends Node

const RATE: int = 22050

var _sfx: Dictionary = {}
var _buses := ["Music", "Ambience", "Combat", "Voices", "UI"]

func _ready() -> void:
	_setup_buses()
	_generate_sfx()

func _setup_buses() -> void:
	for bus_name in _buses:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx: int = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

func play_2d(name: String, bus: String = "Combat", pitch_variance: float = 0.08) -> void:
	if not _sfx.has(name):
		return
	var p := AudioStreamPlayer.new()
	p.stream = _sfx[name]
	p.bus = bus
	p.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	_attach(p)

func play_3d(name: String, pos: Vector3, bus: String = "Combat", pitch_variance: float = 0.1) -> void:
	if not _sfx.has(name):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _sfx[name]
	p.bus = bus
	p.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	p.unit_size = 8.0
	p.max_distance = 90.0
	p.position = pos
	_attach(p)

func get_stream(name: String) -> AudioStream:
	return _sfx.get(name)

func _attach(player: Node) -> void:
	# parent to this autoload (always safely in-tree) rather than current_scene, which is "busy
	# setting up children" during scene load — 3D players use an absolute position so origin-parenting
	# is fine, and they self-free on finished.
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func _generate_sfx() -> void:
	_sfx["bow_release"] = _synth(0.18, func(t: float) -> float:
		var env: float = exp(-t * 22.0)
		return (sin(t * TAU * 190.0) * 0.6 + _noise() * 0.4) * env)
	_sfx["impact_body"] = _synth(0.16, func(t: float) -> float:
		var env: float = exp(-t * 26.0)
		return (sin(t * TAU * 95.0) * 0.5 + _noise() * 0.5) * env)
	_sfx["impact_env"] = _synth(0.09, func(t: float) -> float:
		return _noise() * exp(-t * 60.0))
	_sfx["gate_impact"] = _synth(0.55, func(t: float) -> float:
		var env: float = exp(-t * 6.5)
		return (sin(t * TAU * 58.0) * 0.7 + _noise() * 0.3) * env)
	_sfx["enemy_death"] = _synth(0.34, func(t: float) -> float:
		var env: float = exp(-t * 8.0)
		var freq: float = lerpf(210.0, 90.0, clampf(t / 0.34, 0.0, 1.0))
		return (sin(t * TAU * freq) * 0.5 + _noise() * 0.5) * env)
	_sfx["ui_click"] = _synth(0.05, func(t: float) -> float:
		return sin(t * TAU * 760.0) * exp(-t * 40.0) * 0.5)
	_sfx["wind"] = _synth_loop(2.2, func(t: float) -> float:
		var slow: float = (sin(t * TAU * 0.4) * 0.5 + 0.5)
		return _noise() * 0.12 * (0.4 + slow * 0.6))
	_sfx["fire"] = _synth_loop(1.3, func(t: float) -> float:
		var crackle: float = 1.0 if randf() < 0.02 else 0.15
		return _noise() * 0.1 * crackle)

func _synth(duration: float, fn: Callable) -> AudioStreamWAV:
	return _build(duration, fn, false)

func _synth_loop(duration: float, fn: Callable) -> AudioStreamWAV:
	return _build(duration, fn, true)

func _build(duration: float, fn: Callable, looping: bool) -> AudioStreamWAV:
	var count: int = int(duration * RATE)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var t: float = float(i) / RATE
		var s: float = clampf(fn.call(t), -1.0, 1.0)
		var v: int = int(s * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if looping:
		wav.loop_mode = AudioStreamWAV.LOOP_PINGPONG
		wav.loop_begin = 0
		wav.loop_end = count
	return wav

func _noise() -> float:
	return randf() * 2.0 - 1.0
