extends Node
## Audio playback: music + pooled SFX players, volume buses.
## Web-safe: playback only starts after user gesture (Click-to-Play) in the web shell.

enum SfxTier { CRITICAL, IMPORTANT, AMBIENT, LOW }

var master_volume: float = 0.8
var music_volume: float = 0.7
var sfx_volume: float = 0.8

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
	"ui_click": SfxTier.LOW,
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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	add_child(_music_player)
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
	_apply_volumes()
	PerformanceManager.quality_changed.connect(_on_performance_tier_changed)
	PerformanceManager.quality_changed.connect(_on_stress_changed)

## Simple procedural SFX: short synthesized tone, cached per sound id.
## No external audio assets needed â€” layered, swept, soft-clipped synthesis.
func play_tone(id: String, freq: float, duration: float, kind: String = "sine", volume_db_offset: float = 0.0, glide_ratio: float = 1.0) -> void:
	var stream: AudioStreamWAV = _get_tone(id, freq, duration, kind, glide_ratio)
	play_sfx(stream, volume_db_offset, randf_range(0.96, 1.05))

## Layered one-shot: each layer = {freq, glide, dur, delay, kind, gain}.
## glide = end/start frequency ratio (sweep), delay in seconds.
func play_recipe(id: String, layers: Array, volume_db_offset: float = 0.0) -> void:
	var stream: AudioStreamWAV = _tone_cache.get(id, null)
	if stream == null:
		stream = _build_wav(layers)
		_tone_cache[id] = stream
	play_sfx(stream, volume_db_offset, randf_range(0.96, 1.05))

## Tier-aware recipe playback.
func play_recipe_tiered(id: String, layers: Array, tier: int, volume_db_offset: float = 0.0) -> void:
	var stream: AudioStreamWAV = _tone_cache.get(id, null)
	if stream == null:
		stream = _build_wav(layers)
		_tone_cache[id] = stream
	play_sfx_tiered(stream, tier, volume_db_offset, randf_range(0.96, 1.05))

const _SR := 32000

func _get_tone(id: String, freq: float, duration: float, kind: String, glide: float = 1.0) -> AudioStreamWAV:
	if _tone_cache.has(id):
		return _tone_cache[id]
	var stream := _build_wav([{ "freq": freq, "glide": glide, "dur": duration, "delay": 0.0, "kind": kind, "gain": 1.0 }])
	_tone_cache[id] = stream
	return stream

func _build_wav(layers: Array) -> AudioStreamWAV:
	var total := 0.0
	for l in layers:
		total = maxf(total, float(l.get("delay", 0.0)) + float(l.get("dur", 0.1)))
	var count := maxi(int(total * _SR), 32)
	var mix := PackedFloat32Array()
	mix.resize(count)
	for l in layers:
		var freq := float(l["freq"])
		var glide := maxf(float(l.get("glide", 1.0)), 0.02)
		var dur := maxf(float(l["dur"]), 0.005)
		var delay := float(l.get("delay", 0.0))
		var kind := String(l.get("kind", "sine"))
		var gain := float(l.get("gain", 1.0))
		var start := int(delay * _SR)
		var n := int(dur * _SR)
		var decay := float(l.get("decay", 3.6))
		var phase := 0.0
		var lp := 0.0
		for i in range(n):
			var idx := start + i
			if idx >= count:
				break
			var progress := float(i) / float(n)
			var f := freq * pow(glide, progress)
			phase += f / _SR
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
			var env := minf(progress * 28.0, 1.0) * exp(-decay * progress)
			# Sub-millisecond noise attack = percussive punch
			if i < 140:
				env *= 0.4 + randf() * 0.9
			mix[idx] += lp * env * gain
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in range(count):
		var v := tanh(mix[i] * 1.6)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = _SR
	stream.data = data
	return stream

func play_music(stream: AudioStream, loop: bool = true) -> void:
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = loop
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()

func play_sfx(stream: AudioStream, volume_db_offset: float = 0.0, pitch: float = 1.0) -> void:
	play_sfx_tiered(stream, SfxTier.IMPORTANT, volume_db_offset, pitch)

## Play an SFX with importance-tier-based gating and volume ducking.
func play_sfx_tiered(stream: AudioStream, tier: int, volume_db_offset: float = 0.0, pitch: float = 1.0) -> void:
	# Rate-limit ambient/low-tier sounds under load
	if _GATE_THRESHOLDS[tier] > 0.0:
		var key: int = stream.get_instance_id()
		var last: float = float(_sfx_gate.get(key, -999.0))
		if Time.get_ticks_msec() - last < _GATE_THRESHOLDS[tier] * 1000.0:
			return
		_sfx_gate[key] = float(Time.get_ticks_msec())
	var player := _free_sfx_player()
	if player == null:
		if tier < SfxTier.AMBIENT:
			# Critical/important: steal the loudest non-critical player
			player = _sfx_players[0]
		else:
			return
	# Apply tier-based volume scaling (ducking under stress)
	var vol_scale: float = float(TIER_VOLUME_SCALE.get(tier, 1.0))
	player.stream = stream
	player.volume_db = linear_to_db(clampf(sfx_volume * master_volume * vol_scale, 0.001, 1.0)) + volume_db_offset
	player.pitch_scale = pitch
	player.play()

func _free_sfx_player() -> AudioStreamPlayer:
	if _sfx_players.is_empty():
		return null
	for p in _sfx_players:
		if not p.playing:
			return p
	return _sfx_players[0]

