extends Node
## V8 procedural music: layered synth pads built from cached tone loops.
## Three intensity states cross-faded by game state (calm/tense/boss).
## All web-safe: zero audio assets, generated once and looped.

signal intensity_changed(state: int)

enum Intensity { CALM, TENSE, BOSS }

const LAYER_FADE := 1.5

var _players: Dictionary = {}   # Intensity -> AudioStreamPlayer
var _tweens: Dictionary = {}    # Intensity -> Tween
var _current: int = -1
var _built: bool = false
var _bus: String = "Master"  # Connected to AudioManager's volume bus

## Layer frequencies (dark-synth pads, A-minor family)
const CALM_NOTES := [220.0, 330.0, 440.0]
const TENSE_NOTES := [220.0, 293.66, 349.23, 440.0]
const BOSS_NOTES := [164.81, 220.0, 311.11, 415.30]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var eb: Node = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() != null else null
	if eb != null and eb.has_signal("settings_changed"):
		eb.settings_changed.connect(update_volumes)

## Build the three loop layers once. Called from Main after boot.
func build_music() -> void:
	if _built:
		return
	_built = true
	_players[Intensity.CALM] = _make_layer("music_calm", CALM_NOTES, 0.06)
	_players[Intensity.TENSE] = _make_layer("music_tense", TENSE_NOTES, 0.07)
	_players[Intensity.BOSS] = _make_layer("music_boss", BOSS_NOTES, 0.08)

func _make_layer(cache_id: String, notes: Array, gain: float) -> AudioStreamPlayer:
	# Layer a detuned stack of slow tones into one looped WAV
	var sample_rate := 22050
	var loop_len := int(sample_rate * 2.0)  # 2-second seamless pad loop
	var data := PackedByteArray()
	data.resize(loop_len * 2)
	for i in range(loop_len):
		var t := float(i) / sample_rate
		var value := 0.0
		for n in notes:
			value += sin(TAU * n * t)
			value += sin(TAU * n * 1.005 * t)  # detune shimmer
		value /= float(notes.size()) * 2.0
		var env := 0.85 + 0.15 * sin(TAU * t / 4.0)  # slower, gentler swell
		var s := int(clampf(value * env * gain, -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, s)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = loop_len
	var p := AudioStreamPlayer.new()
	p.bus = _bus  # Route through AudioManager's volume bus
	p.stream = stream
	p.volume_db = -60.0
	add_child(p)
	return p

## Switch intensity with a short cross-fade.
func set_intensity(state: int) -> void:
	if not _built or state == _current:
		return
	_current = state
	var audio_mgr: Node = Engine.get_main_loop().root.get_node_or_null("AudioManager") if Engine.get_main_loop() != null else null
	var music_ceiling: float = -80.0
	if audio_mgr != null and audio_mgr.has_method("get_music_db"):
		music_ceiling = audio_mgr.get_music_db()
	else:
		music_ceiling = linear_to_db(1.0)

	for key in _players:
		var p: AudioStreamPlayer = _players[key]
		if p == null:
			continue
		if _tweens.has(key) and _tweens[key] != null and _tweens[key].is_valid():
			_tweens[key].kill()

		var target_db := -80.0  # effectively silent
		if key == state:
			target_db = music_ceiling
			if not p.playing and p.is_inside_tree():
				p.volume_db = -80.0
				p.play()

		var tween := create_tween()
		_tweens[key] = tween
		tween.tween_property(p, "volume_db", target_db, LAYER_FADE)
	intensity_changed.emit(state)

## Dynamic volume update when AudioManager volume changes.
func update_volumes() -> void:
	if not _built:
		return
	var audio_mgr: Node = Engine.get_main_loop().root.get_node_or_null("AudioManager") if Engine.get_main_loop() != null else null
	var music_ceiling: float = -80.0
	if audio_mgr != null and audio_mgr.has_method("get_music_db"):
		music_ceiling = audio_mgr.get_music_db()

	for key in _players:
		var p: AudioStreamPlayer = _players[key]
		if p == null:
			continue
		if _tweens.has(key) and _tweens[key] != null and _tweens[key].is_valid():
			_tweens[key].kill()

		if music_ceiling <= -70.0:
			p.volume_db = -80.0
		else:
			if key == _current:
				var tween := create_tween()
				_tweens[key] = tween
				tween.tween_property(p, "volume_db", music_ceiling, 0.2)
			else:
				var tween := create_tween()
				_tweens[key] = tween
				tween.tween_property(p, "volume_db", -80.0, 0.5)

func stop_music() -> void:
	for key in _players:
		var p: AudioStreamPlayer = _players[key]
		if _tweens.has(key) and _tweens[key] != null and _tweens[key].is_valid():
			_tweens[key].kill()
		if p != null and p.playing:
			p.stop()
	_current = -1
