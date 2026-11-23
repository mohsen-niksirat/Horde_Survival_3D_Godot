extends Node
## Audio playback: music + pooled SFX players, volume buses.
## Web-safe: playback only starts after user gesture (Click-to-Play) in the web shell.
##
## V31A: every SFX/music waveform is defined as *data* (SFX_RECIPES /
## MUSIC_LAYERS) and synthesised by a chunked builder. `prewarm_audio()` runs
## during the menu and fills the cache a few thousand samples per frame, so the
## first shot / level-up / boss death never pays a 50-250 ms PCM build mid-run
## and the music pads are not rebuilt from scratch on every new run.

enum SfxTier { CRITICAL, IMPORTANT, AMBIENT, LOW }

var master_volume: float = 0.8
var music_volume: float = 0.7
var sfx_volume: float = 0.8
## Independent mute flags for the music mix and the SFX mix.
var _music_muted: bool = false
var _sfx_muted: bool = false

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE := 12

## Audio importance metadata per SFX id — used for culling/ducking under load.
const SFX_IMPORTANCE := {
	"weapon_fire": SfxTier.IMPORTANT,
	"enemy_hit": SfxTier.AMBIENT,
	"enemy_death": SfxTier.IMPORTANT,
	"xp_pickup": SfxTier.AMBIENT,
	"level_up": SfxTier.CRITICAL,
	"boss_warn": SfxTier.CRITICAL,
	"boss_die": SfxTier.CRITICAL,
	"player_hurt": SfxTier.CRITICAL,
	"relic_pickup": SfxTier.CRITICAL,
	"ability": SfxTier.IMPORTANT,
	"dash": SfxTier.IMPORTANT,
	"ui_click": SfxTier.LOW,
	"ui_hover": SfxTier.LOW,
}

## Per-tier volume multipliers under stress / low quality.
const TIER_VOLUME_SCALE := {
	SfxTier.CRITICAL: 1.0,
	SfxTier.IMPORTANT: 0.85,
	SfxTier.AMBIENT: 0.6,
	SfxTier.LOW: 0.3,
}

## Dynamic SFX rate limiter: avoids audio spam under heavy load.
var _sfx_gate: Dictionary = {}
const _GATE_THRESHOLDS := {
	SfxTier.CRITICAL: 0.0,   # always
	SfxTier.IMPORTANT: 0.08, # ~12/sec
	SfxTier.AMBIENT: 0.15,   # ~6/sec
	SfxTier.LOW: 0.25,       # ~4/sec
}

## Procedural tone cache (web-friendly, zero assets): id -> AudioStreamWAV
var _tone_cache: Dictionary = {}

## Background prewarm state (menu-time, chunked).
var _prewarm_started: bool = false
var prewarm_done: bool = false
## Samples synthesised per frame while prewarming. Kept small enough that a
## chunk stays a few milliseconds even in WASM; Web halves both because
## GDScript there is roughly twice as slow per sample.
const PCM_CHUNK := 1024
const PCM_CHUNK_WEB := 512
const MUSIC_CHUNK := 512
const MUSIC_CHUNK_WEB := 256
var _chunk_sfx: int = PCM_CHUNK
var _chunk_music: int = MUSIC_CHUNK

const _SR := 32000
const _MUSIC_SR := 11025

