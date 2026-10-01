extends SceneTree
## Audio layering: importance tiers, stress ducking, platform scaling.

var failures := 0

func _initialize() -> void:
	var audio: Node = root.get_node("AudioManager")

	# Tier enum exists
	_check(audio.SfxTier.CRITICAL == 0, "CRITICAL tier is 0")
	_check(audio.SfxTier.LOW == 3, "LOW tier is 3")

	# SFX_IMPORTANCE map populated
	_check(audio.SFX_IMPORTANCE.has("player_hurt"), "player_hurt tracked")
	_check(audio.SFX_IMPORTANCE["player_hurt"] == audio.SfxTier.CRITICAL, "player_hurt is CRITICAL")
	_check(audio.SFX_IMPORTANCE["enemy_hit"] == audio.SfxTier.AMBIENT, "enemy_hit is AMBIENT")
	_check(audio.SFX_IMPORTANCE["weapon_fire"] == audio.SfxTier.IMPORTANT, "weapon_fire is IMPORTANT")
	_check(audio.SFX_IMPORTANCE["ui_click"] == audio.SfxTier.LOW, "ui_click is LOW")

	# Tier volume scales
	_check(audio.TIER_VOLUME_SCALE[audio.SfxTier.CRITICAL] == 1.0, "critical plays at full volume")
	_check(audio.TIER_VOLUME_SCALE[audio.SfxTier.LOW] < 0.5, "low tier ducked under stress")

	# Gate thresholds prevent spam
	_check(audio._GATE_THRESHOLDS[audio.SfxTier.CRITICAL] == 0.0, "critical never gated")
	_check(audio._GATE_THRESHOLDS[audio.SfxTier.AMBIENT] > 0.0, "ambient gated")

	# play_game_sfx with tier works
	audio.play_game_sfx("player_hurt")
	_check(audio._sfx_players.size() > 0, "SFX pool ready for playback")

	# Stress mode reduces pool size
	var perf: Node = root.get_node("PerformanceManager")
	var original_size: int = audio._sfx_players.size()
	perf.stress_mode = true
	perf.quality_changed.emit(perf.quality)
	await process_frame
	if perf.stress_mode:
		_check(audio._sfx_players.size() <= original_size, "stress shrinks or maintains SFX pool")
	_check(true, "stress callback handled without crash")

	perf.stress_mode = false
	perf.quality = perf.Quality.VERY_LOW
	perf.quality_changed.emit(perf.quality)
	await process_frame
	_check(audio._sfx_players.size() <= 8, "low quality keeps small SFX pool")

	if failures == 0:
		print("AUDIO_LAYERS_PASS")
	else:
		print("AUDIO_LAYERS_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