## Named SFX presets used across the game.
func play_game_sfx(id: String) -> void:
	var tier: int = int(SFX_IMPORTANCE.get(id, SfxTier.IMPORTANT))
	match id:
		"weapon_fire":
			play_recipe_tiered("shoot_fb", [
				{"freq": 300.0, "glide": 0.35, "dur": 0.09, "kind": "saw", "gain": 0.9},
				{"freq": 0.0, "glide": 1.0, "dur": 0.025, "kind": "noise", "gain": 0.4},
			], tier, -6.0)
		"enemy_hit":
			play_recipe_tiered("hit", [
				{"freq": 520.0, "glide": 0.4, "dur": 0.045, "kind": "square", "gain": 0.7},
				{"freq": 0.0, "glide": 1.0, "dur": 0.02, "kind": "noise", "gain": 0.6},
			], tier, -9.0)
		"enemy_death":
			play_recipe_tiered("death", [
				{"freq": 180.0, "glide": 0.25, "dur": 0.2, "kind": "saw", "gain": 0.8},
				{"freq": 0.0, "glide": 1.0, "dur": 0.14, "kind": "noise", "gain": 0.55},
			], tier, -7.0)
		"xp_pickup":
			play_recipe_tiered("xp", [
				{"freq": 900.0, "glide": 1.65, "dur": 0.07, "kind": "sine", "gain": 0.8},
				{"freq": 1800.0, "glide": 1.4, "dur": 0.05, "delay": 0.03, "kind": "sine", "gain": 0.3},
			], tier, -11.0)
		"level_up":
			play_recipe_tiered("lvlup", [
				{"freq": 660.0, "dur": 0.13, "kind": "sine", "gain": 0.9},
				{"freq": 880.0, "dur": 0.13, "delay": 0.09, "kind": "sine", "gain": 0.9},
				{"freq": 1320.0, "dur": 0.3, "delay": 0.18, "kind": "sine", "gain": 1.0, "decay": 2.2},
				{"freq": 1651.0, "dur": 0.26, "delay": 0.18, "kind": "sine", "gain": 0.35, "decay": 2.2},
			], tier, -4.0)
		"boss_warn":
			play_recipe_tiered("boss_w", [
				{"freq": 110.0, "glide": 0.85, "dur": 0.18, "kind": "square", "gain": 1.0},
				{"freq": 110.0, "glide": 0.85, "dur": 0.18, "delay": 0.24, "kind": "square", "gain": 1.0},
				{"freq": 55.0, "glide": 0.7, "dur": 0.5, "kind": "sine", "gain": 0.8, "decay": 1.6},
			], tier, -2.0)
		"boss_die":
			play_recipe_tiered("boss_d", [
				{"freq": 160.0, "glide": 0.15, "dur": 0.9, "kind": "saw", "gain": 1.0, "decay": 1.8},
				{"freq": 0.0, "glide": 1.0, "dur": 0.55, "kind": "noise", "gain": 0.7, "decay": 2.0},
				{"freq": 48.0, "glide": 0.5, "dur": 1.0, "kind": "sine", "gain": 1.0, "decay": 1.2},
			], tier, -1.0)
		"ui_click":
			play_recipe_tiered("ui", [
				{"freq": 1050.0, "glide": 0.75, "dur": 0.035, "kind": "sine", "gain": 0.8},
			], tier, -10.0)
		"player_hurt":
			play_recipe_tiered("hurt", [
				{"freq": 170.0, "glide": 0.3, "dur": 0.14, "kind": "saw", "gain": 1.0},
				{"freq": 0.0, "glide": 1.0, "dur": 0.05, "kind": "noise", "gain": 0.7},
			], tier, -5.0)
		"ability":
			play_recipe_tiered("abil", [
				{"freq": 420.0, "glide": 2.6, "dur": 0.28, "kind": "zap", "gain": 0.8},
				{"freq": 220.0, "glide": 1.5, "dur": 0.34, "kind": "sine", "gain": 0.7, "decay": 2.0},
			], tier, -4.0)
		"relic_pickup":
			play_recipe_tiered("relic", [
				{"freq": 1320.0, "dur": 0.45, "kind": "sine", "gain": 0.9, "decay": 2.0},
				{"freq": 1980.0, "dur": 0.38, "delay": 0.05, "kind": "sine", "gain": 0.4, "decay": 2.0},
				{"freq": 2640.0, "dur": 0.3, "delay": 0.11, "kind": "sine", "gain": 0.22, "decay": 2.0},
			], tier, -8.0)

## Volume loading from save on demand.
func apply_saved_volumes() -> void:
	set_volumes(
		SaveManager.get_setting("master_volume", 0.8),
		SaveManager.get_setting("music_volume", 0.7),
		SaveManager.get_setting("sfx_volume", 0.8)
	)

func set_volumes(master: float, music: float, sfx: float) -> void:
	master_volume = master
	music_volume = music
	sfx_volume = sfx
	_apply_volumes()

func _apply_volumes() -> void:
	var music_db := linear_to_db(clampf(music_volume * master_volume, 0.001, 1.0))
	var sfx_db := linear_to_db(clampf(sfx_volume * master_volume, 0.001, 1.0))
	if _music_player:
		_music_player.volume_db = music_db
	for p in _sfx_players:
		p.volume_db = sfx_db

## Query function: MusicDirector uses this to cross-fade to the right ceiling.
func get_music_db() -> float:
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
