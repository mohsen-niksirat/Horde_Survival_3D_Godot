extends SceneTree
## V30A performance gate: adaptive resolution ladder, telemetry gating,
## pooled-VFX process gating, component gating, and allocation-free targeting.

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

	var perf: Node = root.get_node("PerformanceManager")

	# --- platform probes are cached once (no OS.get_name per hit) ---
	_check(perf._is_web() == perf._web, "web probe reads the cached flag")
	_check(perf._is_touch() == perf._touch, "touch probe reads the cached flag")

	# --- telemetry is off by default and costs nothing when off ---
	perf.set_telemetry_enabled(false)
	perf.report_system_time("v30a_probe", 5000)
	_check(perf.get_system_avg_ms("v30a_probe") == 0.0, "telemetry no-op while disabled")
	perf.set_telemetry_enabled(true)
	perf.report_system_time("v30a_probe", 2000)
	perf.report_system_time("v30a_probe", 2000)
	_check(perf.get_system_avg_ms("v30a_probe") > 0.0, "telemetry records while enabled")
	perf.set_telemetry_enabled(false)
	_check(perf._system_times.is_empty(), "disabling telemetry clears samples")

	# --- adaptive resolution: downscale on sustained low FPS ---
	var original_quality: int = perf.quality
	perf.set_quality(perf.Quality.MEDIUM, false)
	var base_scale: float = perf._render_scale()
	perf.dynamic_resolution = true
	perf._reset_dynamic_state()
	perf._dyn_grace = 0.0
	for i in range(12):
		perf._tick_dynamic_resolution(0.2, 20)
	var dropped: float = perf.current_render_scale()
	_check(dropped < base_scale, "low FPS lowers the 3D render scale (%.2f -> %.2f)" % [base_scale, dropped])
	_check(dropped >= perf._dynamic_floor(base_scale) - 0.001, "render scale never drops below the floor")
	# Let the 1.5 s no-gain window see improved frame rate -> keep the lower scale.
	for i in range(12):
		perf._tick_dynamic_resolution(0.2, 55)
	_check(absf(perf.current_render_scale() - dropped) < 0.001, "improved FPS keeps the lower scale")
	# Sustained headroom climbs back to the tier ceiling.
	for i in range(60):
		perf._tick_dynamic_resolution(0.2, 62)
	_check(absf(perf.current_render_scale() - base_scale) < 0.001, "sustained high FPS restores the scale")
	# A CPU-bound device (lower pixels did not help) reverts and waits.
	perf._reset_dynamic_state()
	perf._dyn_grace = 0.0
	for i in range(18):
		perf._tick_dynamic_resolution(0.2, 20)
	_check(absf(perf.current_render_scale() - base_scale) < 0.001, "no-gain downscale reverts to base")
	_check(perf._dyn_cooldown > 0.0, "no-gain revert pauses the ladder")
	perf.dynamic_resolution = false
	perf.set_quality(original_quality, false)

	# --- pooled damage numbers stop processing when idle ---
	var pool: Node = root.get_node("PoolManager")
	var dn_scene := "res://scenes/vfx/DamageNumber.tscn"
	var dn: Node3D = pool.acquire(dn_scene)
	pool.tag(dn, dn_scene)
	root.add_child(dn)
	_check(not dn.is_processing(), "pooled damage number idles without processing")
	dn.trigger(Vector3.ZERO, 12.0, false)
	_check(dn.is_processing(), "damage number processes while active")
	dn._process(1.0)
	_check(not dn.is_processing() and not dn.visible, "damage number parks after its lifetime")
	pool.release(dn)

	# --- status/elite components are dormant unless in use ---
	var enemy_ps: PackedScene = load("res://scenes/enemies/Enemy.tscn")
	var enemy: CharacterBody3D = enemy_ps.instantiate()
	root.add_child(enemy)
	_check(not enemy.status.is_processing(), "status component idles with no effects")
	enemy.status.apply("slow", 1.0, {"factor": 0.5})
	_check(enemy.status.is_processing(), "status component wakes on apply")
	enemy.status._process(2.0)
	_check(not enemy.status.is_processing() and not enemy.status.has_effect("slow"), "status component sleeps after expiry")
	var elite_comp: Node = enemy.get_node("EliteComponent")
	_check(not elite_comp.is_processing(), "elite component idles on normal enemies")
	elite_comp.setup(enemy, null, null, [])
	_check(elite_comp.is_processing(), "elite component wakes when promoted")
	elite_comp.disable()
	_check(not elite_comp.is_processing() and elite_comp.enemy == null, "elite component cleans up on recycle")
	enemy.queue_free()

	# --- targeting: nearest N, filters non-enemies, no closures ---
	var wc_script: Script = load("res://scripts/weapons/weapon_controller.gd")
	var wc: Node = wc_script.new()
	var origin := Node3D.new()
	origin.position = Vector3.ZERO
	root.add_child(origin)
	var near_enemy := _marker(root, Vector3(2, 0, 0), true)
	var far_enemy := _marker(root, Vector3(9, 0, 0), true)
	var mid_enemy := _marker(root, Vector3(5, 0, 0), true)
	var not_enemy := _marker(root, Vector3(1, 0, 0), false)
	var picked: Array = wc._pick_nearest([far_enemy, not_enemy, mid_enemy, near_enemy], origin, 2)
	_check(picked.size() == 2, "nearest-N returns the requested count")
	_check(picked.has(near_enemy) and picked.has(mid_enemy), "nearest-N picks the two closest enemies")
	_check(not picked.has(not_enemy), "nearest-N filters non-enemy nodes")
	var single: Array = wc._pick_nearest([far_enemy, near_enemy], origin, 1)
	_check(single.size() == 1 and single[0] == near_enemy, "nearest-N orders by distance")
	wc.free()
	for n in [origin, near_enemy, mid_enemy, far_enemy, not_enemy]:
		n.queue_free()

	# --- spatial grid rebuild is decoupled from the render frame ---
	var em_script: Script = load("res://scripts/spawning/enemy_manager.gd")
	var consts: Dictionary = em_script.get_script_constant_map()
	_check(int(consts.get("GRID_REBUILD_MS", 0)) >= 100, "enemy grid rebuild throttled to 100 ms")

	await process_frame
	await process_frame
	if failures == 0:
		print("V30A_PERF_PASS")
	else:
		print("V30A_PERF_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _marker(parent: Node, pos: Vector3, is_enemy: bool) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	if is_enemy:
		n.add_to_group("enemies")
	return n
