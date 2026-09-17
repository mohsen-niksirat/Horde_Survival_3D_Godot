extends SceneTree
## V10 validation: quality tiers valid, VERY_LOW disables shadows, HIGH/ULTRA enable.

var failures := 0

func _initialize() -> void:
	var main_ps: PackedScene = load("res://scenes/main/Main.tscn")
	var main := main_ps.instantiate()
	root.add_child(main)
	for i in range(4):
		await process_frame
		await physics_frame

	var perf: Node = root.get_node("PerformanceManager")
	var perf_quality: int = perf.quality
	_check(perf_quality >= 0 and perf_quality <= 4, "quality tier valid (%d)" % perf_quality)

	perf.set_quality(perf.Quality.VERY_LOW, false)
	for i in range(3):
		await process_frame
	var sun: DirectionalLight3D = main.get_node("World/Sun")
	_check(sun.shadow_enabled == false, "VERY_LOW quality disables shadows")

	perf.set_quality(perf.Quality.HIGH, false)
	for i in range(3):
		await process_frame
	_check(sun.shadow_enabled == true, "HIGH quality re-enables shadows")
	perf.set_quality(perf.Quality.LOW, false)

	var f := FileAccess.open("res://docs/BUILD_ANDROID.md", FileAccess.READ)
	var content := f.get_as_text()
	f.close()
	_check(content.contains("V10"), "Android guide updated for V10")

	if failures == 0:
		print("V10_OPT_PASS")
	else:
		print("V10_OPT_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
