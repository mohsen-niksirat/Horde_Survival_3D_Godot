extends SceneTree
## Phase 11 Step 1 validation: stress scene reaches ~250 enemies and the
## performance overlay reports real data.

var failures := 0

func _initialize() -> void:
	var stress_ps: PackedScene = load("res://tests/StressScene.tscn")
	var stress := stress_ps.instantiate()
	root.add_child(stress)
	# Spawn budget drains ~8 enemies/frame — wait until the feed finishes
	# (or the frame budget runs out) instead of a fixed 20-frame window.
	for i in range(240):
		await process_frame
		await physics_frame
		var target: int = mini(250, root.get_node("PerformanceManager").effective_enemy_cap())
		if stress.get("_em").enemy_count() >= target:
			break

	var em: Node = stress.get_node("EnemyManager")
	var target: int = mini(250, root.get_node("PerformanceManager").effective_enemy_cap())
	_check(em.enemy_count() >= target - 5 and em.enemy_count() <= target, "stress scene respects effective population target %d (got %d)" % [target, em.enemy_count()])
	var perf: Node = root.get_node("PerformanceManager")
	# Quality.ULTRA == 4 (scene forces it so caps don't interfere)
	_check(perf.quality == 4, "quality forced ULTRA (%d)" % perf.quality)

	# Let systems tick for profiling data accumulation
	for i in range(30):
		await process_frame
		await physics_frame

	var info: String = perf.get_debug_info()
	_check(info.contains("draw calls"), "overlay reports draw calls")
	_check(info.contains("enemy_ai"), "overlay reports enemy_ai frame time")
	_check(info.contains("weapons"), "overlay reports weapons frame time")

	# Sanity: counters live
	_check(perf.active_enemies == em.enemy_count(), "active_enemies counter synced")

	# Enemy AI aggregate time should be measurable but sane
	var ai_ms: float = perf.get_system_avg_ms("enemy_ai")
	_check(ai_ms > 0.0, "enemy_ai timing accumulated (%.2f ms)" % ai_ms)

	if failures == 0:
		print("STRESS_INSTRUMENT_PASS")
	else:
		print("STRESS_INSTRUMENT_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
