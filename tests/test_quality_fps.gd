extends SceneTree
## Quality tiers + FPS HUD + horde stress validation.

var failures := 0

func _initialize() -> void:
	var perf: Node = root.get_node("PerformanceManager")
	_check(perf.Quality.VERY_LOW == 0, "VERY_LOW enum is 0")
	_check(perf.Quality.ULTRA == 4, "ULTRA enum is 4")

	# Default path uses lowest tier
	perf.set_quality(perf.Quality.VERY_LOW, false)
	_check(perf.enemy_cap() <= 50, "VERY_LOW enemy cap tight (%d)" % perf.enemy_cap())
	perf.set_quality(perf.Quality.ULTRA, false)
	_check(perf.enemy_cap() >= 200, "ULTRA enemy cap high (%d)" % perf.enemy_cap())

	# Stress shrinks effective cap
	perf.set_quality(perf.Quality.HIGH, false)
	var base_cap: int = perf.enemy_cap()
	perf.stress_mode = true
	var stress_cap: int = perf.effective_enemy_cap()
	_check(stress_cap < base_cap, "stress reduces effective cap (%d < %d)" % [stress_cap, base_cap])
	perf.stress_mode = false

	# Auto settings option count
	var menu_ps: PackedScene = load("res://scenes/menu/SettingsMenu.tscn")
	var menu: Control = menu_ps.instantiate()
	root.add_child(menu)
	await process_frame
	var opts: OptionButton = menu.get_node("Center/Panel/Layout/QualityRow/QualityOption")
	_check(opts.item_count == 6, "quality dropdown has 6 options (%d)" % opts.item_count)
	menu.queue_free()

	# HUD FPS label exists after Main boot
	var main_ps: PackedScene = load("res://scenes/main/Main.tscn")
	var main := main_ps.instantiate()
	root.add_child(main)
	for i in range(4):
		await process_frame
		await physics_frame
	var fps_label: Label = main.get_node_or_null("HUD/Hud/TopRight/FpsLabel")
	if fps_label == null:
		fps_label = main.get_node_or_null("HUD/TopRight/FpsLabel")
	_check(fps_label != null, "FPS label on HUD")
	if fps_label != null:
		var hud: Control = fps_label.get_parent().get_parent()
		if hud.has_method("_update_fps_label"):
			hud._update_fps_label()
		_check(fps_label.text.contains("FPS"), "FPS label shows FPS text (%s)" % fps_label.text)

	# Auto tick steps down under stress-like low FPS from ULTRA
	perf.auto_mode = true
	perf.stress_mode = true
	perf.set_quality(perf.Quality.ULTRA, false)
	for i in range(8):
		perf._auto_tick(0.5, 20)
	_check(perf.quality < perf.Quality.ULTRA, "auto steps down under stress FPS (now %d)" % perf.quality)

	if failures == 0:
		print("QUALITY_FPS_PASS")
	else:
		print("QUALITY_FPS_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
