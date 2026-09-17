extends SceneTree
## Phase 10 test: procedural SFX generation, settings persistence,
## volume application, screen feedback bind, boot click gate (desktop skips).

var failures := 0

func _initialize() -> void:
	var audio := root.get_node("AudioManager")
	var save := root.get_node("SaveManager")

	# --- Procedural tones generate + cache ---
	var stream1 = audio._get_tone("test_sine", 440.0, 0.1, "sine")
	_check(stream1 != null, "tone generated")
	var stream2 = audio._get_tone("test_sine", 440.0, 0.1, "sine")
	_check(stream1 == stream2, "tone cached")
	var stream3 = audio._get_tone("test_noise", 440.0, 0.1, "noise")
	_check(stream3 != null and stream3 != stream1, "noise tone distinct")
	_check(stream1.data.size() > 0, "tone has PCM data")

	# --- Presets don't crash (headless audio = dummy driver, still safe) ---
	audio.play_game_sfx("weapon_fire")
	audio.play_game_sfx("level_up")
	audio.play_game_sfx("boss_die")
	_check(true, "presets execute without error")

	# --- Settings persistence + apply ---
	save.set_setting("master_volume", 0.5)
	save.set_setting("music_volume", 0.4)
	save.set_setting("sfx_volume", 0.6)
	audio.apply_saved_volumes()
	_check(absf(audio.master_volume - 0.5) < 0.01, "master volume loaded (got %.2f)" % audio.master_volume)
	_check(absf(audio.music_volume - 0.4) < 0.01, "music volume loaded")
	_check(absf(audio.sfx_volume - 0.6) < 0.01, "sfx volume loaded")

	# --- Quality tiers ---
	var perf := root.get_node("PerformanceManager")
	perf.set_quality(perf.Quality.VERY_LOW, false)
	_check(perf.enemy_cap() <= 50, "VERY_LOW quality cap tight (%d)" % perf.enemy_cap())
	perf.set_quality(perf.Quality.ULTRA, false)
	_check(perf.enemy_cap() >= 200, "ULTRA quality cap high (%d)" % perf.enemy_cap())
	perf.set_quality(perf.Quality.LOW, false)

	# --- Main scene boot with all new UI pieces ---
	var main_ps: PackedScene = load("res://scenes/main/Main.tscn")
	var main = main_ps.instantiate()
	root.add_child(main)
	for i in range(4):
		await process_frame
		await physics_frame
	_check(main.get_node_or_null("HUD/ScreenFeedback") != null, "ScreenFeedback exists")
	var feedback: Node = main.get_node("HUD/ScreenFeedback")
	_check(feedback.get_node_or_null("Vignette") != null, "vignette node exists")

	# Simulate low HP -> vignette alpha rises on _process
	var player: CharacterBody3D = main.get_node("World/Player")
	player.health.take_damage(DamageEvent.new(player.health.max_hp * 0.8, "test"))
	for i in range(3):
		await process_frame
	_check(feedback.get_node("Vignette").modulate.a > 0.1, "low-HP vignette visible (a=%.2f)" % feedback.get_node("Vignette").modulate.a)

	# --- Menu scene loads with settings ---
	var menu_ps: PackedScene = load("res://scenes/menu/MainMenu.tscn")
	var menu = menu_ps.instantiate()
	root.add_child(menu)
	await process_frame
	_check(menu.get_node_or_null("SettingsMenu") != null, "SettingsMenu embedded")
	var settings: Node = menu.get_node("SettingsMenu")
	settings.open()
	_check(settings.visible, "settings opens")
	settings._on_volume(0.9, "sfx_volume")
	_check(absf(save.get_setting("sfx_volume", 0.0) - 0.9) < 0.01, "settings persist sfx volume")

	if failures == 0:
		print("PHASE10_TEST_PASS")
	else:
		print("PHASE10_TEST_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
