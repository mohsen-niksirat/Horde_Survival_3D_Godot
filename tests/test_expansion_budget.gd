extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
func _run() -> void:
	var main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	for i in range(5):
		await process_frame
		await physics_frame
	main.wave_manager.stop()
	var em = main.enemy_manager
	em.set_process(false)
	em.clear_all()
	var player = main.get_node("World/Player")
	player.weapon_controller.weapons.clear()
	player.experience.xp_to_next = 1000000.0
	var perf = root.get_node("PerformanceManager")
	perf.auto_mode = false
	perf.stress_mode = false
	var data: EnemyData = load("res://data/enemies/broodling.tres")
	var cap: int = perf.effective_enemy_cap()
	var max_count := 0
	var max_queued := 0
	for frame in range(30):
		for request in range(100):
			em.queue_spawn(data, player.global_position + Vector3(18, 0, 0), player, 1.0, 1.0, 1.0)
		var before: int = em.enemy_count()
		em._process(0.016)
		max_count = maxi(max_count, em.enemy_count())
		max_queued = maxi(max_queued, em._spawn_queue.size())
		check(em.enemy_count() - before <= em.MAX_SPAWNS_PER_FRAME, "bounded admissions")
		check(em.enemy_count() + em._spawn_queue.size() <= perf.effective_enemy_cap(), "active plus queued cap")
	check(max_count > 0 and max_count <= cap, "stress population bounded")
	check(max_queued <= em.MAX_SPAWN_QUEUE, "queue storage bounded")
	check(not em.queue_spawn(null, Vector3.ZERO, player, 1, 1, 1), "null data rejected")
	check(not em.queue_spawn(data, Vector3.ZERO, null, 1, 1, 1), "missing player rejected")
	em.clear_all()
	check(em.enemy_count() == 0 and em._spawn_queue.is_empty(), "clear drops backlog")
	main.queue_free()
	await process_frame
	await process_frame
	var campaign = load("res://scenes/menu/CampaignMenu.tscn").instantiate()
	root.add_child(campaign)
	campaign.set_anchors_preset(Control.PRESET_TOP_LEFT)
	campaign.size = Vector2(390, 760)
	campaign.open()
	campaign._fit_layout()
	await process_frame
	var cards := 0
	for child in campaign.rows.get_children():
		if child is Button:
			cards += 1
			check(child.custom_minimum_size.x <= 366.0, "campaign card phone width")
	check(cards == 7, "seven mission buttons")
	campaign.queue_free()
	await process_frame
	print("EXPANSION_BUDGET_METRICS cap=", cap, " peak=", max_count, " queue_peak=", max_queued, " requests=3000")
	print("EXPANSION_BUDGET_PASS" if failures == 0 else "EXPANSION_BUDGET_FAIL")
	quit(0 if failures == 0 else 1)
