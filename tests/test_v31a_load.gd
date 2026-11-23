extends SceneTree
## V31A load gate: menu-time audio baking (chunked synthesis identical to the
## one-shot path), music streams shared across runs, coalesced render-setting
## re-applies, and deferred enemy-pool prewarm.

var failures := 0

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
		print("  FAIL: ", message)

func _initialize() -> void:
	await process_frame

	var audio: Node = root.get_node("AudioManager")

	# --- every gameplay SFX (incl. the previously silent ones) has a recipe ---
	for id in ["weapon_fire", "enemy_hit", "enemy_death", "xp_pickup", "level_up",
			"boss_warn", "boss_die", "ui_click", "ui_hover", "dash", "player_hurt",
			"ability", "relic_pickup", "victory", "shoot_fireball", "shoot_missile",
			"shoot_spear", "shoot_lightning"]:
		_check(audio.SFX_RECIPES.has(id), "recipe present: " + id)

	# --- the chunked builder matches the one-shot builder ---
	# Each layer's first 140 samples are a randomised noise attack, so every
	# layer's attack window is skipped when comparing the two builds.
	var layers: Array = audio.SFX_RECIPES["level_up"]["layers"]
	var attack_windows: Array = []
	for l in layers:
		var attack_start := int(float(l.get("delay", 0.0)) * 32000.0)
		attack_windows.append([attack_start, attack_start + 140])
	var one_shot: AudioStreamWAV = audio._build_wav(layers)
	var chunked: AudioStreamWAV = await audio._build_wav_chunked(layers)
	_check(one_shot.data.size() == chunked.data.size(), "chunked length matches")
	var max_delta := 0
	for i in range(one_shot.data.size() / 2):
		var skipping := false
		for w in attack_windows:
			if i >= int(w[0]) and i < int(w[1]):
				skipping = true
				break
		if skipping:
			continue
		max_delta = maxi(max_delta, absi(
			one_shot.data.decode_s16(i * 2) - chunked.data.decode_s16(i * 2)))
	_check(max_delta == 0, "chunked synthesis is sample-identical (delta=%d)" % max_delta)

	# --- prewarm fills the cache and terminates ---
	audio.prewarm_audio()
	var guard := 0
	while not audio.prewarm_done and guard < 4000:
		await process_frame
		guard += 1
	_check(audio.prewarm_done, "prewarm completes (%d frames)" % guard)
	_check(audio._tone_cache.has("shoot_fireball"), "weapon fire baked during prewarm")
	_check(audio._tone_cache.has("boss_d"), "long boss SFX baked during prewarm")
	var calm: AudioStreamWAV = audio._tone_cache.get("music_calm", null)
	_check(calm != null and calm.loop_mode == AudioStreamWAV.LOOP_FORWARD, "calm pad cached + looped")

	# --- MusicDirector reuses the cached pads (no per-run re-synthesis) ---
	var music := Node.new()
	music.set_script(load("res://scripts/audio/music_director.gd"))
	root.add_child(music)
	music.build_music()
	_check(music._players.size() == 3, "three music layers built")
	var calm_player: AudioStreamPlayer = music._players.get(0, null)
	_check(calm_player != null and calm_player.stream == calm, "calm layer shares the cached stream")
	music.queue_free()
	await process_frame

	# --- render-setting re-applies coalesce during a scene load ---
	var perf: Node = root.get_node("PerformanceManager")
	perf._reapply_queued = false
	var light_a := DirectionalLight3D.new()
	var light_b := DirectionalLight3D.new()
	root.add_child(light_a)
	root.add_child(light_b)
	_check(perf._reapply_queued, "first light queues one deferred re-apply")
	await process_frame
	_check(not perf._reapply_queued, "deferred re-apply ran once and cleared the flag")
	light_a.queue_free()
	light_b.queue_free()
	await process_frame

	# --- enemy prewarm is deferred off the first frame ---
	var enemy_manager := Node.new()
	enemy_manager.set_script(load("res://scripts/spawning/enemy_manager.gd"))
	enemy_manager.name = "V31AEnemyManager"
	root.add_child(enemy_manager)
	var pool_manager: Node = root.get_node("PoolManager")
	var before: Dictionary = pool_manager.get_pool_stats("res://scenes/enemies/Enemy.tscn")
	_check(int(before.get("free", 0)) == 0, "pool is empty on the first frame")
	await process_frame
	var after: Dictionary = pool_manager.get_pool_stats("res://scenes/enemies/Enemy.tscn")
	_check(int(after.get("free", 0)) > 0, "pool prewarms on the next frame (%d)" % int(after.get("free", 0)))
	enemy_manager.queue_free()
	await process_frame

	if failures == 0:
		print("V31A_LOAD_PASS")
	else:
		print("V31A_LOAD_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)