## Every gameplay SFX as data. `cache` is the stream id (tests and
## play_recipe use the same keys), `layers` feed the synthesiser.
const SFX_RECIPES := {
	"weapon_fire": {"cache": "shoot_fb", "tier": SfxTier.IMPORTANT, "vol": -6.0, "layers": [
		{"freq": 300.0, "glide": 0.35, "dur": 0.09, "kind": "saw", "gain": 0.9},
		{"freq": 0.0, "glide": 1.0, "dur": 0.025, "kind": "noise", "gain": 0.4},
	]},
	"enemy_hit": {"cache": "hit", "tier": SfxTier.AMBIENT, "vol": -9.0, "layers": [
		{"freq": 520.0, "glide": 0.4, "dur": 0.045, "kind": "square", "gain": 0.7},
		{"freq": 0.0, "glide": 1.0, "dur": 0.02, "kind": "noise", "gain": 0.6},
	]},
	"enemy_death": {"cache": "death", "tier": SfxTier.IMPORTANT, "vol": -7.0, "layers": [
		{"freq": 180.0, "glide": 0.25, "dur": 0.2, "kind": "saw", "gain": 0.8},
		{"freq": 0.0, "glide": 1.0, "dur": 0.14, "kind": "noise", "gain": 0.55},
	]},
	"xp_pickup": {"cache": "xp", "tier": SfxTier.AMBIENT, "vol": -11.0, "layers": [
		{"freq": 900.0, "glide": 1.65, "dur": 0.07, "kind": "sine", "gain": 0.8},
		{"freq": 1800.0, "glide": 1.4, "dur": 0.05, "delay": 0.03, "kind": "sine", "gain": 0.3},
	]},
	"level_up": {"cache": "lvlup", "tier": SfxTier.CRITICAL, "vol": -4.0, "layers": [
		{"freq": 660.0, "dur": 0.13, "kind": "sine", "gain": 0.9},
		{"freq": 880.0, "dur": 0.13, "delay": 0.09, "kind": "sine", "gain": 0.9},
		{"freq": 1320.0, "dur": 0.3, "delay": 0.18, "kind": "sine", "gain": 1.0, "decay": 2.2},
		{"freq": 1651.0, "dur": 0.26, "delay": 0.18, "kind": "sine", "gain": 0.35, "decay": 2.2},
	]},
	"boss_warn": {"cache": "boss_w", "tier": SfxTier.CRITICAL, "vol": -2.0, "layers": [
		{"freq": 110.0, "glide": 0.85, "dur": 0.18, "kind": "square", "gain": 1.0},
		{"freq": 110.0, "glide": 0.85, "dur": 0.18, "delay": 0.24, "kind": "square", "gain": 1.0},
		{"freq": 55.0, "glide": 0.7, "dur": 0.5, "kind": "sine", "gain": 0.8, "decay": 1.6},
	]},
	"boss_die": {"cache": "boss_d", "tier": SfxTier.CRITICAL, "vol": -1.0, "layers": [
		{"freq": 160.0, "glide": 0.15, "dur": 0.9, "kind": "saw", "gain": 1.0, "decay": 1.8},
		{"freq": 0.0, "glide": 1.0, "dur": 0.55, "kind": "noise", "gain": 0.7, "decay": 2.0},
		{"freq": 48.0, "glide": 0.5, "dur": 1.0, "kind": "sine", "gain": 1.0, "decay": 1.2},
	]},
	"ui_click": {"cache": "ui", "tier": SfxTier.LOW, "vol": -10.0, "layers": [
		{"freq": 1050.0, "glide": 0.75, "dur": 0.035, "kind": "sine", "gain": 0.8},
	]},
	"ui_hover": {"cache": "ui_hover", "tier": SfxTier.LOW, "vol": -18.0, "layers": [
		{"freq": 1320.0, "glide": 1.12, "dur": 0.025, "kind": "sine", "gain": 0.5},
	]},
	"dash": {"cache": "dash", "tier": SfxTier.IMPORTANT, "vol": -7.0, "layers": [
		{"freq": 0.0, "glide": 1.0, "dur": 0.12, "kind": "noise", "gain": 0.5, "decay": 5.0},
		{"freq": 420.0, "glide": 2.2, "dur": 0.1, "kind": "saw", "gain": 0.35},
	]},
	"player_hurt": {"cache": "hurt", "tier": SfxTier.CRITICAL, "vol": -5.0, "layers": [
		{"freq": 170.0, "glide": 0.3, "dur": 0.14, "kind": "saw", "gain": 1.0},
		{"freq": 0.0, "glide": 1.0, "dur": 0.05, "kind": "noise", "gain": 0.7},
	]},
	"ability": {"cache": "abil", "tier": SfxTier.IMPORTANT, "vol": -4.0, "layers": [
		{"freq": 420.0, "glide": 2.6, "dur": 0.28, "kind": "zap", "gain": 0.8},
		{"freq": 220.0, "glide": 1.5, "dur": 0.34, "kind": "sine", "gain": 0.7, "decay": 2.0},
	]},
	"relic_pickup": {"cache": "relic", "tier": SfxTier.CRITICAL, "vol": -8.0, "layers": [
		{"freq": 1320.0, "dur": 0.45, "kind": "sine", "gain": 0.9, "decay": 2.0},
		{"freq": 1980.0, "dur": 0.38, "delay": 0.05, "kind": "sine", "gain": 0.4, "decay": 2.0},
		{"freq": 2640.0, "dur": 0.3, "delay": 0.11, "kind": "sine", "gain": 0.22, "decay": 2.0},
	]},
	"victory": {"cache": "victory", "tier": SfxTier.CRITICAL, "vol": -2.0, "layers": [
		{"freq": 523.0, "dur": 0.18, "kind": "sine", "gain": 0.9},
		{"freq": 659.0, "dur": 0.18, "delay": 0.16, "kind": "sine", "gain": 0.9},
		{"freq": 784.0, "dur": 0.18, "delay": 0.32, "kind": "sine", "gain": 0.95},
		{"freq": 1046.0, "dur": 0.55, "delay": 0.48, "kind": "sine", "gain": 1.0, "decay": 1.8},
	]},
	# Per-weapon fire sounds (used by WeaponController and prewarmed here so
	# the first shot of a run never synthesises mid-combat).
	"shoot_fireball": {"cache": "shoot_fireball", "tier": SfxTier.IMPORTANT, "vol": -6.0, "layers": [
		{"freq": 260.0, "glide": 0.28, "dur": 0.2, "kind": "saw", "gain": 1.0},
		{"freq": 0.0, "glide": 1.0, "dur": 0.08, "kind": "noise", "gain": 0.45},
	]},
	"shoot_missile": {"cache": "shoot_missile", "tier": SfxTier.IMPORTANT, "vol": -10.0, "layers": [
		{"freq": 1400.0, "glide": 0.22, "dur": 0.11, "kind": "sine", "gain": 0.9},
		{"freq": 2800.0, "glide": 0.3, "dur": 0.05, "kind": "sine", "gain": 0.25},
	]},
	"shoot_spear": {"cache": "shoot_spear", "tier": SfxTier.IMPORTANT, "vol": -8.0, "layers": [
		{"freq": 950.0, "glide": 0.12, "dur": 0.07, "kind": "square", "gain": 0.8},
		{"freq": 0.0, "glide": 1.0, "dur": 0.03, "kind": "noise", "gain": 0.6},
	]},
	"shoot_lightning": {"cache": "shoot_lightning", "tier": SfxTier.IMPORTANT, "vol": -5.0, "layers": [
		{"freq": 0.0, "glide": 1.0, "dur": 0.17, "kind": "noise", "gain": 0.75},
		{"freq": 95.0, "glide": 0.45, "dur": 0.24, "kind": "sine", "gain": 0.95, "decay": 2.4},
		{"freq": 700.0, "glide": 0.3, "dur": 0.09, "kind": "zap", "gain": 0.5},
	]},
}

