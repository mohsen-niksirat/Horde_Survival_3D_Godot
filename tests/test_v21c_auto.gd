extends SceneTree
## V21C validation: AUTO mode + expanded tiers + Auto dropdown.

var failures := 0

func _initialize() -> void:
	var perf: Node = root.get_node("PerformanceManager")
	perf.auto_mode = true
	perf.stress_mode = false
	perf.set_quality(perf.Quality.ULTRA, false)  # 4

	# Desktop non-stress: low_hold=4s → ~2 steps in 10s at 20 FPS
	for i in range(20):
		perf._auto_tick(0.5, 20)
	_check(perf.quality <= perf.Quality.MEDIUM, "stepped down from ULTRA at 20 FPS (now %d)" % perf.quality)

	var after_low: int = perf.quality
	for i in range(50):
		perf._auto_tick(0.5, 58)
	_check(perf.quality == after_low + 1 or perf.quality == perf.Quality.ULTRA, "recovered at least one tier (%d)" % perf.quality)
	for i in range(80):
		perf._auto_tick(0.5, 58)
	_check(perf.quality == perf.Quality.ULTRA, "fully recovered to ULTRA (now %d)" % perf.quality)

	var menu_ps: PackedScene = load("res://scenes/menu/SettingsMenu.tscn")
	var menu: Control = menu_ps.instantiate()
	root.add_child(menu)
	await process_frame
	var opts: OptionButton = menu.get_node("Center/Panel/Layout/QualityRow/QualityOption")
	_check(opts.item_count == 6, "quality dropdown Very Low..Ultra+Auto (%d)" % opts.item_count)
	menu.queue_free()

	if failures == 0:
		print("V21C_AUTO_PASS")
	else:
		print("V21C_AUTO_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
