extends SceneTree
## Phase 5 test: threat-budget waves spawn over time, caps hold, culling
## works, difficulty timeline produces correct compositions.

var failures := 0

func _initialize() -> void:
	var main_ps: PackedScene = load("res://scenes/main/Main.tscn")
	var main := main_ps.instantiate()
	root.add_child(main)
	for i in range(4):
		await process_frame
		await physics_frame

	var player: CharacterBody3D = main.get_node("World/Player")
	var em: Node = main.get_node("EnemyManager")
	var wm: Node = main.get_node("WaveManager")
	var game_manager := root.get_node("GameManager")
	game_manager.state = game_manager.State.PLAYING

	_check(wm.archetype_data.size() >= 9, ">= 9 archetypes loaded (got %d)" % wm.archetype_data.size())

	# --- Simulate 30 seconds of waves (fast-forward clock, run frames) ---
	var run_manager := root.get_node("RunManager")
	run_manager.elapsed_time = 120.0  # 2 minutes in: fast enemies available

	var frames := 0
	while frames < 1800 and em.enemy_count() < 25:  # up to ~30s at 60fps
		await process_frame
		await physics_frame
		frames += 1
	_check(em.enemy_count() >= 10, "waves spawned enemies (count=%d after %d frames)" % [em.enemy_count(), frames])

	# --- Composition: after 2 min, only basic+swarm should exist ---
	var ids := {}
	for e in em.active_enemies:
		if is_instance_valid(e) and e.data != null:
			ids[e.data.id] = true
	var legal := true
	for id in ids:
		if not ["basic_drone", "swarm_bat"].has(id):
			legal = false
	_check(legal, "composition respects timeline (got %s)" % [ids.keys()])

	# --- Cap holds: force budget way up ---
	run_manager.elapsed_time = 1200.0  # 20 min
	frames = 0
	while frames < 1200:
		await process_frame
		await physics_frame
		frames += 1
		var cap: int = root.get_node("PerformanceManager").enemy_cap()
		if em.enemy_count() >= cap:
			break
	var perf := root.get_node("PerformanceManager")
	_check(em.enemy_count() <= perf.enemy_cap(), "enemy cap holds (%d <= %d)" % [em.enemy_count(), perf.enemy_cap()])

	# --- Culling: stop waves, teleport player+enemy far apart ---
	# A level-up during the soak pauses the tree (LEVEL_UP state); clear
	# that pause so EnemyManager._process (which runs culling) ticks.
	game_manager.state = game_manager.State.PLAYING
	paused = false
	player.experience.xp_to_next = 999999.0
	wm.stop()
	player.global_position = Vector3(0, 0.5, 0)
	player.velocity = Vector3.ZERO
	if em.enemy_count() > 0:
		var far: CharacterBody3D = em.active_enemies[0]
		far.set_physics_process(false)  # freeze it so it cannot chase closer
		far.global_position = Vector3(0, 0, 200)  # far beyond the 55m cull
		var before: int = em.enemy_count()
		for i in range(120):
			await process_frame
			await physics_frame
		_check(em.enemy_count() < before, "far enemy culled (%d -> %d)" % [before, em.enemy_count()])

	# --- Difficulty math sanity ---
	_check(absf(DifficultyManager.difficulty_multiplier(1, 0.0) - 1.18) < 0.01, "difficulty at start = 1.18")
	_check(DifficultyManager.hp_scale(20.0) == 12.0, "hp scale capped at 12")
	_check(DifficultyManager.spawn_interval(0.0) == 2.0, "spawn interval starts 2s")
	_check(DifficultyManager.spawn_interval(100.0) == 0.45, "spawn interval floors at 0.45s (V18)")

	if failures == 0:
		print("PHASE5_TEST_PASS")
	else:
		print("PHASE5_TEST_FAIL failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("OK: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