## Three procedural music pads. Kept here (not in MusicDirector) so the PCM is
## generated once per session instead of once per run.
const MUSIC_LAYERS := {
	"music_calm": {"notes": [220.0, 330.0, 440.0], "gain": 0.06},
	"music_tense": {"notes": [220.0, 293.66, 349.23, 440.0], "gain": 0.07},
	"music_boss": {"notes": [164.81, 220.0, 311.11, 415.30], "gain": 0.08},
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		_chunk_sfx = PCM_CHUNK_WEB
		_chunk_music = MUSIC_CHUNK_WEB
	_ensure_players()
	PerformanceManager.quality_changed.connect(_on_performance_tier_changed)

func _ensure_players() -> void:
	if _music_player == null:
		_music_player = AudioStreamPlayer.new()
		_music_player.bus = "Master"
		add_child(_music_player)
	if _sfx_players.is_empty():
		for i in range(SFX_POOL_SIZE):
			var p := AudioStreamPlayer.new()
			add_child(p)
			_sfx_players.append(p)
		_apply_volumes()

## Simple procedural SFX: short synthesized tone, cached per sound id.
## No external audio assets needed — layered, swept, soft-clipped synthesis.
func play_tone(id: String, freq: float, duration: float, kind: String = "sine", volume_db_offset: float = 0.0, glide_ratio: float = 1.0) -> void:
	var stream: AudioStreamWAV = _get_tone(id, freq, duration, kind, glide_ratio)
	play_sfx(stream, volume_db_offset, randf_range(0.96, 1.05))

## Layered one-shot: each layer = {freq, glide, dur, delay, kind, gain}.
## glide = end/start frequency ratio (sweep), delay in seconds.
func play_recipe(id: String, layers: Array, volume_db_offset: float = 0.0) -> void:
	var stream: AudioStreamWAV = _stream_for(id, layers)
	play_sfx(stream, volume_db_offset, randf_range(0.96, 1.05))

## Tier-aware recipe playback.
func play_recipe_tiered(id: String, layers: Array, tier: int, volume_db_offset: float = 0.0) -> void:
	var stream: AudioStreamWAV = _stream_for(id, layers)
	play_sfx_tiered(stream, tier, volume_db_offset, randf_range(0.96, 1.05))

## Cache lookup + first-use synthesis. The prewarm pass fills this cache
## during the menu, so by the time gameplay starts this is a plain lookup.
func _stream_for(id: String, layers: Array) -> AudioStreamWAV:
	var stream: AudioStreamWAV = _tone_cache.get(id, null)
	if stream == null:
		stream = _build_wav(layers)
		_tone_cache[id] = stream
	return stream

func _get_tone(id: String, freq: float, duration: float, kind: String, glide: float = 1.0) -> AudioStreamWAV:
	if _tone_cache.has(id):
		return _tone_cache[id]
	var stream := _build_wav([{ "freq": freq, "glide": glide, "dur": duration, "delay": 0.0, "kind": kind, "gain": 1.0 }])
	_tone_cache[id] = stream
	return stream

## Expand recipe dictionaries into render-ready layer state.
func _layer_state(layers: Array) -> Array:
	var out: Array = []
	for l in layers:
		out.append({
			"freq": float(l["freq"]),
			"glide": maxf(float(l.get("glide", 1.0)), 0.02),
			"dur": maxf(float(l["dur"]), 0.005),
			"delay": float(l.get("delay", 0.0)),
			"kind": String(l.get("kind", "sine")),
			"gain": float(l.get("gain", 1.0)),
			"decay": float(l.get("decay", 3.6)),
			"phase": 0.0,
			"lp": 0.0,
		})
	return out

## Render [from, to) samples straight into the WAV byte buffer. Layer phase,
## frequency and low-pass state persist in the state dictionaries so the
## buffer can be filled across several frames without seams.
func _render_into(state: Array, data: PackedByteArray, from: int, to: int) -> void:
	var size := to - from
	var block := PackedFloat32Array()
	block.resize(size)
	for p in state:
		var start := int(float(p["delay"]) * _SR)
		var n := int(float(p["dur"]) * _SR)
		if n <= 0:
			continue
		var lo := maxi(from, start)
		var hi := mini(to, start + n)
		if lo >= hi:
			continue
		# `freq` advances sample by sample; persisting it in the layer state
		# keeps a chunked build in phase with a single-block build.
		var freq: float = p["freq"]
		var glide: float = p["glide"]
		var kind: String = p["kind"]
		var gain: float = p["gain"]
		var decay: float = p["decay"]
		var phase: float = p["phase"]
		var lp: float = p["lp"]
		# Incremental glide + envelope: two multiplies per sample instead of
		# pow()/exp() — same curve, a fraction of the cost in GDScript/WASM.
		var glide_step: float = pow(glide, 1.0 / float(n))
		var decay_step: float = exp(-decay / float(n))
		var env_decay: float = pow(decay_step, float(lo - start))
		var inv_n := 1.0 / float(n)
		for i in range(lo, hi):
			var progress := float(i - start) * inv_n
			phase += freq / _SR
			freq *= glide_step
			var raw := 0.0
			match kind:
				"sine":
					raw = sin(TAU * phase)
				"square":
					raw = sin(TAU * phase) + 0.5 * sin(TAU * 3.0 * phase) + 0.25 * sin(TAU * 5.0 * phase)
					raw = clampf(raw * 0.7, -1.0, 1.0)
				"saw":
					raw = 2.0 * fmod(phase, 1.0) - 1.0
				"noise":
					raw = randf_range(-1.0, 1.0)
				"zap":
					# FM crackle for electric / magic zaps
					raw = sin(TAU * phase * 4.0 + sin(TAU * phase * 2.3) * 5.0)
				_:
					raw = sin(TAU * phase)
			# One-pole lowpass: tames aliasing fizz on square/saw
			lp += (raw - lp) * 0.5
			var env := minf(progress * 28.0, 1.0) * env_decay
			env_decay *= decay_step
			# Sub-millisecond noise attack = percussive punch
			if i - start < 140:
				env *= 0.4 + randf() * 0.9
			block[i - from] += lp * env * gain
		p["phase"] = phase
		p["lp"] = lp
		p["freq"] = freq
	# Soft-clip + quantise this block. Encoding per block keeps the whole
	# build (including the tanh pass) inside the per-frame budget.
	for i in range(size):
		var v := tanh(block[i] * 1.6)
		data.encode_s16((from + i) * 2, int(clampf(v, -1.0, 1.0) * 32000.0))

func _recipe_length(layers: Array) -> int:
	var total := 0.0
	for l in layers:
		total = maxf(total, float(l.get("delay", 0.0)) + float(l.get("dur", 0.1)))
	return maxi(int(total * _SR), 32)

func _make_wav(data: PackedByteArray, mix_rate: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.data = data
	return stream

func _build_wav(layers: Array) -> AudioStreamWAV:
	var state := _layer_state(layers)
	var count := _recipe_length(layers)
	var data := PackedByteArray()
	data.resize(count * 2)
	var i := 0
	while i < count:
		var stop := mini(i + _chunk_sfx, count)
		_render_into(state, data, i, stop)
		i = stop
	return _make_wav(data, _SR)

## Chunked variant: identical output, but yields to the frame loop every
## PCM_CHUNK samples so baking never blocks a rendered frame.
func _build_wav_chunked(layers: Array) -> AudioStreamWAV:
	var state := _layer_state(layers)
	var count := _recipe_length(layers)
	var data := PackedByteArray()
	data.resize(count * 2)
	var i := 0
	while i < count:
		var stop := mini(i + _chunk_sfx, count)
		_render_into(state, data, i, stop)
		i = stop
		if i < count:
			await get_tree().process_frame
	return _make_wav(data, _SR)

## Music pad: 2-second detuned stack, looped. Same maths as the old
## MusicDirector local builder, now cached for the whole session.
func _render_music_block(notes: Array, gain: float, data: PackedByteArray, from: int, to: int) -> void:
	var note_scale := 1.0 / (float(notes.size()) * 2.0)
	for i in range(from, to):
		var t := float(i) / _MUSIC_SR
		var value := 0.0
		for n in notes:
			value += sin(TAU * n * t)
			value += sin(TAU * n * 1.005 * t)  # detune shimmer
		value *= note_scale
		var env := 0.85 + 0.15 * sin(TAU * t / 4.0)
		data.encode_s16(i * 2, int(clampf(value * env * gain, -1.0, 1.0) * 32000.0))

func _music_stream(data: PackedByteArray) -> AudioStreamWAV:
	var loop_len := data.size() / 2
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = _MUSIC_SR
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = loop_len
	return stream

func _build_music_layer(cfg: Dictionary) -> AudioStreamWAV:
	var notes: Array = cfg["notes"]
	var gain: float = float(cfg.get("gain", 0.06))
	var loop_len := int(_MUSIC_SR * 2.0)
	var data := PackedByteArray()
	data.resize(loop_len * 2)
	_render_music_block(notes, gain, data, 0, loop_len)
	return _music_stream(data)

func _build_music_layer_chunked(cfg: Dictionary) -> AudioStreamWAV:
	var notes: Array = cfg["notes"]
	var gain: float = float(cfg.get("gain", 0.06))
	var loop_len := int(_MUSIC_SR * 2.0)
	var data := PackedByteArray()
	data.resize(loop_len * 2)
	var i := 0
	while i < loop_len:
		var stop := mini(i + _chunk_music, loop_len)
		_render_music_block(notes, gain, data, i, stop)
		i = stop
		if i < loop_len:
			await get_tree().process_frame
	return _music_stream(data)

## Shared music stream (built once, reused by every run).
func get_music_stream(id: String) -> AudioStreamWAV:
	if _tone_cache.has(id):
		return _tone_cache[id]
	var cfg: Dictionary = MUSIC_LAYERS.get(id, {})
	if cfg.is_empty():
		return null
	var stream := _build_music_layer(cfg)
	_tone_cache[id] = stream
	return stream

## Menu-time background baking. Idempotent; safe to call from every scene.
## Builds one stream at a time, yielding between chunks and between sounds.
func prewarm_audio() -> void:
	if _prewarm_started or prewarm_done:
		return
	_prewarm_started = true
	_prewarm_coroutine()

func _prewarm_coroutine() -> void:
	# Music first: the pads are needed the instant a run starts, and the three
	# layers are the longest buffers. A player who clicks Play immediately
	# still finds them cached in the common case (menu dwell > ~2 s).
	for id in MUSIC_LAYERS:
		if not _tone_cache.has(id):
			_tone_cache[id] = await _build_music_layer_chunked(MUSIC_LAYERS[id])
		await get_tree().process_frame
	# Then the gameplay SFX, in recipe order (the most-fired sounds are first).
	for id in SFX_RECIPES:
		var recipe: Dictionary = SFX_RECIPES[id]
		var key := String(recipe["cache"])
		if not _tone_cache.has(key):
			_tone_cache[key] = await _build_wav_chunked(recipe["layers"])
		await get_tree().process_frame
	prewarm_done = true

func play_music(stream: AudioStream, loop: bool = true) -> void:
	_ensure_players()
	if _music_player == null:
		return
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = loop
	if _music_player.is_inside_tree():
		_music_player.play()

func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()

func play_sfx(stream: AudioStream, volume_db_offset: float = 0.0, pitch: float = 1.0) -> void:
	play_sfx_tiered(stream, SfxTier.IMPORTANT, volume_db_offset, pitch)

## Play an SFX with importance-tier-based gating and volume ducking.
func play_sfx_tiered(stream: AudioStream, tier: int, volume_db_offset: float = 0.0, pitch: float = 1.0) -> void:
	_ensure_players()
	if _sfx_players.is_empty() or stream == null:
		return
	# Rate-limit ambient/low-tier sounds under load
	if _GATE_THRESHOLDS[tier] > 0.0:
		var key: int = stream.get_instance_id()
		var last: float = float(_sfx_gate.get(key, -999.0))
		if Time.get_ticks_msec() - last < _GATE_THRESHOLDS[tier] * 1000.0:
			return
		_sfx_gate[key] = float(Time.get_ticks_msec())
	var player := _free_sfx_player()
	if player == null:
		if tier < SfxTier.AMBIENT and not _sfx_players.is_empty():
			# Critical/important: steal the loudest non-critical player
			player = _sfx_players[0]
		else:
			return
	if player == null:
		return
	# Apply tier-based volume scaling (ducking under stress)
	var vol_scale: float = float(TIER_VOLUME_SCALE.get(tier, 1.0))
	player.stream = stream
	player.volume_db = linear_to_db(clampf(sfx_volume * master_volume * vol_scale, 0.001, 1.0)) + volume_db_offset
	player.pitch_scale = pitch
	if player.is_inside_tree():
		player.play()

func _free_sfx_player() -> AudioStreamPlayer:
	if _sfx_players.is_empty():
		return null
	for p in _sfx_players:
		if not p.playing:
			return p
	return _sfx_players[0]

## Named SFX presets used across the game. Everything resolves through
## SFX_RECIPES so prewarm and playback can never drift apart.
func play_game_sfx(id: String) -> void:
	var recipe: Dictionary = SFX_RECIPES.get(id, {})
	if recipe.is_empty():
		return
	var tier: int = int(SFX_IMPORTANCE.get(id, recipe.get("tier", SfxTier.IMPORTANT)))
	var stream := _stream_for(String(recipe["cache"]), recipe["layers"])
	play_sfx_tiered(stream, tier, float(recipe.get("vol", 0.0)), randf_range(0.96, 1.05))

## Volume loading from save on demand.
func apply_saved_volumes() -> void:
	set_volumes(
		SaveManager.get_setting("master_volume", 0.8),
		SaveManager.get_setting("music_volume", 0.7),
		SaveManager.get_setting("sfx_volume", 0.8)
	)
	_music_muted = bool(SaveManager.get_setting("music_muted", false))
	_sfx_muted = bool(SaveManager.get_setting("sfx_muted", false))
	_apply_volumes()

## Mute the music without touching the SFX mix (and vice versa).
func set_music_muted(muted: bool) -> void:
	_music_muted = muted
	_apply_volumes()
	SaveManager.set_setting("music_muted", muted)

func set_sfx_muted(muted: bool) -> void:
	_sfx_muted = muted
	_apply_volumes()
	SaveManager.set_setting("sfx_muted", muted)

func is_music_muted() -> bool:
	return _music_muted

func is_sfx_muted() -> bool:
	return _sfx_muted

## Toggle helper for the Settings UI.
func toggle_music_muted() -> bool:
	set_music_muted(not _music_muted)
	return _music_muted

func toggle_sfx_muted() -> bool:
	set_sfx_muted(not _sfx_muted)
	return _sfx_muted

func set_volumes(master: float, music: float, sfx: float) -> void:
	master_volume = master
	music_volume = music
	sfx_volume = sfx
	_apply_volumes()
	var eb: Node = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() != null else null
	if eb != null and eb.has_signal("settings_changed"):
		eb.settings_changed.emit()

func _apply_volumes() -> void:
	var music_db := get_music_db()
	var sfx_db := -80.0 if (master_volume <= 0.001 or sfx_volume <= 0.001 or _sfx_muted) else linear_to_db(clampf(sfx_volume * master_volume, 0.001, 1.0))
	if _music_player:
		_music_player.volume_db = music_db
	for p in _sfx_players:
		p.volume_db = sfx_db
	var tree: SceneTree = get_tree() if is_inside_tree() else null
	if tree != null and tree.root != null:
		var md: Node = tree.root.find_child("MusicDirector", true, false)
		if md != null and md.has_method("update_volumes"):
			md.update_volumes()

## Query function: MusicDirector uses this to cross-fade to the right ceiling.
func get_music_db() -> float:
	if master_volume <= 0.001 or music_volume <= 0.001 or _music_muted:
		return -80.0
	return linear_to_db(clampf(music_volume * master_volume, 0.001, 1.0))

## Under stress or low quality, reduce SFX pool size and shorten gate thresholds.
func _on_performance_tier_changed(tier: int) -> void:
	var pm: Node = PerformanceManager
	var reduce: bool = bool(pm.stress_mode) or int(pm.quality) <= int(pm.Quality.LOW)
	# Shrink SFX pool under pressure to free audio voices
	var target_size := SFX_POOL_SIZE if not reduce else 6
	while _sfx_players.size() > target_size:
		var p: AudioStreamPlayer = _sfx_players.pop_back()
		p.queue_free()
	while _sfx_players.size() < target_size:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
	_apply_volumes()

## Stress state changed — re-apply settings.
func _on_stress_changed(_tier: int) -> void:
	_on_performance_tier_changed(_tier)
